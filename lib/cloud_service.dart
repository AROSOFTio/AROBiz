import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'business_document.dart';
import 'document_store.dart';

const cloudUrl='https://crownfiles.arosoftlabs.com/business-docs/api/v1';
class CloudService {
  CloudService(this.prefs,{http.Client? client}):client=client??http.Client();
  final SharedPreferences prefs;
  final http.Client client;
  String? token,username;
  bool get analytics=>prefs.getBool('cloud_usage_consent')??false;
  static const queueKey='cloud_usage_queue';
  static const installKey='cloud_usage_install';
  Future<void> _tail=Future.value();
  Future<T> _serial<T>(Future<T> Function() work){
    final next=_tail.then((_)=>work());
    _tail=next.then<void>((_) {},onError:(Object e,StackTrace st){});
    return next;
  }
  Future<Map<String,dynamic>> request(String method,String path,{Map<String,dynamic>? data,bool authenticated=false})async{
    final req=http.Request(method,Uri.parse('$cloudUrl/$path'));
    req.headers['Accept']='application/json';
    if(authenticated){
      if(token==null)throw StateError('Sign in first.');
      req.headers['Authorization']='Bearer $token';
    }
    if(data!=null){req.headers['Content-Type']='application/json';req.body=jsonEncode(data);}
    final res=await client.send(req).then(http.Response.fromStream).timeout(const Duration(seconds:12));
    Map<String,dynamic> result;
    try{result=Map<String,dynamic>.from(jsonDecode(res.body) as Map);}
    catch(_){throw StateError('Cloud service unavailable. Your local documents are safe.');}
    if(res.statusCode<200||res.statusCode>=300){
      throw StateError(result['error']?.toString()??'Cloud request failed.');
    }
    return result;
  }
  Future<void> authenticate(String name,String password,{bool register=false})async{
    final res=await request('POST',register?'register':'login',data:{'username':name,'password':password});
    token=res['token'] as String;username=res['username'] as String;
  }
  Future<void> logout()async{
    try{if(token!=null)await request('POST','logout',authenticated:true);}
    finally{token=null;username=null;}
  }
  Future<void> deleteAccount(String password)async{
    await request('DELETE','account',authenticated:true,data:{'password':password});
    token=null;username=null;
  }
  Future<int> backup(DocumentStore store)async{
    final docs=store.documents();
    final r=await request('PUT','backup',authenticated:true,data:{
      'profile':store.profile().toJson(),
      'documents':docs.map((d)=>d.toJson()).toList(),
    });
    return r['documents'] as int;
  }
  Future<int> restore(DocumentStore store)async{
    final r=await request('GET','backup',authenticated:true);
    final raw=Map<String,dynamic>.from(r['backup'] as Map);
    final docs=(raw['documents'] as List).map((j)=>BusinessDocument.fromJson(Map<String,dynamic>.from(j as Map))).toList();
    final profile=BusinessInfo.fromJson(Map<String,dynamic>.from(raw['profile'] as Map));
    return store.mergeBackup(docs,profile);
  }
  Future<void> deleteBackup()async{await request('DELETE','backup',authenticated:true);}
  Future<void> setConsent(bool enabled) => _serial(()async{
    await prefs.setBool('cloud_usage_consent',enabled);
    if(enabled){
      await _record('app_open',null);
    }else{
      await prefs.remove(queueKey);
    }
  });
  Future<void> eraseAnalytics()=>_serial(()async{
    final installation=prefs.getString(installKey);
    if(installation!=null)await request('DELETE','usage',data:{'installation':installation});
    await prefs.setBool('cloud_usage_consent',false);
    await prefs.remove(installKey);
    await prefs.remove(queueKey);
  });
  Future<void> event(String name,{DocKind? kind})=>_serial(()async{
    if(analytics)await _record(name,kind);
  });
  Future<void> _record(String name,DocKind? kind)async{
    if(!analytics)return;
    var id=prefs.getString(installKey);
    if(id==null){id=const Uuid().v4();await prefs.setString(installKey,id);}
    final pending=prefs.getStringList(queueKey)??[];
    pending.add(jsonEncode({'id':const Uuid().v4(),'event':name,'kind':kind?.name??''}));
    if(pending.length>500)pending.removeRange(0,pending.length-500);
    await prefs.setStringList(queueKey,pending);
    try{
      while(pending.isNotEmpty&&analytics){
        final batch=pending.take(100).map(jsonDecode).toList();
        await request('POST','usage',data:{'installation':id,'events':batch});
        pending.removeRange(0,batch.length);
        await prefs.setStringList(queueKey,pending);
      }
    }catch(_){/* No connection: keep a bounded queue for the next opted-in event. */}
  }
}
CloudService? cloud;
void recordUsage(String event,{DocKind? kind}){
  final service=cloud;
  if(service!=null&&service.analytics)unawaited(service.event(event,kind:kind).catchError((Object _){}));
}

