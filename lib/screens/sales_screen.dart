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
  String _baseCurrency='USD';
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
      final currency=await InventoryService.instance.businessCurrency(business);
      final transactions=await SalesService.instance.list(business);
      if(mounted)setState((){
        _businessId=business;_products=products;_balances=balances;_transactions=transactions;_baseCurrency=currency;
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
        quantity:(r['quantity'] as num),
        unitPrice:(r['unit_price'] as num).toDouble(),
      )).toList(),
      discount:((sale['returned_total']??0) as num).toDouble(),
      type:sale['kind']=='quotation'?DocumentType.quotation:
        (sale['payment_status']=='paid'?DocumentType.receipt:DocumentType.invoice),
      paymentOption:sale['payment_method']?.toString(),
      currencyCode:sale['currency']?.toString(),
      notes:sale['kind']=='sale'?
        'Sales total: '+sale['total'].toString()+
        ' | Paid (net): '+(((sale['paid_total']??0) as num).toDouble()-((sale['refunded_total']??0) as num).toDouble()).toStringAsFixed(2)+
        ' | Returned: '+(sale['returned_total']??0).toString()+
        ' | Refunded: '+(sale['refunded_total']??0).toString()+
        ' | Balance: '+((sale['total'] as num).toDouble()-((sale['returned_total']??0) as num).toDouble()-((sale['paid_total']??0) as num).toDouble()+((sale['refunded_total']??0) as num).toDouble()).toStringAsFixed(2)+
        (sale['due_date']==null?'':' | Due: '+sale['due_date'].toString())
        : 'Catalog quotation · Stock not deducted',
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
  Future<void> _collect(Map<String,dynamic> sale)async{
    final amount=TextEditingController(),reference=TextEditingController();
    String method='Cash';
    bool processing=false;
    final remaining=(sale['total'] as num).toDouble()-
      ((sale['returned_total']??0) as num).toDouble()-
      ((sale['paid_total']??0) as num).toDouble()+
      ((sale['refunded_total']??0) as num).toDouble();
    final result=await showModalBottomSheet<bool>(
      context:context,isScrollControlled:true,
      builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,update)=>
        Padding(
          padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.viewInsetsOf(sheetContext).bottom+20),
          child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text('Receive payment',style:Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height:8),
            Text('Outstanding: '+_baseCurrency+' '+remaining.toStringAsFixed(2)),
            const SizedBox(height:14),
            TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'Amount received',border:OutlineInputBorder())),
            const SizedBox(height:12),
            DropdownButtonFormField<String>(
              value:method,
              decoration:const InputDecoration(labelText:'Payment method',border:OutlineInputBorder()),
              items:['Cash','Mobile Money','Bank Transfer','Card']
                .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
              onChanged:(v)=>update(()=>method=v??'Cash'),
            ),
            const SizedBox(height:12),
            TextField(controller:reference,decoration:const InputDecoration(
              labelText:'Payment reference (optional)',border:OutlineInputBorder())),
            const SizedBox(height:16),
            SizedBox(width:double.infinity,child:FilledButton(
              onPressed:processing?null:()async{
                final value=double.tryParse(amount.text.trim());
                if(value==null||!value.isFinite||value<=0||value>remaining||
                   (value*100).roundToDouble()!=value*100){
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:Text('Enter a valid amount not exceeding the balance (2 decimals).')));
                  return;
                }
                update(()=>processing=true);
                try{
                  await SalesService.instance.addPayment(
                    businessId:_businessId!,saleId:sale['id'].toString(),
                    amount:value,method:method,reference:reference.text.trim());
                  if(sheetContext.mounted)Navigator.pop(sheetContext,true);
                }catch(e){
                  if(sheetContext.mounted){
                    update(()=>processing=false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_message(e))));
                  }
                }
              },
              child:Text(processing?'Saving...':'Record payment'),
            )),
          ])),
        ),
      ),
    );
    amount.dispose();reference.dispose();
    if(result==true)await _refresh();
  }

  Future<void> _returnSale(Map<String,dynamic> sale) async {
    if(_businessId==null)return;
    try{
      final full=await SalesService.instance.byId(_businessId!,sale['id'].toString());
      final returns=await SalesService.instance.returns(_businessId!,sale['id'].toString());
      if(!mounted)return;
      final lines=List<Map<String,dynamic>>.from(
        (full['lines'] as List).map((item)=>Map<String,dynamic>.from(item as Map)));
      final refunded=returns.fold<double>(0,(sum,item)=>
        sum+(item['refund_amount'] as num).toDouble());
      final availableRefund=(full['paid_total'] as num).toDouble()-refunded;
      final count=TextEditingController(text:'1'),money=TextEditingController(text:'0'),
        reason=TextEditingController();
      String? productId;
      String method='Cash';
      bool restock=true,busy=false;
      final saved=await showModalBottomSheet<bool>(
        context:context,isScrollControlled:true,
        builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
          final line=lines.where((e)=>e['product_id']==productId).firstOrNull;
          final sold=(line?['quantity'] as num?)?.toDouble()??0;
          final returned=returns.where((e)=>e['product_id']==productId)
            .fold<double>(0,(v,e)=>v+(e['quantity'] as num).toDouble());
          final remaining=sold-returned;
          return Padding(
            padding:EdgeInsets.fromLTRB(16,16,16,MediaQuery.viewInsetsOf(ctx).bottom+20),
            child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text('Return / refund',style:Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height:8),
              Text('Maximum refundable: '+(full['currency']??_baseCurrency).toString()+' '+availableRefund.toStringAsFixed(2)),
              const SizedBox(height:12),
              DropdownButtonFormField<String>(
                value:productId,isExpanded:true,
                decoration:const InputDecoration(labelText:'Sold item',border:OutlineInputBorder()),
                items:lines.map((e)=>DropdownMenuItem<String>(
                  value:e['product_id'].toString(),
                  child:Text(e['description'].toString(),overflow:TextOverflow.ellipsis))).toList(),
                onChanged:(v)=>update(()=>productId=v),
              ),
              if(productId!=null)Padding(
                padding:const EdgeInsets.only(top:8),
                child:Text('Available to return: '+remaining.toString())),
              const SizedBox(height:12),
              TextField(controller:count,
                keyboardType:const TextInputType.numberWithOptions(decimal:true),
                decoration:const InputDecoration(labelText:'Quantity returned',border:OutlineInputBorder())),
              const SizedBox(height:12),
              TextField(controller:money,
                keyboardType:const TextInputType.numberWithOptions(decimal:true),
                decoration:const InputDecoration(labelText:'Refund amount (0 if no refund)',
                  border:OutlineInputBorder())),
              const SizedBox(height:12),
              DropdownButtonFormField<String>(
                value:method,
                decoration:const InputDecoration(labelText:'Refund method',border:OutlineInputBorder()),
                items:['Cash','Mobile Money','Bank Transfer','Card']
                  .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
                onChanged:(v)=>update(()=>method=v??'Cash'),
              ),
              SwitchListTile(title:const Text('Return items to stock'),value:restock,
                onChanged:(v)=>update(()=>restock=v)),
              TextField(controller:reason,
                decoration:const InputDecoration(labelText:'Reason',border:OutlineInputBorder())),
              const SizedBox(height:14),
              SizedBox(width:double.infinity,child:FilledButton(
                onPressed:busy?null:()async{
                  final qty=double.tryParse(count.text.trim());
                  final amount=double.tryParse(money.text.trim());
                  if(productId==null||qty==null||!qty.isFinite||qty<=0||qty>remaining||
                      amount==null||!amount.isFinite||amount<0||amount>availableRefund||
                      (amount*100).round()!=(amount*100)){
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:Text('Check item, return quantity and refundable amount.')));
                    return;
                  }
                  update(()=>busy=true);
                  try{
                    await SalesService.instance.returnItem(
                      businessId:_businessId!,saleId:full['id'].toString(),
                      productId:productId!,quantity:qty,refundAmount:amount,
                      refundMethod:method,restock:restock,reason:reason.text.trim());
                    if(ctx.mounted)Navigator.pop(ctx,true);
                  }catch(e){
                    if(ctx.mounted){
                      update(()=>busy=false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content:Text(_message(e))));
                    }
                  }
                },
                child:Text(busy?'Processing...':'Record return'),
              )),
            ])),
          );
        }),
      );
      count.dispose();money.dispose();reason.dispose();
      if(saved==true)await _refresh();
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(_message(e))));
    }
  }

  Future<void> _new(String kind)async{
    if(_businessId==null)return;
    final id=await Navigator.of(context).push<String>(MaterialPageRoute(
      builder:(_)=>_SalesWizard(
        businessId:_businessId!,kind:kind,products:_products,balances:_balances,currency:_baseCurrency)));
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
            ..._transactions.map((item)=>Card(child:Column(children:[
              ListTile(
              leading:Icon(item['kind']=='sale'?Icons.receipt_long:Icons.request_quote),
              title:Text(item['document_number'].toString()),
              subtitle:Text(item['customer_name'].toString()+' · '+
                (item['kind']=='sale'
                  ? (item['currency']??_baseCurrency).toString()+' · Net paid: '+(((item['paid_total']??0) as num).toDouble()-((item['refunded_total']??0) as num).toDouble()).toStringAsFixed(2)+
                    ' / '+((item['total'] as num).toDouble()-((item['returned_total']??0) as num).toDouble()).toStringAsFixed(2)+
                    ' · '+item['payment_status'].toString()
                  : 'Quotation · '+item['total'].toString())),
              trailing:item['kind']=='sale' &&
                (item['payment_status']=='partial'||item['payment_status']=='unpaid')
                ?IconButton(
                    tooltip:'Receive payment',icon:const Icon(Icons.add_card),
                    onPressed:()=>_collect(item),
                  )
                :const Icon(Icons.chevron_right),
              onTap:()=>_preview(item['id'].toString()),
              ),
              if(item['kind']=='sale')
                Align(alignment:Alignment.centerRight,child:TextButton.icon(
                  onPressed:()=>_returnSale(item),
                  icon:const Icon(Icons.assignment_return_outlined,size:18),
                  label:const Text('Return / refund'),
                )),
            ]))),
          ],
        ]),
      ),
    );
  }
}

