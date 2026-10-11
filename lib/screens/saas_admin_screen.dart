import 'package:flutter/material.dart';
import '../services/saas_admin_service.dart';

class SaaSAdminScreen extends StatefulWidget {
  const SaaSAdminScreen({super.key});
  @override
  State<SaaSAdminScreen> createState()=>_SaaSAdminScreenState();
}

class _SaaSAdminScreenState extends State<SaaSAdminScreen> {
  bool _loading=true,_authorized=false;
  String? _error;
  Map<String,dynamic> _stats={};
  List<Map<String,dynamic>> _tenants=[];
  String _search='';
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{
    setState((){_loading=true;_error=null;});
    try{
      final auth=await SaaSAdminService.instance.isAdmin();
      if(!auth){if(mounted)setState(()=>_authorized=false);return;}
      final stats=await SaaSAdminService.instance.overview();
      final tenants=await SaaSAdminService.instance.tenants();
      if(mounted)setState((){
        _authorized=true;_stats=stats;_tenants=tenants;
      });
    }catch(e){
      if(mounted)setState(()=>_error='Unable to load platform administration. Check your access and connection.');
    }finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _setStatus(Map<String,dynamic> tenant,String next)async{
    final allowed=await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(next=='suspended'?'Suspend business?':'Reactivate business?'),
        content:Text('Business: '+tenant['name'].toString()+
          (next=='suspended'?
            '\nThis may interrupt access for its team. Existing records will be retained.':
            '\nRe-enable access to this tenant.')),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirm')),
        ],
      ));
    if(allowed!=true)return;
    try{
      await SaaSAdminService.instance.setTenant(id:tenant['id'].toString(),
        status:next,trialEnd:tenant['trial_end']?.toString());
      await _load();
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Could not update tenant. Check your administrator permissions.')));
    }
  }
  Future<void> _setTrial(Map<String,dynamic> tenant)async{
    final now=DateTime.now();
    final picked=await showDatePicker(context:context,
      firstDate:DateTime(now.year-1),lastDate:DateTime(now.year+10),
      initialDate:now.add(const Duration(days:14)));
    if(picked==null)return;
    try{
      await SaaSAdminService.instance.setTenant(
        id:tenant['id'].toString(),status:tenant['status'].toString(),
        trialEnd:DateTime(picked.year,picked.month,picked.day,23,59,59).toUtc().toIso8601String());
      await _load();
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Trial date could not be updated.')));
    }
  }

  @override
  Widget build(BuildContext context){
    final visible=_tenants.where((t)=>[t['name'],t['owner_email'],t['category']]
      .any((x)=>x.toString().toLowerCase().contains(_search.toLowerCase()))).toList();
    return Scaffold(
      appBar:AppBar(title:const Text('ARODesk SaaS Admin')),
      body:RefreshIndicator(onRefresh:_load,
        child:_loading?const Center(child:CircularProgressIndicator()):
        !_authorized?ListView(children:const [
          SizedBox(height:80),
          Icon(Icons.admin_panel_settings_outlined,size:64),
          Padding(padding:EdgeInsets.all(24),child:Text(
            'Platform administrator access required. Business-owner accounts are not platform administrators.',
            textAlign:TextAlign.center)),
        ]):ListView(padding:const EdgeInsets.all(16),children:[
          Text('Platform overview',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),
          if(_error!=null)Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
          Wrap(spacing:8,runSpacing:8,children:[
            _metric('Businesses',_stats['businesses']),
            _metric('Users',_stats['users']),
            _metric('Active',_stats['active_tenants']),
            _metric('Suspended',_stats['suspended_tenants']),
            _metric('Products',_stats['products']),
            _metric('Sales',_stats['sales']),
          ]),
          const SizedBox(height:22),
          Text('Tenant management',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:12),
          TextField(onChanged:(v)=>setState(()=>_search=v),
            decoration:const InputDecoration(labelText:'Find business or owner',
              prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
          const SizedBox(height:12),
          if(visible.isEmpty)const Padding(padding:EdgeInsets.all(24),
            child:Text('No matching businesses.',textAlign:TextAlign.center)),
          ...visible.map((tenant)=>Card(child:Padding(
            padding:const EdgeInsets.all(12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text(tenant['name'].toString(),style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:6),
              Text('Owner: '+(tenant['owner_email']??'Unknown').toString()),
              Text('Industry: '+(tenant['category']??'Other').toString()+
                ' · Currency: '+tenant['currency'].toString()),
              Text('Status: '+tenant['status'].toString()),
              if(tenant['trial_end']!=null)
                Text('Trial ends: '+tenant['trial_end'].toString().substring(0,10)),
              const SizedBox(height:8),
              Wrap(spacing:8,children:[
                OutlinedButton.icon(
                  onPressed:()=>_setTrial(tenant),
                  icon:const Icon(Icons.event,size:18),
                  label:const Text('Trial date'),
                ),
                FilledButton.tonalIcon(
                  onPressed:()=>_setStatus(tenant,
                    tenant['status']=='suspended'?'active':'suspended'),
                  icon:Icon(tenant['status']=='suspended'?Icons.play_arrow:Icons.pause_circle_outline,size:18),
                  label:Text(tenant['status']=='suspended'?'Reactivate':'Suspend'),
                ),
              ]),
            ]),
          ))),
        ]),
      ),
    );
  }

  Widget _metric(String label,dynamic value)=>Container(
    width:145,padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),
      color:Theme.of(context).colorScheme.surfaceContainerHighest),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:Theme.of(context).textTheme.labelMedium),
      const SizedBox(height:6),
      Text((value??0).toString(),style:Theme.of(context).textTheme.headlineSmall),
    ]),
  );
}
