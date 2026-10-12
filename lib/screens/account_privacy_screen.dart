import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'password_security_screen.dart';

class AccountPrivacyScreen extends StatefulWidget{
  const AccountPrivacyScreen({super.key});
  @override State<AccountPrivacyScreen> createState()=>_AccountPrivacyScreenState();
}
class _AccountPrivacyScreenState extends State<AccountPrivacyScreen>{
  bool _submitting=false;
  static const _privacy='https://github.com/AROSOFTio/AROBiz/blob/main/play-compliance/README.md#privacy-policy';
  static const _delete='https://github.com/AROSOFTio/AROBiz/blob/main/play-compliance/README.md#request-account-deletion';
  Future<void> _open(String url)async{
    try{
      if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication)){
        throw StateError('Could not open website.');
      }
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Unable to open website.')));
    }
  }
  Future<void> _requestDelete()async{
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Request account deletion'),
      content:const Text('Your request will be verified. Some business records may need to be retained for legal reasons.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Continue')),
      ]));
    if(confirmed!=true)return;
    setState(()=>_submitting=true);
    try{
      await Supabase.instance.client.rpc('arodesk_request_account_deletion');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Account deletion request submitted.')));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Could not submit request. Please try again.')));
    }finally{if(mounted)setState(()=>_submitting=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Account & privacy')),
    body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:ListTile(
        leading:const Icon(Icons.account_circle_outlined),
        title:Text(Supabase.instance.client.auth.currentUser?.email??'Your account'),
        subtitle:const Text('Signed-in account'))),
      Card(child:ListTile(
        leading:const Icon(Icons.lock_reset_outlined),
        title:const Text('Change password'),
        trailing:const Icon(Icons.chevron_right),
        onTap:()=>Navigator.push(context,MaterialPageRoute(
          builder:(_)=>const PasswordSecurityScreen())))),
      Card(child:ListTile(
        leading:const Icon(Icons.privacy_tip_outlined),
        title:const Text('Privacy policy'),
        trailing:const Icon(Icons.open_in_new),
        onTap:()=>_open(_privacy))),
      Card(child:ListTile(
        leading:const Icon(Icons.delete_outline),
        title:const Text('Request account deletion'),
        trailing:_submitting?const SizedBox(width:20,height:20,
          child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.chevron_right),
        onTap:_submitting?null:_requestDelete)),
      TextButton(onPressed:()=>_open(_delete),
        child:const Text('Web deletion request')),
    ])),
  );
}
