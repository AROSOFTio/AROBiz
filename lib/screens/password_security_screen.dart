import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class PasswordSecurityScreen extends StatefulWidget {
  final bool recovery;
  final bool forced;
  const PasswordSecurityScreen({super.key,this.recovery=false,this.forced=false});
  @override
  State<PasswordSecurityScreen> createState()=>_PasswordSecurityScreenState();
}
class _PasswordSecurityScreenState extends State<PasswordSecurityScreen> {
  final _current=TextEditingController(),_next=TextEditingController(),
    _confirm=TextEditingController();
  bool _busy=false,_show=false;
  String? _message;
  bool _success=false;
  @override
  void dispose(){_current.dispose();_next.dispose();_confirm.dispose();super.dispose();}
  bool get _valid {
    final text=_next.text;
    return text.length>=6 && RegExp(r'[A-Z]').hasMatch(text) &&
      RegExp(r'[a-z]').hasMatch(text) &&
      RegExp(r'[^a-zA-Z0-9]').hasMatch(text);
  }
  Future<void> _save() async {
    if(!_valid||_confirm.text!=_next.text){
      setState(()=>_message='Use at least 6 characters, including uppercase, lowercase and a special character. Passwords must match.');
      return;
    }
    final auth=Supabase.instance.client.auth;
    final user=auth.currentUser;
    if(user==null){setState(()=>_message='Sign in or open your password reset link again.');return;}
    if(!widget.recovery && !widget.forced && _current.text.isEmpty){setState(()=>_message='Enter your current password.');return;}
    setState((){_busy=true;_message=null;});
    try {
      if(!widget.recovery && !widget.forced){
        // Verify the current password before changing an active session.
        await auth.signInWithPassword(email:user.email,password:_current.text);
      }
      await auth.updateUser(UserAttributes(password:_next.text));
      if(mounted){
        setState((){_success=true;_message='Password updated successfully.';});
        if(widget.forced){
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
            builder:(_)=>const AppShell()),(_)=>false);
        }
      }
    } on AuthException catch(e) {
      if(mounted)setState(()=>_message=e.message.toLowerCase().contains('invalid')
        ?'Incorrect current password or expired recovery link.'
        :'Could not change password. Please check your connection and try again.');
    } catch(_) {
      if(mounted)setState(()=>_message='Unable to update password. Please retry.');
    } finally {if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(automaticallyImplyLeading:!widget.forced,
      title:Text(widget.forced?'Set your new password':widget.recovery?'Reset password':'Change password')),

    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:480),
      child:ListView(padding:const EdgeInsets.all(22),children:[
        const Center(child:Image(image:AssetImage('assets/logo.png'),height:82,width:82)),
        const SizedBox(height:16),
        Text(widget.recovery?'Choose your new password':'Secure your ARODesk account',
          textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:20),
        if(widget.forced)const Padding(padding:EdgeInsets.only(bottom:16),
          child:Text('Business access remains locked until you choose a new password.')),
        if(!widget.recovery && !widget.forced)...[
          TextField(controller:_current,obscureText:!_show,
            decoration:const InputDecoration(labelText:'Current password',border:OutlineInputBorder())),
          const SizedBox(height:14),
        ],
        TextField(controller:_next,obscureText:!_show,
          decoration:const InputDecoration(labelText:'New password',border:OutlineInputBorder())),
        const SizedBox(height:14),
        TextField(controller:_confirm,obscureText:!_show,
          decoration:const InputDecoration(labelText:'Confirm new password',border:OutlineInputBorder())),
        CheckboxListTile(
          contentPadding:EdgeInsets.zero,
          title:const Text('Show passwords'),value:_show,
          onChanged:(v)=>setState(()=>_show=v??false)),
        const Text('Minimum 6 characters, including uppercase, lowercase and a special character.'),
        if(_message!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),
          child:Text(_message!,style:TextStyle(color:_success?Colors.green:Theme.of(context).colorScheme.error))),
        const SizedBox(height:12),
        FilledButton(onPressed:_busy||_success?null:_save,
          child:Text(_busy?'Updating...':'Update password')),
        if(_success && !widget.forced) TextButton(onPressed:()=>Navigator.maybePop(context),
          child:const Text('Close')),
      ]),
    ))),
  );
}
