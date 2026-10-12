import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Protects first-login reset while allowing previously verified sessions to
/// reopen the application without internet access.
class AuthSecurityService{
  AuthSecurityService._();
  static final instance=AuthSecurityService._();
  static const _storage=FlutterSecureStorage();
  String _key(String userId)=>'arodesk_password_gate_'+userId;

  Future<bool> mustChangePassword() async{
    final client=Supabase.instance.client;
    final uid=client.auth.currentUser?.id;
    if(uid==null)throw StateError('Session expired. Sign in again.');
    try{
      final required=await client.rpc('arodesk_password_change_required')
        .timeout(const Duration(seconds:8))==true;
      await _storage.write(key:_key(uid),value:required?'required':'verified');
      return required;
    }catch(_){
      final cached=await _storage.read(key:_key(uid));
      if(cached=='required')return true;
      if(cached=='verified')return false;
      rethrow; // Never treat an unverified login as an approved offline login.
    }
  }

  Future<void> markPasswordUpdated() async{
    final client=Supabase.instance.client;
    final uid=client.auth.currentUser?.id;
    if(uid==null)throw StateError('Sign in again.');
    // Confirm the database trigger cleared the first-login requirement.
    final required=await client.rpc('arodesk_password_change_required')==true;
    if(required)throw StateError('Password update was not confirmed. Retry online.');
    await _storage.write(key:_key(uid),value:'verified');
  }
}
