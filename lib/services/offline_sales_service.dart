import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Encrypted, per-user and per-business sales queue.
/// A sale is written to device storage before any network request.
class OfflineSalesService {
  OfflineSalesService._();
  static final instance=OfflineSalesService._();
  static const _store=FlutterSecureStorage();
  bool _syncing=false;
  String _key(String business,String part){
    final user=Supabase.instance.client.auth.currentUser?.id;
    if(user==null)throw StateError('Sign in once online before offline sales.');
    return 'arodesk_offline_sales_${user}_${business}_${part}';
  }
  Future<List<Map<String,dynamic>>> _read(String business,String part)async{
    final raw=await _store.read(key:_key(business,part));
    if(raw==null)return [];
    return (jsonDecode(raw) as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  }
  Future<void> _write(String business,String part,List<Map<String,dynamic>> rows)async{
    await _store.write(key:_key(business,part),value:jsonEncode(rows));
  }
  Future<void> cacheCatalog(String business,{
    required List<Map<String,dynamic>> products,
    required Map<String,double> balances,
    required String currency,
    required List<Map<String,dynamic>> transactions,
  })async{
    await _store.write(key:_key(business,'snapshot'),value:jsonEncode({
      'products':products,'balances':balances,'currency':currency,'transactions':transactions,
      'cached_at':DateTime.now().toUtc().toIso8601String(),
    }));
  }
  Future<Map<String,dynamic>?> snapshot(String business)async{
    final data=await _store.read(key:_key(business,'snapshot'));
    return data==null?null:Map<String,dynamic>.from(jsonDecode(data) as Map);
  }
  // Retain printable details after server sync removes a pending operation.
  Future<void> _archivePrint(String business,Map<String,dynamic> entry)async{
    final rows=await _read(business,'print_archive');
    rows.removeWhere((row)=>row['id']==entry['id']);
    rows.insert(0,entry);
    if(rows.length>250)rows.removeRange(250,rows.length);
    await _write(business,'print_archive',rows);
  }
  Future<Map<String,dynamic>?> printable(String business,String localId)async{
    final rawId=localId.startsWith('offline:')?localId.substring(8):localId;
    for(final row in await _read(business,'print_archive')){
      if(row['id']==rawId)return row;
    }
    for(final row in [...await pending(business),...await pendingQuotes(business)]){
      if(row['id']==rawId)return row;
    }
    return null;
  }
  Future<List<Map<String,dynamic>>> pendingQuotes(String business)=>
    _read(business,'quote_queue');
  Future<String> queueQuotation({
    required String business,required Map<String,double> quantities,
    required String customer,required String phone,
  })async{
    if(quantities.isEmpty||quantities.values.any((v)=>!v.isFinite||v<=0)){
      throw ArgumentError('Select valid quotation items.');
    }
    final snapshotData=await snapshot(business);
    if(snapshotData==null)throw StateError('Connect once to download your product catalog.');
    final catalog=<String,Map<String,dynamic>>{
      for(final raw in snapshotData['products'] as List)
        Map<String,dynamic>.from(raw as Map)['id'].toString():Map<String,dynamic>.from(raw),
    };
    var total=0.0;
    for(final item in quantities.entries){
      final product=catalog[item.key];
      if(product==null)throw StateError('Quotation item is unavailable in the catalog.');
      total+=(product['sale_price'] as num).toDouble()*item.value;
    }
    final id=const Uuid().v4();
    final queue=await pendingQuotes(business);
    queue.add({
      'id':id,'business':business,'kind':'quotation','quantities':quantities,
      'customer':customer,'phone':phone,'currency':snapshotData['currency'],
      'total':total,
      'print_lines':[
        for(final e in quantities.entries)
          {'description':catalog[e.key]!['name'].toString(),
           'quantity':e.value,'unit_price':(catalog[e.key]!['sale_price'] as num).toDouble()},
      ],
      'created_at':DateTime.now().toUtc().toIso8601String(),
    });
    await _write(business,'quote_queue',queue);
    await _archivePrint(business,queue.last);
    return 'offline:$id';
  }
  Future<int> syncQuotes(String business)async{
    var confirmed=0;
    for(final item in await pendingQuotes(business)){
      try{
        final quantities=Map<String,dynamic>.from(item['quantities'] as Map);
        await Supabase.instance.client.rpc('arodesk_record_offline_quotation',params:{
          'p_request':item['id'],'p_business':business,
          'p_lines':quantities.entries.map((e)=>{'product_id':e.key,'quantity':e.value}).toList(),
          'p_customer':item['customer'],'p_phone':item['phone'],
        }).timeout(const Duration(seconds:10));
        final current=await pendingQuotes(business);
        current.removeWhere((e)=>e['id']==item['id']);
        await _write(business,'quote_queue',current);
        confirmed++;
      }catch(_){break;}
    }
    return confirmed;
  }
  Future<List<Map<String,dynamic>>> pendingStock(String business)=>
    _read(business,'stock_queue');
  Future<void> queueStock(String business,{
    required String product,required double delta,required String kind,
    required String note,required DateTime date,required String source,
    required String destination,required String reference,
  })async{
    if(!delta.isFinite||delta==0||delta.abs()>999999999){
      throw ArgumentError('Invalid stock quantity.');
    }
    final snap=await snapshot(business);
    if(snap==null)throw StateError('Load products online at least once.');
    final catalog=(snap['products'] as List).map((e)=>Map<String,dynamic>.from(e as Map));
    if(!catalog.any((p)=>p['id']==product&&p['track_stock']==true)){
      throw StateError('This product cannot be adjusted offline.');
    }
    final available=await effectiveBalances(business,{
      for(final entry in Map<String,dynamic>.from(snap['balances'] as Map).entries)
        entry.key:(entry.value as num).toDouble(),
    });
    if(delta<0&&(available[product]??0)+delta<0){
      throw StateError('Insufficient offline stock.');
    }
    final rows=await pendingStock(business);
    rows.add({
      'id':const Uuid().v4(),'product':product,'delta':delta,'kind':kind,
      'note':note,'date':'${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}',
      'source':source,'destination':destination,'reference':reference,
      'queued_at':DateTime.now().toUtc().toIso8601String(),
    });
    await _write(business,'stock_queue',rows);
  }
  Future<int> syncStock(String business)async{
    final rows=await pendingStock(business);
    var count=0;
    for(final item in rows){
      try{
        await Supabase.instance.client.rpc('arodesk_post_stock_offline_idempotent',params:{
          'p_request':item['id'],'p_business':business,'p_product':item['product'],
          'p_delta':item['delta'],'p_kind':item['kind'],'p_note':item['note'],
          'p_movement_date':item['date'],
          'p_source_location':item['source'],
          'p_destination_location':item['destination'],
          'p_reference':item['reference'],
        }).timeout(const Duration(seconds:10));
        final latest=await pendingStock(business);
        latest.removeWhere((x)=>x['id']==item['id']);
        await _write(business,'stock_queue',latest);
        count++;
      }catch(_){break;}
    }
    return count;
  }
  Future<List<Map<String,dynamic>>> pending(String business)=>_read(business,'queue');
  Future<int> pendingCount(String business)async=>(await pending(business)).length;
  Future<String> queueSale({
    required String business,required Map<String,double> quantities,
    required String customer,required String phone,required String address,
    required List<Map<String,dynamic>> payments,String? dueDate,
  })async{
    if(quantities.isEmpty)throw ArgumentError('Add a product.');
    if(quantities.values.any((v)=>!v.isFinite||v<=0))throw ArgumentError('Invalid quantity.');
    final snap=await snapshot(business);
    if(snap==null)throw StateError('Connect once to download your products before selling offline.');
    final catalog=List<Map<String,dynamic>>.from(
      (snap['products'] as List).map((x)=>Map<String,dynamic>.from(x as Map)));
    final byId={for(final p in catalog)p['id'].toString():p};
    final stock=Map<String,dynamic>.from(snap['balances'] as Map);
    final queue=await pending(business);
    for(final move in await pendingStock(business)){
      final id=move['product'].toString();
      stock[id]=((stock[id] as num?)?.toDouble()??0)+(move['delta'] as num).toDouble();
    }
    for(final item in queue){
      final q=Map<String,dynamic>.from(item['quantities'] as Map);
      for(final e in q.entries){
        final p=byId[e.key];
        if(p!=null && p['track_stock']==true){
          stock[e.key]=((stock[e.key] as num?)?.toDouble()??0)-
            (e.value as num).toDouble();
        }
      }
    }
    for(final e in quantities.entries){
      final p=byId[e.key];
      if(p==null)throw StateError('Product is missing from the offline catalog.');
      if(p['track_stock']==true && e.value>((stock[e.key] as num?)?.toDouble()??0)+0.00001){
        throw StateError('Insufficient offline stock for ${p['name']}.');
      }
    }
    final total=quantities.entries.fold<double>(0,(sum,e)=>
      sum+((byId[e.key]!['sale_price'] as num).toDouble()*e.value));
    final paid=payments.fold<double>(0,(sum,p)=>sum+(p['amount'] as num).toDouble());
    if(paid>total+0.01)throw StateError('Payment exceeds sale total.');
    final id=const Uuid().v4();
    final row=<String,dynamic>{
      'id':id,'business':business,'kind':'sale','customer':customer,'phone':phone,
      'address':address,'payments':payments,'due_date':dueDate,
      'quantities':quantities,'currency':snap['currency']??'USD',
      'total':total,'paid_total':paid,
      'print_lines':[
        for(final e in quantities.entries)
          {'description':byId[e.key]!['name'].toString(),
           'quantity':e.value,'unit_price':(byId[e.key]!['sale_price'] as num).toDouble()},
      ],
      'created_at':DateTime.now().toUtc().toIso8601String(),
    };
    queue.add(row);
    // Failure to persist MUST prevent marking a sale as recorded.
    await _write(business,'queue',queue);
    await _archivePrint(business,queue.last);
    return 'offline:$id';
  }
  Future<List<Map<String,dynamic>>> localTransactions(String business)async{
    final queue=[...await pending(business),...await pendingQuotes(business)];
    queue.sort((a,b)=>a['created_at'].toString().compareTo(b['created_at'].toString()));
    return queue.reversed.map((q)=><String,dynamic>{
      'id':'offline:${q['id']}','document_number':'LOCAL-${q['id'].toString().substring(0,8).toUpperCase()}',
      'kind':q['kind']??'sale','customer_name':q['customer'],'currency':q['currency'],
      'total':q['total'],'paid_total':q['paid_total']??0,
      'returned_total':0,'refunded_total':0,
      'payment_status':'Pending sync','due_date':q['due_date'],
      'created_at':q['created_at'],
    }).toList();
  }
  Future<Map<String,double>> effectiveBalances(String business,Map<String,double> original)async{
    final result=Map<String,double>.from(original);
    final snap=await snapshot(business);
    if(snap==null)return result;
    final products=List<Map<String,dynamic>>.from(
      (snap['products'] as List).map((x)=>Map<String,dynamic>.from(x as Map)));
    final tracked={for(final p in products)if(p['track_stock']==true)p['id'].toString()};
    for(final item in await pendingStock(business)){
      final id=item['product'].toString();
      result[id]=(result[id]??0)+(item['delta'] as num).toDouble();
    }
    for(final row in await pending(business)){
      for(final item in Map<String,dynamic>.from(row['quantities'] as Map).entries){
        if(tracked.contains(item.key)){
          result[item.key]=(result[item.key]??0)-(item.value as num).toDouble();
        }
      }
    }
    return result;
  }
  /// Server function guarantees atomic checkout + request-id deduplication.
  /// Retain failed/conflicted transactions for manual resolution, never discard.
  Future<int> sync(String business)async{
    if(_syncing)return 0;
    _syncing=true;
    var success=0;
    try{
      final queue=await pending(business);
      for(final item in queue){
        try{
          final qty=Map<String,dynamic>.from(item['quantities'] as Map);
          await Supabase.instance.client.rpc('arodesk_checkout_offline_idempotent',params:{
            'p_request':item['id'],'p_business':business,
            'p_lines':qty.entries.map((e)=>{'product_id':e.key,'quantity':e.value}).toList(),
            'p_customer':item['customer'],'p_phone':item['phone'],
            'p_address':item['address'],'p_payments':item['payments'],
            'p_due_date':item['due_date'],
          }).timeout(const Duration(seconds:12));
          final latest=await pending(business);
          latest.removeWhere((r)=>r['id']==item['id']);
          await _write(business,'queue',latest);
          success++;
        }catch(_){
          // A connection or business rule failure must leave the sale queued.
          break;
        }
      }
      return success;
    }finally{_syncing=false;}
  }
}