class _SalesWizard extends StatefulWidget {
  final String businessId,kind,currency;
  final List<Map<String,dynamic>> products;
  final Map<String,double> balances;
  const _SalesWizard({required this.businessId,required this.kind,required this.currency,
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
  String _secondMethod='Mobile Money';
  String _paymentMode='full';
  final _amountOne=TextEditingController();
  final _amountTwo=TextEditingController();
  DateTime? _dueDate;
  String? _error;
  bool _saving=false;
  @override
  void dispose(){_customer.dispose();_phone.dispose();_amountOne.dispose();_amountTwo.dispose();super.dispose();}
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
    if(_step==1&&widget.kind=='sale'){
      if(_paymentMode=='split'||_paymentMode=='credit'){
        final a=double.tryParse(_amountOne.text.trim());
        if(a==null||!a.isFinite||a<0||a>_total){setState(()=>_error='Enter a valid first payment amount.');return;}
        if(_paymentMode=='split'){
          final b=double.tryParse(_amountTwo.text.trim());
          if(b==null||!b.isFinite||b<=0||(a+b-_total).abs()>0.001){
            setState(()=>_error='Split payments must equal the sale total.');return;
          }
        }
        if(_paymentMode=='credit'&&a<_total&&_dueDate==null){
          setState(()=>_error='Choose a credit due date.');return;
        }
      }
    }
    setState((){_step++;_error=null;});
  }
  Future<void> _save()async{
    if(_saving)return;
    setState((){_saving=true;_error=null;});
    try{
      final paymentList=<Map<String,dynamic>>[];
      if(widget.kind=='sale'){
        if(_paymentMode=='full'){
          paymentList.add({'method':_method,'amount':double.parse(_total.toStringAsFixed(2))});
        }else{
          final a=double.tryParse(_amountOne.text.trim())??0;
          if(a>0)paymentList.add({'method':_method,'amount':a});
          if(_paymentMode=='split'){
            final b=double.tryParse(_amountTwo.text.trim())??0;
            if(b>0)paymentList.add({'method':_secondMethod,'amount':b});
          }
        }
      }
      final id=await SalesService.instance.record(
        businessId:widget.businessId,
        kind:widget.kind,
        quantities:_cart,
        customer:_customer.text.trim(),
        phone:_phone.text.trim(),
        paymentMethod:_method,
        payments:paymentList,
        dueDate:_paymentMode=='credit'&&_dueDate!=null
          ?_dueDate!.toIso8601String().substring(0,10):null,
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
                      subtitle:Text('Price: '+widget.currency+' '+p['sale_price'].toString()+
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
                const SizedBox(height:14),
                DropdownButtonFormField<String>(
                  value:_paymentMode,
                  decoration:const InputDecoration(labelText:'Payment arrangement',border:OutlineInputBorder()),
                  items:const [
                    DropdownMenuItem(value:'full',child:Text('Paid in full')),
                    DropdownMenuItem(value:'split',child:Text('Split payments')),
                    DropdownMenuItem(value:'credit',child:Text('Partial / credit sale')),
                  ],onChanged:(v)=>setState(()=>_paymentMode=v??'full'),
                ),
                if(_paymentMode!='full')...[
                  const SizedBox(height:14),
                  TextField(controller:_amountOne,keyboardType:const TextInputType.numberWithOptions(decimal:true),
                    decoration:InputDecoration(labelText:_paymentMode=='credit'?'Amount paid now (0 if unpaid)':'First payment amount',
                      border:const OutlineInputBorder())),
                ],
                if(_paymentMode=='split')...[
                  const SizedBox(height:14),
                  DropdownButtonFormField<String>(
                    value:_secondMethod,
                    decoration:const InputDecoration(labelText:'Second payment method',border:OutlineInputBorder()),
                    items:['Cash','Mobile Money','Bank Transfer','Card']
                      .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
                    onChanged:(v)=>setState(()=>_secondMethod=v??'Mobile Money'),
                  ),
                  const SizedBox(height:14),
                  TextField(controller:_amountTwo,keyboardType:const TextInputType.numberWithOptions(decimal:true),
                    decoration:const InputDecoration(labelText:'Second payment amount',border:OutlineInputBorder())),
                ],
                if(_paymentMode=='credit')...[
                  const SizedBox(height:14),
                  OutlinedButton.icon(
                    onPressed:()async{
                      final picked=await showDatePicker(
                        context:context,firstDate:DateTime.now(),
                        lastDate:DateTime.now().add(const Duration(days:3650)),
                        initialDate:_dueDate??DateTime.now().add(const Duration(days:30)));
                      if(picked!=null)setState(()=>_dueDate=picked);
                    },
                    icon:const Icon(Icons.event),
                    label:Text(_dueDate==null?'Choose due date':
                      'Due: '+_dueDate!.toIso8601String().substring(0,10)),
                  ),
                ],
                const Padding(padding:EdgeInsets.all(12),
                  child:Text('Record only payments actually received. Outstanding amounts remain on credit.')),
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
              Text('Total: '+widget.currency+' '+_total.toStringAsFixed(2),
                style:Theme.of(context).textTheme.titleLarge),
              const SizedBox(height:10),
              Text(isSale?'Stock is deducted on checkout. A receipt is issued only when fully paid; otherwise an invoice shows the balance.':
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
