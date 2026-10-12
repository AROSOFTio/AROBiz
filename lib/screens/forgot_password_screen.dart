import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState()=>_ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>{
  final _email=TextEditingController();
  bool _busy=false;
  String? _result;
  @override void dispose(){_email.dispose();super.dispose();}
  Future<void> _request()async{
    final email=_email.text.trim().toLowerCase();
    if(!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)){
      setState(()=>_result='Enter a valid email address.');return;
    }
    setState((){_busy=true;_result=null;});
    try{
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,redirectTo:'io.supabase.arodesk://reset-password/',
      );
      if(mounted)setState(()=>_result=
        'If this email has an account, a reset link has been sent. Check Inbox and Spam.');
    }catch(_){
      if(mounted)setState(()=>_result='Unable to request a reset. Check internet access and retry.');
    }finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Forgot password')),
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:460),
      child:ListView(padding:const EdgeInsets.all(24),children:[
        Image.asset('assets/logo.png',height:100,width:100),
        const SizedBox(height:20),
        Text('Recover your ARODesk account',textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:10),
        const Text('Enter the email used to create your account. We will send a secure reset link.',
          textAlign:TextAlign.center),
        const SizedBox(height:24),
        TextField(controller:_email,keyboardType:TextInputType.emailAddress,
          decoration:const InputDecoration(labelText:'Account email',
          prefixIcon:Icon(Icons.email_outlined),border:OutlineInputBorder())),
        const SizedBox(height:16),
        FilledButton(onPressed:_busy?null:_request,
          child:Text(_busy?'Sending...':'Send password reset link')),
        if(_result!=null)Padding(padding:const EdgeInsets.only(top:16),child:Text(_result!)),
      ]),
    ))),
  );
}
