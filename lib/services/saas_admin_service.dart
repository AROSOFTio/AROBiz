import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform operators are independent of tenant membership.
/// Every read or mutation is re-authorized inside PostgreSQL.
class SaaSAdminService {
  SaaSAdminService._();
  static final SaaSAdminService instance=SaaSAdminService._();
  final _client=Supabase.instance.client;

  Future<bool> isAdmin() async {
    if (_client.auth.currentUser==null) return false;
    try {
      final result=await _client.rpc('arodesk_am_i_platform_admin');
      return result==true;
    }catch(_){return false;}
  }
  Future<Map<String,dynamic>> overview() async {
    final data=await _client.rpc('arodesk_admin_overview');
    return Map<String,dynamic>.from(data as Map);
  }
  Future<List<Map<String,dynamic>>> tenants() async {
    final data=await _client.rpc('arodesk_admin_list_tenants');
    return List<Map<String,dynamic>>.from(data as List);
  }
  Future<void> setTenant({
    required String id,required String status,String? trialEnd,
  }) async {
    await _client.rpc('arodesk_admin_set_tenant',params:{
      'p_business':id,'p_status':status,'p_trial_end':trialEnd,
    });
  }
}
