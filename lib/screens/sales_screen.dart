import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../services/data_service.dart';
import '../services/inventory_service.dart';
import '../services/sales_service.dart';
import 'invoice_preview_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String? _businessId, _error;
  List<Map<String,dynamic>> _products=[], _transactions=[];
  Map<String,double> _balances={};
  bool _loading=true;
  @override
  void initState(){super.initState();_refresh();}
  String _message(Object error){
    final t=error.toString().toLowerCase();
    if(t.contains('insufficient stock'))return 'Insufficient stock for one or more items. Check inventory and retry.';
    if(t.contains('network')||t.contains('connection')||t.contains('socket'))return 'Check your internet connection and try again.';
    if(t.contains('not authorized')||t.contains('permission'))return 'Your account cannot record sales for this business.';
    return 'Transaction could not be completed. Please try again.';
  }
  Future<void> _refresh()async{
    setState((){_loading=true;_error=null;});
    try{
      final profile=DataService().currentProfile;
      final business=await InventoryService.instance.ensureBusiness(
        name:profile?.name??'My Business',category:profile?.category??'Other');
      final products=await InventoryService.instance.products(business);
      final balances=await InventoryService.instance.balances(business);
      final transactions=await SalesService.instance.list(business);
      if(mounted)setState((){
        _businessId=business;_products=products;_balances=balances;_transactions=transactions;
      });
    }catch(e){if(mounted)setState(()=>_error=_message(e));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Invoice _toInvoice(Map<String,dynamic> sale) {
    final rows=List<Map<String,dynamic>>.from(
      (sale['lines'] as List).map((r)=>Map<String,dynamic>.from(r as Map)));
    return Invoice(
      id:sale['id'].toString(),
      invoiceNumber:sale['document_number'].toString(),
      issueDate:DateTime.parse(sale['created_at'].toString()),
      clientName:sale['customer_name'].toString(),
      clientPhone:(sale['customer_phone']??'').toString(),
      items:rows.map((r)=>InvoiceItem(
        description:r['description'].toString(),
        quantity:(r['quantity'] as num).toInt(),
        unitPrice:(r['unit_price'] as num).toDouble(),
      )).toList(),
      type:sale['kind']=='quotation'?DocumentType.quotation:DocumentType.receipt,
      paymentOption:sale['payment_method']?.toString(),
      notes:sale['kind']=='sale'?'Generated from ARODesk Sales': 'Catalog quotation · Stock not deducted',
    );
  }
  Future<void> _preview(String id)async{
    if(_businessId==null)return;
    try{
      final row=await SalesService.instance.byId(_businessId!,id);
      if(mounted)await Navigator.of(context).push(MaterialPageRoute(
        builder:(_)=>InvoicePreviewScreen(invoice:_toInvoice(row))));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(_message(e))));}
  }
  Future<void> _new(String kind)async{
    if(_businessId==null)return;
    final id=await Navigator.of(context).push<String>(MaterialPageRoute(
      builder:(_)=>_SalesWizard(
        businessId:_businessId!,kind:kind,products:_products,balances:_balances)));
    if(id!=null&&mounted){
      await _refresh();
      if(mounted)await _preview(id);
    }
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      body:RefreshIndicator(onRefresh:_refresh,child:_loading?
        const Center(child:CircularProgressIndicator()):
        ListView(padding:const EdgeInsets.all(16),children:[
          Text('Sales & POS',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:6),
          const Text('Record sales and issue catalog-based quotations. Standalone documents remain separate.'),
          const SizedBox(height:16),
          if(_error!=null)...[
            Card(color:Theme.of(context).colorScheme.errorContainer,
              child:Padding(padding:const EdgeInsets.all(16),child:Text(_error!))),
            TextButton(onPressed:_refresh,child:const Text('Retry')),
          ]else...[
            Row(children:[
              Expanded(child:FilledButton.icon(onPressed:()=>_new('sale'),
                icon:const Icon(Icons.point_of_sale),label:const Text('New sale'))),
              const SizedBox(width:8),
              Expanded(child:OutlinedButton.icon(onPressed:()=>_new('quotation'),
                icon:const Icon(Icons.request_quote),label:const Text('Quotation'))),
            ]),
            const SizedBox(height:20),
            Text('Recent transactions',style:Theme.of(context).textTheme.titleMedium),
            if(_transactions.isEmpty)const Padding(
              padding:EdgeInsets.all(25),child:Text('No sales or quotations yet.',textAlign:TextAlign.center)),
            ..._transactions.map((item)=>Card(child:ListTile(
              leading:Icon(item['kind']=='sale'?Icons.receipt_long:Icons.request_quote),
              title:Text(item['document_number'].toString()),
              subtitle:Text(item['customer_name'].toString()+' · '+item['kind'].toString()),
              trailing:const Icon(Icons.chevron_right),
              onTap:()=>_preview(item['id'].toString()),
            ))),
          ],
        ]),
      ),
    );
  }
}