class CloudSettings extends StatefulWidget {
  const CloudSettings({super.key,required this.store});
  final DocumentStore store;
  @override
  State<CloudSettings> createState()=>_CloudSettingsState();
}
class _CloudSettingsState extends State<CloudSettings>{
  late final CloudService service;
  final username=TextEditingController(),password=TextEditingController();
  bool busy=false,creating=false;
  @override
  void initState(){super.initState();service=cloud??=CloudService(widget.store.preferences);}
  @override
  void dispose(){username.dispose();password.dispose();super.dispose();}
  void notice(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> run(Future<void> Function() action)async{
    if(busy)return;
    setState(()=>busy=true);
    try{await action();}
    catch(e){notice(e.toString().replaceFirst('Bad state: ',''));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<bool> confirm(String title,String message)async{
    return await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text(title),content:Text(message),actions:[
        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Continue')),
      ]))??false;
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Account & privacy')),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      const Text('Optional cloud account',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      const Text('You can use every document generator offline, without signing in. An account lets you make and restore an encrypted cloud backup.'),
      const SizedBox(height:16),
      if(service.token==null)...[
        TextField(controller:username,decoration:const InputDecoration(labelText:'Username'),autocorrect:false,maxLength:32),
        const SizedBox(height:8),
        TextField(controller:password,decoration:const InputDecoration(labelText:'Password (12+ characters)'),obscureText:true,autocorrect:false,enableSuggestions:false),
        const SizedBox(height:12),
        FilledButton(onPressed:busy?null:()=>run(()async{
          await service.authenticate(username.text.trim(),password.text,register:creating);
          password.clear();notice('Signed in.');
        }),child:Text(creating?'Create account':'Sign in')),
        TextButton(onPressed:busy?null:()=>setState(()=>creating=!creating),child:Text(creating?'Already registered? Sign in':'Create an optional account')),
        const Text('Keep your password safe. Password recovery is not available in this initial account version.',style:TextStyle(fontSize:12,color:Colors.black54)),
      ]else...[
        Text('Signed in as ${service.username}',style:const TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:busy?null:()=>run(()async{
          if(!await confirm('Replace cloud backup?','Upload all documents and saved business details from this device to your account. This replaces the previous cloud backup.'))return;
          final count=await service.backup(widget.store);notice('Cloud backup saved: $count documents.');
        }),icon:const Icon(Icons.cloud_upload_outlined),label:const Text('Back up documents')),
        const SizedBox(height:8),
        OutlinedButton.icon(onPressed:busy?null:()=>run(()async{
          if(!await confirm('Restore backup?','Add missing documents from your account to this device. Existing local records will not be overwritten.'))return;
          final count=await service.restore(widget.store);notice('Restored $count new documents.');
        }),icon:const Icon(Icons.cloud_download_outlined),label:const Text('Restore documents')),
        TextButton(onPressed:busy?null:()=>run(()async{
          if(await confirm('Delete cloud backup?','This removes only the online copy. Local documents are kept.')){await service.deleteBackup();notice('Cloud backup deleted.');}
        }),child:const Text('Delete cloud backup')),
        OutlinedButton(onPressed:busy?null:()=>run(()async{await service.logout();notice('Signed out.');}),child:const Text('Sign out')),
        const SizedBox(height:12),
        TextField(controller:password,decoration:const InputDecoration(labelText:'Confirm password to delete account'),obscureText:true,autocorrect:false,enableSuggestions:false),
        TextButton(onPressed:busy?null:()=>run(()async{
          if(!await confirm('Delete account permanently?','Your online account and backup will be removed. Local documents are kept.'))return;
          await service.deleteAccount(password.text);password.clear();notice('Account deleted.');
        }),child:const Text('Delete online account',style:TextStyle(color:Color(0xFFB42318)))),
      ],
      if(busy)const LinearProgressIndicator(),
      const SizedBox(height:24),
      const Divider(),
      const SizedBox(height:12),
      const Text('Usage analytics',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      const Text('Help improve the app by sharing anonymous usage statistics: app opens, document types generated, saves, and share or print requests. No document text, names, contacts, amounts or PDFs are collected. Reports use a random installation identifier and are kept for up to 90 days.'),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Share optional usage analytics'),value:service.analytics,onChanged:busy?null:(v)=>run(()=>service.setConsent(v))),
      TextButton(onPressed:busy?null:()=>run(()async{
        if(await confirm('Erase usage history?','Remove this installation’s uploaded analytics and turn off future reporting. Internet access is required.')){await service.eraseAnalytics();notice('Usage history erased.');}
      }),child:const Text('Erase my analytics history')),
      const Text('If you turn reporting off, queued events are discarded. Nothing is collected unless you opt in.',style:TextStyle(fontSize:12,color:Colors.black54)),
    ]),
  );
}

