import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class OfflinePaymentService {
  OfflinePaymentService._();
  static final instance=OfflinePaymentService._();
  bool _syncing=false;
  static const _storage=FlutterSecureStorage();
  SupabaseClient get _client=>Supabase.instance.client;
  String _key(String business){
    final user=_client.auth.currentUser?.id;
    if(user==null)throw StateError('Sign in to record payments.');
    return 'pending_debtor_payments_'+user+'_'+business;
  }
  Future<List<Map<String,dynamic>>> pending(String business)async{
    final serialized=await _storage.read(key:_key(business));
    if(serialized==null)return [];
    return List<Map<String,dynamic>>.from(
      (jsonDecode(serialized) as List).map((row)=>Map<String,dynamic>.from(row as Map)));
  }
  Future<void> _write(String business,List<Map<String,dynamic>> rows)async{
    await _storage.write(key:_key(business),value:jsonEncode(rows));
  }
  Future<void> cacheDebtors(String business,List<Map<String,dynamic>> rows)async{
    await _storage.write(key:_key(business)+'_snapshot',value:jsonEncode(rows));
  }
  Future<List<Map<String,dynamic>>> cachedDebtors(String business)async{
    final data=await _storage.read(key:_key(business)+'_snapshot');
    if(data==null)return [];
    return List<Map<String,dynamic>>.from(
      (jsonDecode(data) as List).map((v)=>Map<String,dynamic>.from(v as Map)));
  }
  Future<void> record({
    required String business,required String sale,
    required double amount,required String method,String reference='',
  })async{
    if(!amount.isFinite||amount<=0||((amount*100).round()-(amount*100)).abs()>0.001)
      throw ArgumentError('Enter a valid amount with two decimal places.');
    if(!['Cash','Mobile Money','Bank Transfer','Card'].contains(method))
      throw ArgumentError('Invalid payment method.');
    final rows=await pending(business);
    final safeReference=reference.length>100?reference.substring(0,100):reference;
    rows.add({
      'id':const Uuid().v4(),'sale':sale,'amount':amount,
      'method':method,'reference':safeReference,
      'queued_at':DateTime.now().toUtc().toIso8601String(),
    });
    await _write(business,rows);
    await sync(business);
  }
  Future<double> queuedForSale(String business,String sale)async{
    final rows=await pending(business);
    return rows.where((r)=>r['sale']==sale)
      .fold<double>(0,(sum,r)=>sum+(r['amount'] as num).toDouble());
  }
  Future<int> sync(String business)async{
    if(_syncing)return 0;
    _syncing=true;var confirmed=0;
    try{
      var rows=await pending(business);
      for(final item in List<Map<String,dynamic>>.from(rows)){
        try{
          await _client.rpc('arodesk_add_sale_payment_idempotent',params:{
            'p_business':business,'p_sale':item['sale'],'p_amount':item['amount'],
            'p_method':item['method'],'p_reference':item['reference'],
            'p_request':item['id'],
          }).timeout(const Duration(seconds:7));
          rows=await pending(business);
          rows.removeWhere((e)=>e['id']==item['id']);
          await _write(business,rows);
          confirmed++;
        }catch(_){break;}
      }
      return confirmed;
    }finally{_syncing=false;}
  }
}