class _SalesWizard extends StatefulWidget {
  final String businessId,kind;
  final List<Map<String,dynamic>> products;
  final Map<String,double> balances;
  const _SalesWizard({required this.businessId,required this.kind,
    required this.products,required this.balances});
  @override
  State<_SalesWizard> createState()=>_SalesWizardState();
}
class _SalesWizardState extends State<_SalesWizard> {
  final _customer=TextEditingController(text:'Walk-in customer');
  final _phone=TextEditingController();
  final Map<String,double> _cart={};
  int _step=0;
  String _method='Cash';
  String? _error;
  bool _saving=false;
  @override
  void dispose(){_customer.dispose();_phone.dispose();super.dispose();}
  Map<String,dynamic>? _product(String id){
    for(final p in widget.products){if(p['id'].toString()==id)return p;}
    return null;
  }
  double get _total{
    double sum=0;
    for(final entry in _cart.entries){
      final p=_product(entry.key);
      if(p!=null)sum+=((p['sale_price'] as num).toDouble()*entry.value);
    }
    return sum;
  }
  void _add(Map<String,dynamic> p){
    final id=p['id'].toString();
    final existing=_cart[id]??0;
    final available=widget.balances[id]??0;
    if(widget.kind=='sale'&&p['track_stock']==true&&existing+1>available){
      setState(()=>_error='Not enough stock available for '+p['name'].toString());
      return;
    }
    setState((){_cart[id]=existing+1;_error=null;});
  }
  void _remove(String id){
    setState((){
      final qty=_cart[id]??0;
      if(qty<=1){_cart.remove(id);}else{_cart[id]=qty-1;}
      _error=null;
    });
  }
  void _next(){
    if(_step==0&&_cart.isEmpty){setState(()=>_error='Select at least one item.');return;}
    if(_step==1&&_customer.text.trim().isEmpty){
      setState(()=>_error='Enter the customer name.');return;
    }
    setState((){_step++;_error=null;});
  }
  Future<void> _save()async{
    if(_saving)return;
    setState((){_saving=true;_error=null;});
    try{
      final id=await SalesService.instance.record(
        businessId:widget.businessId,
        kind:widget.kind,
        quantities:_cart,
        customer:_customer.text.trim(),
        phone:_phone.text.trim(),
        paymentMethod:_method,
      );
      if(mounted)Navigator.pop(context,id);
    }catch(e){
      if(mounted)setState((){
        final t=e.toString().toLowerCase();
        _error=t.contains('insufficient stock')
          ? 'Insufficient stock. Refresh inventory and retry.'
          : 'Could not save the transaction. Please check your details and connection.';
      });
    }finally{if(mounted)setState(()=>_saving=false);}
  }
  @override
  Widget build(BuildContext context){
    final isSale=widget.kind=='sale';
    return Scaffold(
      appBar:AppBar(title:Text(isSale?'New sale':'Catalog quotation')),
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:650),
        child:Column(children:[
          Padding(padding:const EdgeInsets.all(16),child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text('Step '+(_step+1).toString()+' of 3'),
              const SizedBox(height:8),
              LinearProgressIndicator(value:(_step+1)/3),
              const SizedBox(height:12),
              Text(['Select products','Customer & payment','Review'][_step],
                style:Theme.of(context).textTheme.titleLarge),
            ])),
          if(_error!=null)Card(color:Theme.of(context).colorScheme.errorContainer,
            child:Padding(padding:const EdgeInsets.all(12),child:Text(_error!))),
          Expanded(child:SingleChildScrollView(
            padding:const EdgeInsets.symmetric(horizontal:16),
            child:_step==0?Column(children:[
              if(widget.products.isEmpty)const Padding(padding:EdgeInsets.all(20),
                child:Text('Add products in Products & Inventory before using Sales.')),
              ...widget.products.map((p){
                final id=p['id'].toString();
                final track=p['track_stock']==true;
                final balance=widget.balances[id]??0;
                final qty=_cart[id]??0;
                return Card(child:Padding(padding:const EdgeInsets.all(8),
                  child:Column(children:[
                    ListTile(
                      title:Text(p['name'].toString(),maxLines:2),
                      subtitle:Text('Price: '+p['sale_price'].toString()+
                        (track?' · In stock: '+balance.toString():' · Service')),
                    ),
                    Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                      IconButton(onPressed:qty>0?()=>_remove(id):null,
                        icon:const Icon(Icons.remove_circle_outline)),
                      Text(qty.toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
                      IconButton(onPressed:()=>_add(p),icon:const Icon(Icons.add_circle_outline)),
                    ]),
                  ])));
              }),
            ]):_step==1?Column(children:[
              TextField(controller:_customer,
                decoration:const InputDecoration(labelText:'Customer name',border:OutlineInputBorder())),
              const SizedBox(height:16),
              TextField(controller:_phone,keyboardType:TextInputType.phone,
                decoration:const InputDecoration(labelText:'Phone (optional)',border:OutlineInputBorder())),
              if(isSale)...[
                const SizedBox(height:16),
                DropdownButtonFormField<String>(
                  value:_method,decoration:const InputDecoration(labelText:'Payment method',
                    border:OutlineInputBorder()),
                  items:const [
                    DropdownMenuItem(value:'Cash',child:Text('Cash')),
                    DropdownMenuItem(value:'Mobile Money',child:Text('Mobile Money')),
                    DropdownMenuItem(value:'Bank Transfer',child:Text('Bank Transfer')),
                    DropdownMenuItem(value:'Card',child:Text('Card')),
                  ],onChanged:(v)=>setState(()=>_method=v??'Cash'),
                ),
                const Padding(padding:EdgeInsets.all(12),
                  child:Text('Complete a sale only after payment is received.')),
              ],
            ]):Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text('Customer: '+_customer.text.trim()),
              const SizedBox(height:10),
              ..._cart.entries.map((e){
                final p=_product(e.key);
                return ListTile(title:Text(p?['name']?.toString()??'Item'),
                  subtitle:Text('Qty: '+e.value.toString()),
                  trailing:Text(((p?['sale_price'] as num? ?? 0).toDouble()*e.value).toStringAsFixed(2)));
              }),
              const Divider(),
              Text('Total: '+_total.toStringAsFixed(2),
                style:Theme.of(context).textTheme.titleLarge),
              const SizedBox(height:10),
              Text(isSale?'Stock is deducted after checkout. A sales receipt will be generated.':
                'Quotation only. Stock remains unchanged.'),
            ]),
          )),
          Padding(padding:const EdgeInsets.all(16),child:Row(children:[
            if(_step>0)...[
              OutlinedButton(onPressed:_saving?null:()=>setState((){_step--;_error=null;}),
                child:const Text('Back')),
              const SizedBox(width:10),
            ],
            Expanded(child:FilledButton(
              onPressed:_saving?null:(_step==2?_save:_next),
              child:Text(_saving?'Processing...':_step==2?
                (isSale?'Complete sale':'Save quotation'):'Next'),
            )),
          ])),
        ]),
      ))),
    );
  }
}
