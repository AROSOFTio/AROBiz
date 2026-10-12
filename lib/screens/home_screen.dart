import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/inventory_service.dart';
import '../services/sales_service.dart';
import 'team_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const HomeScreen({super.key,this.onNavigate});
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>{
  bool _loading=true;
  String? _error,_role,_businessName;
  String _currency='USD';
  int _products=0,_lowStock=0,_salesCount=0;
  double _salesTotal=0,_owed=0;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    setState((){_loading=true;_error=null;});
    try{
      final p=DataService().currentProfile;
      final business=await InventoryService.instance.ensureBusiness(
        name:p?.name??'My Business',category:p?.category??'Other');
      final memberships=await TeamService.instance.businesses();
      final role=memberships.where((m)=>m['business_id']==business)
        .map((m)=>m['role'].toString()).firstOrNull;
      final items=await InventoryService.instance.products(business);
      final balances=await InventoryService.instance.balances(business);
      final currency=await InventoryService.instance.businessCurrency(business);
      final transactions=await SalesService.instance.list(business);
      double net=0,owed=0;
      for(final row in transactions){
        if(row['kind']!='sale'||row['currency']!=currency)continue;
        final value=(row['total'] as num).toDouble()-
          ((row['returned_total']??0) as num).toDouble();
        final paid=((row['paid_total']??0) as num).toDouble()-
          ((row['refunded_total']??0) as num).toDouble();
        net+=value;owed+=(value-paid).clamp(0,double.infinity);
      }
      if(mounted)setState((){
        _role=role;_currency=currency;
        final chosen=memberships.where((m)=>m['business_id'].toString()==business).toList();
        _businessName=chosen.isEmpty?null:chosen.first['business_name'].toString();
        _products=items.length;
        _lowStock=items.where((x)=>x['track_stock']==true&&
          (balances[x['id'].toString()]??0)<=(x['reorder_level'] as num).toDouble()).length;
        _salesCount=transactions.where((x)=>x['kind']=='sale').length;
        _salesTotal=net;_owed=owed;
      });
    }catch(_){if(mounted)setState(()=>_error='Unable to refresh business dashboard.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Widget _metric(String label,String value,IconData icon)=>Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius:BorderRadius.circular(14)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:Theme.of(context).colorScheme.primary),
      const SizedBox(height:10),
      Text(value,maxLines:2,overflow:TextOverflow.ellipsis,
        style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:5),Text(label,style:Theme.of(context).textTheme.labelMedium),
    ]));
  Widget _link(String title,IconData icon,int page)=>Card(child:ListTile(
    leading:Icon(icon,color:Theme.of(context).colorScheme.primary),
    title:Text(title),trailing:const Icon(Icons.chevron_right),
    onTap:()=>widget.onNavigate?.call(page)));
  @override Widget build(BuildContext context){
    final f=NumberFormat.currency(name:_currency,symbol:_currency+' ');
    final docs=DataService().invoices.where((v)=>!v.archived).length;
    return RefreshIndicator(onRefresh:_load,child:_loading?
      const Center(child:CircularProgressIndicator()):
      ListView(padding:const EdgeInsets.fromLTRB(16,16,16,50),children:[
        Text('Welcome to ARODesk',style:Theme.of(context).textTheme.headlineSmall),
        Text(_businessName??DataService().currentProfile?.name??'My Business',
          style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:12),
        if(_error!=null)Card(child:Padding(padding:const EdgeInsets.all(14),child:Text(_error!))),
        Wrap(spacing:8,runSpacing:8,children:[
          Chip(label:Text('Role: '+(_role??'Not assigned'))),
          Chip(label:Text('Currency: '+_currency)),
        ]),
        const SizedBox(height:12),
        LayoutBuilder(builder:(ctx,c){
          final cols=c.maxWidth>=600?3:2;
          final w=(c.maxWidth-10*(cols-1))/cols;
          return Wrap(spacing:10,runSpacing:10,children:[
            SizedBox(width:w,child:_metric('Net sales · recent 100',f.format(_salesTotal),Icons.point_of_sale)),
            SizedBox(width:w,child:_metric('Outstanding · recent 100',f.format(_owed),Icons.payments_outlined)),
            SizedBox(width:w,child:_metric('Sales · recent 100',_salesCount.toString(),Icons.receipt_long_outlined)),
            SizedBox(width:w,child:_metric('Catalog items',_products.toString(),Icons.inventory_2_outlined)),
            SizedBox(width:w,child:_metric('Low stock',_lowStock.toString(),Icons.warning_amber_outlined)),
            SizedBox(width:w,child:_metric('Standalone documents',docs.toString(),Icons.description_outlined)),
          ]);
        }),
        const SizedBox(height:20),
        Text('Quick access',style:Theme.of(context).textTheme.titleLarge),
        _link('Products & Inventory',Icons.inventory_2_outlined,2),
        _link('Sales & POS',Icons.point_of_sale_outlined,3),
        _link('Standalone Documents',Icons.description_outlined,1),
        if(_role=='owner'||_role=='admin')
          Card(child:ListTile(
            leading:const Icon(Icons.groups_outlined),
            title:const Text('Manage team & permissions'),
            trailing:const Icon(Icons.chevron_right),
            onTap:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>const TeamScreen())),
          )),
        const SizedBox(height:14),
        const Text('Sales figures are from the latest 100 catalog transactions in the business accounting currency. Standalone documents are not treated as sales.'),
      ]),
    );
  }
}
