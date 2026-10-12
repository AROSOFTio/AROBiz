import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_sales_service.dart';

/// Read-only ledger projection: server-posted double entries plus clearly
/// separated locally pending movements. Never represents pending as posted.
class AccountingService {
  AccountingService._();
  static final instance=AccountingService._();
  static const _secure=FlutterSecureStorage();
  static const names=<String,String>{
    '1000':'Cash','1010':'Mobile money','1020':'Bank / card',
    '1100':'Accounts receivable','1200':'Inventory',
    '2100':'Stock clearing','4000':'Sales revenue',
    '5000':'Cost of sales','5200':'Stock adjustments',
  };
  String _key(String business){
    final uid=Supabase.instance.client.auth.currentUser?.id;
    if(uid==null)throw StateError('Sign in first.');
    return 'accounting_snapshot_${uid}_${business}';
  }
  Future<List<Map<String,dynamic>>> posted(String business)async{
    try{
      final journals=await Supabase.instance.client.from('arodesk_journals')
        .select('id,posted_at,currency,source_type')
        .eq('business_id',business)
        .order('posted_at',ascending:false).limit(500)
        .timeout(const Duration(seconds:9));
      if(journals.isEmpty)return [];
      final ids=journals.map((e)=>e['id'].toString()).toList();
      final details=await Supabase.instance.client.from('arodesk_journal_lines')
        .select('journal_id,account_code,debit,credit')
        .inFilter('journal_id',ids)
        .timeout(const Duration(seconds:9));
      final refs={for(final j in journals)j['id'].toString():j};
      final lines=<Map<String,dynamic>>[
        for(final item in details)
          {
            ...Map<String,dynamic>.from(item),
            'posted_at':refs[item['journal_id'].toString()]?['posted_at'],
            'source_type':refs[item['journal_id'].toString()]?['source_type'],
            'currency':refs[item['journal_id'].toString()]?['currency'],
          },
      ];
      await _secure.write(key:_key(business),value:jsonEncode(lines));
      return lines;
    }catch(_){
      final cached=await _secure.read(key:_key(business));
      if(cached==null)return [];
      return (jsonDecode(cached) as List)
          .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    }
  }
  Future<List<Map<String,dynamic>>> pending(String business)async{
    final snap=await OfflineSalesService.instance.snapshot(business);
    if(snap==null)return [];
    final products={
      for(final p in (snap['products'] as List))
        Map<String,dynamic>.from(p as Map)['id'].toString():Map<String,dynamic>.from(p as Map),
    };
    final result=<Map<String,dynamic>>[];
    void add(String account,num debit,num credit,String time,String currency){
      if(debit==0&&credit==0)return;
      result.add({'account_code':account,'debit':debit,'credit':credit,
        'posted_at':time,'source_type':'Pending sync','currency':currency});
    }
    for(final sale in await OfflineSalesService.instance.pending(business)){
      final currency=sale['currency'].toString();
      final time=sale['created_at'].toString();
      final payments=(sale['payments'] as List).map((e)=>Map<String,dynamic>.from(e as Map));
      num paid=0;
      for(final p in payments){
        final amount=(p['amount'] as num);
        paid+=amount;
        final method=p['method'].toString();
        add(method=='Cash'?'1000':method=='Mobile Money'?'1010':'1020',
          amount,0,time,currency);
      }
      final total=(sale['total'] as num);
      add('1100',total-paid,0,time,currency);
      add('4000',0,total,time,currency);
      num cost=0;
      for(final item in Map<String,dynamic>.from(sale['quantities'] as Map).entries){
        final product=products[item.key];
        if(product!=null && product['track_stock']==true){
          cost+=(item.value as num)*(product['cost_price'] as num);
        }
      }
      final rounded=(cost*100).round()/100;
      add('5000',rounded,0,time,currency);
      add('1200',0,rounded,time,currency);
    }
    final currency=snap['currency'].toString();
    for(final item in await OfflineSalesService.instance.pendingStock(business)){
      final product=products[item['product'].toString()];
      if(product==null)continue;
      final amount=((item['delta'] as num).abs()*(product['cost_price'] as num)*100).round()/100;
      if(amount<=0)continue;
      final time=item['queued_at'].toString();
      final incoming=(item['delta'] as num)>0;
      add('1200',incoming?amount:0,incoming?0:amount,time,currency);
      add(incoming?'2100':'5200',incoming?0:amount,incoming?amount:0,time,currency);
    }
    return result;
  }
  Map<String,Map<String,double>> trialBalance(List<Map<String,dynamic>> lines){
    final output=<String,Map<String,double>>{};
    for(final line in lines){
      final code=line['account_code'].toString();
      final totals=output.putIfAbsent(code,()=>{'debit':0,'credit':0});
      totals['debit']=totals['debit']!+(line['debit'] as num).toDouble();
      totals['credit']=totals['credit']!+(line['credit'] as num).toDouble();
    }
    return output;
  }
}
