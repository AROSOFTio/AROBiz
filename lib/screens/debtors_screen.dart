import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/inventory_service.dart';
import '../services/sales_service.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});
  @override State<DebtorsScreen> createState()=>_DebtorsScreenState();
}
class _DebtorsScreenState extends State<DebtorsScreen> {
  String? _business,_error;
  bool _loading=true;
  List<Map<String,dynamic>> _rows=[];
  String _search='';
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    setState((){_loading=true;_error=null;});
    try{
      final profile=DataService().currentProfile;
      final b=await InventoryService.instance.ensureBusiness(name:profile?.name??'My Business',
        category:profile?.category??'Other');
      final rows=await SalesService.instance.debtors(b);
      if(mounted)setState((){_business=b;_rows=rows;});
    }catch(e){if(mounted)setState(()=>_error='Could not load outstanding credit accounts. Check your connection.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _receive(Map<String,dynamic> row)async{
    if(_business==null)return;
    final outstanding=(row['balance'] as num).toDouble();
    final amount=TextEditingController(text:outstanding.toStringAsFixed(2));
    final reference=TextEditingController();
    String method='Cash';bool saving=false;
    final saved=await showModalBottomSheet<bool>(
      context:context,isScrollControlled:true,useSafeArea:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(18,16,18,
          MediaQuery.viewInsetsOf(ctx).bottom+MediaQuery.viewPaddingOf(ctx).bottom+48),
        child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text('Receive debtor payment',style:Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height:8),
          Text(row['customer_name'].toString()+' • '+row['currency'].toString()+
            ' '+outstanding.toStringAsFixed(2)),
          const SizedBox(height:12),
          TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'Amount received',border:OutlineInputBorder())),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(value:method,
            decoration:const InputDecoration(labelText:'Payment method',border:OutlineInputBorder()),
            items:['Cash','Mobile Money','Bank Transfer','Card']
              .map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
            onChanged:(v)=>update(()=>method=v??'Cash')),
          const SizedBox(height:12),
          TextField(controller:reference,decoration:const InputDecoration(
            labelText:'Reference (optional)',border:OutlineInputBorder())),
          const SizedBox(height:14),
          SizedBox(width:double.infinity,child:FilledButton(
            onPressed:saving?null:()async{
              final value=double.tryParse(amount.text.trim());
              if(value==null||!value.isFinite||value<=0||value>outstanding+0.001){
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content:Text('Enter a payment not exceeding the balance.')));return;
              }
              update(()=>saving=true);
              try{
                await SalesService.instance.addPayment(businessId:_business!,
                  saleId:row['id'].toString(),amount:value,method:method,
                  reference:reference.text.trim());
                if(ctx.mounted)Navigator.pop(ctx,true);
              }catch(_){
                if(ctx.mounted){
                  update(()=>saving=false);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content:Text('Payment was not saved. Refresh balance and retry.')));
                }
              }
            },child:Text(saving?'Recording...':'Record payment')),
          ),
        ]))),
      ));
    amount.dispose();reference.dispose();
    if(saved==true)await _load();
  }
  @override Widget build(BuildContext context){
    final filtered=_rows.where((r)=>[r['customer_name'],r['customer_phone'],
      r['document_number'],r['customer_address']].any((x)=>
        x.toString().toLowerCase().contains(_search.toLowerCase()))).toList();
    final now=DateTime.now();
    final overdue=filtered.where((r)=>r['due_date']!=null&&
      DateTime.tryParse(r['due_date'].toString())?.isBefore(DateTime(now.year,now.month,now.day))==true).length;
    return Scaffold(
      appBar:AppBar(title:const Text('Debtors & receivables')),
      body:RefreshIndicator(onRefresh:_load,child:_loading?
        const Center(child:CircularProgressIndicator()):
        ListView(padding:const EdgeInsets.fromLTRB(16,16,16,56),children:[
          Text('Outstanding customer balances',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),
          Text('${_rows.length} open accounts • $overdue overdue'),
          const SizedBox(height:14),
          TextField(onChanged:(v)=>setState(()=>_search=v),
            decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
              labelText:'Find customer, phone or sale',border:OutlineInputBorder())),
          const SizedBox(height:14),
          if(_error!=null)Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
          if(filtered.isEmpty&&_error==null)const Padding(padding:EdgeInsets.all(28),
            child:Text('No outstanding debt. Fully settled sales disappear from this list.')),
          ...filtered.map((r){
            final due=r['due_date']?.toString();
            final past=due!=null&&DateTime.tryParse(due)?.isBefore(
              DateTime(now.year,now.month,now.day))==true;
            final format=NumberFormat.currency(name:r['currency'].toString(),
              symbol:r['currency'].toString()+' ');
            return Card(child:Padding(padding:const EdgeInsets.all(12),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Expanded(child:Text(r['customer_name'].toString(),
                    style:Theme.of(context).textTheme.titleMedium)),
                  if(past)const Chip(label:Text('Overdue')),
                ]),
                Text(r['document_number'].toString()+' · '+format.format(r['balance'])),
                if(r['customer_phone'].toString().isNotEmpty)
                  Text('Phone: '+r['customer_phone'].toString()),
                if(r['customer_address'].toString().isNotEmpty)
                  Text('Address: '+r['customer_address'].toString()),
                Text('Due: '+(due??'Not set')),
                const SizedBox(height:8),
                Align(alignment:Alignment.centerRight,child:FilledButton.tonalIcon(
                  onPressed:()=>_receive(r),
                  icon:const Icon(Icons.payments_outlined),
                  label:const Text('Receive payment'))),
              ])));
          }),
        ]),
      ),
    );
  }
}
