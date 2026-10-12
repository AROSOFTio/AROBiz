import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamService {
  TeamService._();
  static final instance=TeamService._();
  final client=Supabase.instance.client;
  Future<List<Map<String,dynamic>>> businesses()async{
    final rows=await client.rpc('arodesk_my_businesses');
    return List<Map<String,dynamic>>.from(rows as List);
  }
  Future<List<Map<String,dynamic>>> members(String business)async{
    final rows=await client.rpc('arodesk_team_list_v2',params:{'p_business':business});
    return List<Map<String,dynamic>>.from(rows as List);
  }
  Future<void> add(String business,String email,String role,String title,
      String first,String middle,String last)async{
    final response=await client.functions.invoke('arodesk-team-register',body:{
      'business_id':business,'email':email.trim().toLowerCase(),
      'first_name':first.trim(),'middle_name':middle.trim(),'last_name':last.trim(),
      'role':role,'job_title':title.trim(),
    });
    if(response.status!=200){
      final body=response.data;
      throw Exception(body is Map ? (body['error']??'Unable to register member').toString()
        : 'Unable to register member. Check email service settings.');
    }
  }
  Future<void> update(String business,String user,String role,String title)async{
    await client.rpc('arodesk_team_update',params:{
      'p_business':business,'p_user':user,'p_role':role,'p_title':title.trim()});
  }
  Future<void> remove(String business,String user)async{
    await client.rpc('arodesk_team_remove',params:{
      'p_business':business,'p_user':user});
  }
}
class TeamScreen extends StatefulWidget{
  const TeamScreen({super.key});
  @override State<TeamScreen> createState()=>_TeamScreenState();
}
class _TeamScreenState extends State<TeamScreen>{
  String? _business,_role,_error;
  List<Map<String,dynamic>> _members=[],_businesses=[];
  bool _busy=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    setState((){_busy=true;_error=null;});
    try {
      final businesses=await TeamService.instance.businesses();
      final selected=businesses.isEmpty?null:
        (businesses.any((b)=>b['business_id']==_business)?_business:
          businesses.first['business_id'].toString());
      final role=businesses.where((b)=>b['business_id']==selected)
        .map((b)=>b['role'].toString()).firstOrNull;
      final members=selected==null||!['owner','admin'].contains(role)
        ?<Map<String,dynamic>>[]:await TeamService.instance.members(selected);
      if(mounted)setState((){
        _businesses=businesses;_business=selected;_role=role;_members=members;
      });
    }catch(_){if(mounted)setState(()=>_error='Unable to load team. Check your connection or permissions.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _editor([Map<String,dynamic>? member])async{
    if(_business==null)return;
    final email=TextEditingController(text:member?['email']?.toString()??'');
    final title=TextEditingController(text:member?['job_title']?.toString()??'');
    final first=TextEditingController(text:member?['first_name']?.toString()??'');
    final middle=TextEditingController(text:member?['middle_name']?.toString()??'');
    final last=TextEditingController(text:member?['last_name']?.toString()??'');
    String role=member?['role']?.toString()??'staff';
    bool saving=false;
    final done=await showModalBottomSheet<bool>(
      context:context,isScrollControlled:true,useSafeArea:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(18,18,18,
          MediaQuery.viewInsetsOf(ctx).bottom+
          MediaQuery.viewPaddingOf(ctx).bottom+48),
        child:ConstrainedBox(
          constraints:BoxConstraints(maxHeight:(MediaQuery.sizeOf(ctx).height-
            MediaQuery.viewInsetsOf(ctx).bottom-
            MediaQuery.viewPaddingOf(ctx).bottom-115).clamp(180.0,680.0).toDouble()),
          child:SingleChildScrollView(
            keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
            child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(member==null?'Add team member':'Edit team member',
            style:Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height:14),
          if(member==null)...[
            TextField(controller:first,textCapitalization:TextCapitalization.words,
              decoration:const InputDecoration(labelText:'First name *',border:OutlineInputBorder())),
            const SizedBox(height:12),
            TextField(controller:middle,textCapitalization:TextCapitalization.words,
              decoration:const InputDecoration(labelText:'Middle name (optional)',border:OutlineInputBorder())),
            const SizedBox(height:12),
            TextField(controller:last,textCapitalization:TextCapitalization.words,
              decoration:const InputDecoration(labelText:'Last name *',border:OutlineInputBorder())),
            const SizedBox(height:12),
          ],
          TextField(controller:email,enabled:member==null,
            keyboardType:TextInputType.emailAddress,
            decoration:const InputDecoration(labelText:'Work email address *',
              border:OutlineInputBorder())),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            value:role,
            decoration:const InputDecoration(labelText:'Access role',border:OutlineInputBorder()),
            items:['admin','staff','viewer'].where((v)=>
              _role=='owner'||v!='admin').map((v)=>DropdownMenuItem(
                value:v,child:Text(v=='admin'?'Administrator':
                  v=='staff'?'Staff':'Viewer (read only)'))).toList(),
            onChanged:(v)=>update(()=>role=v??'staff'),
          ),
          const SizedBox(height:12),
          TextField(controller:title,
            decoration:const InputDecoration(
              labelText:'Job title (e.g. Cashier, Storekeeper)',
              border:OutlineInputBorder())),
          const SizedBox(height:12),
          const SizedBox(height:8),
          SizedBox(width:double.infinity,child:FilledButton(
            onPressed:saving?null:()async{
              if(member==null&&(first.text.trim().isEmpty||last.text.trim().isEmpty||
                  !email.text.contains('@'))){
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:Text('First name, last name and a valid email are required.')));
                return;
              }
              update(()=>saving=true);
              try{
                if(member==null){
                  await TeamService.instance.add(_business!,email.text,role,title.text,
                    first.text,middle.text,last.text);
                }else{
                  await TeamService.instance.update(_business!,
                    member['user_id'].toString(),role,title.text);
                }
                if(ctx.mounted)Navigator.pop(ctx,true);
              }catch(e){
                if(ctx.mounted){
                  update(()=>saving=false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:Text(e is PostgrestException ? e.message :
                      e.toString().replaceFirst('Exception: ','').replaceFirst('FunctionException: ',''))));
                }
              }
            },child:Text(saving?'Saving...':'Save member'),
          )),
        ]))))),
    );
    email.dispose();title.dispose();first.dispose();middle.dispose();last.dispose();
    if(done==true)await _load();
  }
  Future<void> _remove(Map<String,dynamic> member)async{
    final yes=await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Remove team member?'),
        content:Text('Remove '+member['email'].toString()+' from this business?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Remove')),
        ]));
    if(yes!=true)return;
    try{await TeamService.instance.remove(_business!,member['user_id'].toString());await _load();}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('Unable to remove team member.')));}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Team & permissions')),
    floatingActionButton:['owner','admin'].contains(_role)?FloatingActionButton.extended(
      onPressed:()=>_editor(),icon:const Icon(Icons.person_add_alt_1),
      label:const Text('Add member')):null,
    body:RefreshIndicator(onRefresh:_load,child:_busy?
      const Center(child:CircularProgressIndicator()):
      ListView(padding:const EdgeInsets.fromLTRB(16,16,16,96),children:[
        Text('Business access',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        if(_businesses.length>1)DropdownButtonFormField<String>(
          value:_business,decoration:const InputDecoration(border:OutlineInputBorder()),
          items:_businesses.map((b)=>DropdownMenuItem(
            value:b['business_id'].toString(),child:Text(b['business_name'].toString()))).toList(),
          onChanged:(v){setState(()=>_business=v);_load();}),
        Text('Your role: '+(_role??'Not assigned')),
        const SizedBox(height:10),
        if(_error!=null)Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        if(!['owner','admin'].contains(_role))const Card(child:Padding(
          padding:EdgeInsets.all(18),child:Text('Only business owners and administrators can manage team access.'))),
        if(_members.isEmpty&&_error==null)const Padding(
          padding:EdgeInsets.all(24),child:Text('No team members to display.')),
        ..._members.map((member)=>Card(child:ListTile(
          leading:CircleAvatar(child:Text(member['role'].toString().substring(0,1).toUpperCase())),
          title:Text([member['first_name'],member['middle_name'],member['last_name']]
            .where((n)=>n!=null&&n.toString().trim().isNotEmpty)
            .join(' ').isEmpty ? member['email'].toString() :
            [member['first_name'],member['middle_name'],member['last_name']]
              .where((n)=>n!=null&&n.toString().trim().isNotEmpty).join(' ')),
          subtitle:Text(member['email'].toString()+' · '+member['role'].toString()+
            (member['job_title'].toString().isEmpty?'':' · '+member['job_title'].toString())),
          trailing:member['role']=='owner'||(member['role']=='admin'&&_role!='owner')
            ?const Icon(Icons.verified_user_outlined)
            :PopupMenuButton<String>(
              onSelected:(action)=>action=='edit'?_editor(member):_remove(member),
              itemBuilder:(_)=>const [
                PopupMenuItem(value:'edit',child:Text('Edit role / title')),
                PopupMenuItem(value:'remove',child:Text('Remove access')),
              ],
            ),
        ))),

      ]),
    ),
  );
}
