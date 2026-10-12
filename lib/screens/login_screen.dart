import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/data_service.dart';
import '../services/auth_security_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'password_security_screen.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String _friendlyAuthError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials') ||
        message.contains('invalid credentials')) {
      return 'Incorrect email or password. Please check your details and try again.';
    }
    if (message.contains('email not confirmed') || message.contains('email_not_confirmed')) {
      return 'Please confirm your email address first. Tap Resend confirmation email below.';
    }
    if (message.contains('too many') || message.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (message.contains('socketexception') || message.contains('host lookup') ||
        message.contains('clientexception') || message.contains('network') ||
        message.contains('connection') || message.contains('timed out')) {
      return 'Cannot connect to ARODesk. Check your internet and try again.';
    }
    return 'Unable to sign in right now. Please try again.';
  }

  Future<void> _login() async {
    if (_identifierCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await DataService().login(_identifierCtrl.text.trim(), _passwordCtrl.text);
      final requiresChange = await AuthSecurityService.instance.mustChangePassword();
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => requiresChange
            ? const PasswordSecurityScreen(forced:true)
            : const AppShell()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyAuthError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendConfirmation() async {
    if (_identifierCtrl.text.trim().isEmpty ||
        !_identifierCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address above first.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await DataService().resendEmailConfirmation(_identifierCtrl.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check your email'),
          content: const Text(
            'If this account is awaiting confirmation, a new ARODesk verification email has been requested. Check Inbox and Spam, then try logging in.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyAuthError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose(){
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset:true,
      body:DecoratedBox(
        decoration:const BoxDecoration(color:Color(0xFFF7F8FA)),
        child:SafeArea(child:Center(child:SingleChildScrollView(
          keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
          padding:EdgeInsets.fromLTRB(18,16,18,
            MediaQuery.viewInsetsOf(context).bottom>0?24:28),
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:430),
            child:Card(
              margin:EdgeInsets.zero,
              elevation:5,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
              child:Padding(
                padding:const EdgeInsets.fromLTRB(24,22,24,22),
                child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Image.asset('assets/logo.png',height:77,width:77,
                    fit:BoxFit.contain,semanticLabel:'ARODesk'),
                  const SizedBox(height:6),
                  const Text('ARODesk',style:TextStyle(
                    fontSize:24,fontWeight:FontWeight.w800,color:Color(0xFF142235))),
                  const SizedBox(height:2),
                  Text('Sign in to your workspace',style:theme.textTheme.bodySmall),
                  const SizedBox(height:21),
                  TextField(
                    controller:_identifierCtrl,
                    keyboardType:TextInputType.emailAddress,
                    textInputAction:TextInputAction.next,
                    autofillHints:const [AutofillHints.email,AutofillHints.username],
                    decoration:const InputDecoration(
                      labelText:'Email address',
                      prefixIcon:Icon(Icons.mail_outline),
                      border:OutlineInputBorder())),
                  const SizedBox(height:12),
                  TextField(
                    controller:_passwordCtrl,
                    obscureText:_obscurePassword,
                    textInputAction:TextInputAction.done,
                    autofillHints:const [AutofillHints.password],
                    onSubmitted:(_){if(!_isLoading)_login();},
                    decoration:InputDecoration(
                      labelText:'Password',
                      prefixIcon:const Icon(Icons.lock_outline),
                      border:const OutlineInputBorder(),
                      suffixIcon:IconButton(
                        tooltip:_obscurePassword?'Show password':'Hide password',
                        icon:Icon(_obscurePassword?Icons.visibility_outlined:
                          Icons.visibility_off_outlined),
                        onPressed:()=>setState(()=>_obscurePassword=!_obscurePassword)))),
                  Align(alignment:Alignment.centerRight,
                    child:TextButton(
                      onPressed:_isLoading?null:()=>Navigator.push(context,
                        MaterialPageRoute(builder:(_)=>const ForgotPasswordScreen())),
                      child:const Text('Forgot password?'))),
                  SizedBox(width:double.infinity,height:48,
                    child:FilledButton(
                      onPressed:_isLoading?null:_login,
                      child:_isLoading
                        ?const SizedBox(width:20,height:20,
                          child:CircularProgressIndicator(strokeWidth:2))
                        :const Text('Sign in'))),
                  const SizedBox(height:10),
                  Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                    const Flexible(child:Text('New to ARODesk?',
                      style:TextStyle(fontSize:12))),
                    TextButton(
                      onPressed:_isLoading?null:()=>Navigator.push(context,
                        MaterialPageRoute(builder:(_)=>const RegisterScreen())),
                      child:const Text('Create account')),
                  ]),
                  PopupMenuButton<String>(
                    tooltip:'Account help',
                    initialValue:null,
                    onSelected:(value){
                      if(value=='resend')_resendConfirmation();
                      if(value=='privacy')launchUrl(Uri.parse(
                        'https://github.com/AROSOFTio/AROBiz/blob/main/play-compliance/README.md#privacy-policy'),
                        mode:LaunchMode.externalApplication);
                    },
                    itemBuilder:(_)=>const [
                      PopupMenuItem(value:'resend',child:Text('Resend verification email')),
                      PopupMenuItem(value:'privacy',child:Text('Privacy policy')),
                    ],
                    child:const Padding(
                      padding:EdgeInsets.symmetric(horizontal:12,vertical:6),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        Text('Account help',style:TextStyle(fontSize:12)),
                        Icon(Icons.expand_more,size:17),
                      ])),
                  ),
                ]),
              ),
            ),
          ),
        ))),
      ),
    );
  }
}
