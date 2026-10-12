import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../services/inventory_service.dart';

class ProductsScreen extends StatefulWidget {
  final bool readOnly;
  const ProductsScreen({super.key,this.readOnly=false});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}
class _ProductsScreenState extends State<ProductsScreen> {
  String? _businessId, _error;
  List<Map<String,dynamic>> _products=[];
  Map<String,double> _balances={};
  bool _loading=true;
  String _baseCurrency='USD';
  String _query='';
  @override
  void initState(){super.initState();_load();}
  String _message(Object e){
    final t=e.toString().toLowerCase();
    if(t.contains('unique')||t.contains('duplicate'))return 'The SKU is already used by this business.';
    if(t.contains('insufficient stock'))return 'Not enough stock available.';
    if(t.contains('permission')||t.contains('not allowed'))return 'You do not have permission for this action.';
    return 'Unable to complete this action. Check your connection and try again.';
  }
  Future<void> _load()async{
    setState((){_loading=true;_error=null;});
    try{
      final p=DataService().currentProfile;
      final id=await InventoryService.instance.ensureBusiness(name:p?.name??'My Business',category:p?.category??'Other');
      final productsRequest=InventoryService.instance.products(id);
      final balancesRequest=InventoryService.instance.balances(id);
      final currencyRequest=InventoryService.instance.businessCurrency(id);
      final products=await productsRequest;
      final balances=await balancesRequest;
      final currency=await currencyRequest;
      if(mounted)setState((){_businessId=id;_products=products;_balances=balances;_baseCurrency=currency;});
    }catch(e){if(mounted)setState(()=>_error=_message(e));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _edit([Map<String,dynamic>? product])async{
    if(_businessId==null)return;
    final ok=await Navigator.push<bool>(context,MaterialPageRoute(
      builder:(_)=>_ProductWizard(businessId:_businessId!,original:product,currency:_baseCurrency)));
    if(ok==true)await _load();
  }
  Future<void> _move(Map<String,dynamic> product,{bool receive=true})async{
    if(_businessId==null)return;
    final qty=TextEditingController(),note=TextEditingController();
    bool incoming=receive,busy=false;
    final saved=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.only(left:20,right:20,top:20,bottom:MediaQuery.viewInsetsOf(ctx).bottom+20),
        child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(incoming?'Add / receive stock':'Issue stock',style:Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height:12),
          Text(product['name'].toString()+' · Available: '+(_balances[product['id'].toString()]??0).toString()+' '+product['unit'].toString(),maxLines:3),
          const SizedBox(height:12),
          SegmentedButton<bool>(segments:const [
            ButtonSegment(value:true,label:Text('Receive')),
            ButtonSegment(value:false,label:Text('Issue')),
          ],selected:{incoming},onSelectionChanged:(v)=>update(()=>incoming=v.first)),
          const SizedBox(height:12),
          TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'Quantity',border:OutlineInputBorder())),
          const SizedBox(height:12),
          TextField(controller:note,decoration:const InputDecoration(labelText:'Reason or reference',border:OutlineInputBorder())),
          const SizedBox(height:18),
          SizedBox(width:double.infinity,child:FilledButton(
            onPressed:busy?null:()async{
              final n=double.tryParse(qty.text.trim());
              if(n==null||!n.isFinite||n<=0||n>999999999||(n*1000).roundToDouble()!=n*1000){
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a positive quantity with up to 3 decimal places.')));
                return;
              }
              update(()=>busy=true);
              try{
                await InventoryService.instance.postStock(_businessId!,product['id'].toString(),
                  delta:incoming?n:-n,kind:incoming?'receive':'adjustment',note:note.text.trim());
                if(ctx.mounted)Navigator.pop(ctx,true);
              }catch(e){
                if(ctx.mounted){update(()=>busy=false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_message(e))));}
              }
            },child:Text(busy?'Saving...':incoming?'Add stock':'Issue stock'),
          )),
        ]))),
      ));
    qty.dispose();note.dispose();
    if(saved==true)await _load();
  }
  Future<void> _history(Map<String,dynamic> product)async{
    try{
      final rows=await InventoryService.instance.movements(_businessId!,product['id'].toString());
      if(!mounted)return;
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(ctx)=>
        SafeArea(child:SizedBox(height:MediaQuery.sizeOf(ctx).height*0.7,child:Column(children:[
          Padding(padding:const EdgeInsets.all(16),child:Text('Stock history: '+product['name'].toString(),
            style:Theme.of(ctx).textTheme.titleMedium)),
          Expanded(child:rows.isEmpty?const Center(child:Text('No stock movements yet.')):
            ListView.builder(itemCount:rows.length,itemBuilder:(_,i){
              final r=rows[i];final change=(r['change_qty'] as num).toDouble();
              return ListTile(
                leading:Icon(change>=0?Icons.add_circle_outline:Icons.remove_circle_outline),
                title:Text(r['kind'].toString()+' · '+change.toString()),
                subtitle:Text((r['note']??'').toString()),
                trailing:Text('Balance '+r['quantity_after'].toString()),
              );
            })),
        ]))));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_message(e))));}
  }
  @override
  Widget build(BuildContext context){
    final items=_products.where((p)=>[p['name'],p['sku'],p['category']]
      .any((v)=>v.toString().toLowerCase().contains(_query.toLowerCase()))).toList();
    final low=_products.where((p)=>p['track_stock']==true&&
      (_balances[p['id'].toString()]??0)<=(p['reorder_level'] as num).toDouble()).length;
    return Scaffold(
      resizeToAvoidBottomInset:true,
      floatingActionButton:_businessId==null||widget.readOnly?null:FloatingActionButton.extended(
        onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('New item')),
      body:RefreshIndicator(onRefresh:_load,child:_loading?
        const Center(child:CircularProgressIndicator()):
        ListView(padding:const EdgeInsets.fromLTRB(16,16,16,100),children:[
          Text('Products & Inventory',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),
          const Text('Products, services, raw materials and finished goods in one catalog.'),
          const SizedBox(height:12),
          if(_error!=null)...[
            Card(color:Theme.of(context).colorScheme.errorContainer,
              child:Padding(padding:const EdgeInsets.all(16),child:Text(_error!))),
            TextButton(onPressed:_load,child:const Text('Retry')),
          ]else...[
            Wrap(spacing:8,runSpacing:8,children:[
              Chip(label:Text(_products.length.toString()+' items')),
              Chip(label:Text(low.toString()+' low-stock')),
            ]),
            const SizedBox(height:12),
            Card(
              child:Padding(padding:const EdgeInsets.all(12),
                child:Row(children:[
                  const Icon(Icons.add_box_outlined,size:26),
                  const SizedBox(width:12),
                  const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Stock receiving',style:TextStyle(fontWeight:FontWeight.bold)),
                    Text('Add stock to any tracked product using Add Stock below.',style:TextStyle(fontSize:12)),
                  ])),
                ])),
            ),
            const SizedBox(height:12),
            TextField(onChanged:(v)=>setState(()=>_query=v),
              decoration:const InputDecoration(labelText:'Search products or SKU',
                prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
            const SizedBox(height:12),
            if(items.isEmpty)const Padding(padding:EdgeInsets.all(24),
              child:Text('No items found. Add your first product or service.',textAlign:TextAlign.center)),
            ...items.map((p){
              final track=p['track_stock']==true;
              final quantity=_balances[p['id'].toString()]??0;
              return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
                ListTile(
                  title:Text(p['name'].toString(),maxLines:2),
                  subtitle:Text(p['item_type'].toString()+' · '+(p['sku']??'No SKU').toString()+
                  ' · '+_baseCurrency+' '+p['sale_price'].toString()),
                  trailing:Text(track?quantity.toString()+' '+p['unit'].toString():'Service',
                    style:const TextStyle(fontWeight:FontWeight.bold)),
                ),
                if(track&&quantity<=(p['reorder_level'] as num).toDouble())
                  const Align(alignment:Alignment.centerLeft,
                    child:Padding(padding:EdgeInsets.only(left:16),child:Text('Low stock',
                      style:TextStyle(color:Colors.orange)))),
                Wrap(spacing:8,runSpacing:8,children:[
                  if(!widget.readOnly) TextButton.icon(onPressed:()=>_edit(p),icon:const Icon(Icons.edit_outlined,size:18),
                    label:const Text('Edit')),
                  if(track)TextButton.icon(onPressed:()=>_history(p),
                    icon:const Icon(Icons.history,size:18),label:const Text('History')),
                  if(track&&!widget.readOnly)FilledButton.icon(onPressed:()=>_move(p),
                    icon:const Icon(Icons.add,size:18),label:const Text('Add Stock')),
                  if(track&&!widget.readOnly)OutlinedButton.icon(onPressed:()=>_move(p,receive:false),
                    icon:const Icon(Icons.remove,size:18),label:const Text('Issue')),
                ]),
              ])));
            }),
          ],
        ]),
      ),
    );
  }
}
class _ProductWizard extends StatefulWidget{
  final String businessId;
  final String currency;
  final Map<String,dynamic>? original;
  const _ProductWizard({required this.businessId,required this.currency,this.original});
  @override
  State<_ProductWizard> createState()=>_ProductWizardState();
}
class _ProductWizardState extends State<_ProductWizard>{
  final _name=TextEditingController(),_sku=TextEditingController(),
    _category=TextEditingController(),_unit=TextEditingController(),
    _sale=TextEditingController(),_cost=TextEditingController(),
    _reorder=TextEditingController();
  final _opening=TextEditingController(text:'0');
  int _step=0;
  String _type='product';
  String? _error;
  bool _track=true,_busy=false;
  @override
  void initState(){
    super.initState();
    final p=widget.original;
    if(p!=null){
      _name.text=p['name'].toString();_sku.text=(p['sku']??'').toString();
      _category.text=(p['category']??'').toString();_unit.text=p['unit'].toString();
      _sale.text=p['sale_price'].toString();_cost.text=p['cost_price'].toString();
      _reorder.text=p['reorder_level'].toString();_type=p['item_type'].toString();
      _track=p['track_stock']==true;
    }else{_unit.text='pcs';_sale.text='0';_cost.text='0';_reorder.text='0';}
  }
  @override
  void dispose(){for(final c in [_name,_sku,_category,_unit,_sale,_cost,_reorder,_opening]){c.dispose();}super.dispose();}
  Widget _field(TextEditingController c,String label,{bool number=false})=>
    Padding(padding:const EdgeInsets.only(bottom:14),child:TextField(
      scrollPadding:const EdgeInsets.only(bottom:135),
      controller:c,keyboardType:number?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
      decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
  void _next(){
    if(_step==0&&_name.text.trim().length<2){setState(()=>_error='Enter an item name.');return;}
    if(_step==1&&[_sale,_cost,_reorder,if(widget.original==null)_opening].any((c){
      final n=double.tryParse(c.text.trim());return n==null||!n.isFinite||n<0;
    })){setState(()=>_error='Enter non-negative amounts and opening stock.');return;}
    final open=double.tryParse(_opening.text.trim())??0;
    if(_step==1&&(open*1000).roundToDouble()!=open*1000){setState(()=>_error='Stock supports up to three decimal places.');return;}
    setState((){_error=null;_step++;});
  }
  Future<void> _save()async{
    if(_busy)return;
    setState((){_busy=true;_error=null;});
    try{
      await InventoryService.instance.saveProduct(widget.businessId,
        id:widget.original?['id']?.toString(),name:_name.text,sku:_sku.text,
        category:_category.text,type:_type,unit:_unit.text,
        salePrice:double.parse(_sale.text),costPrice:double.parse(_cost.text),
        reorderLevel:double.parse(_reorder.text),trackStock:_track,
        openingStock:widget.original==null&&_track&&_type!='service'?
          (double.tryParse(_opening.text.trim())??0):0);
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)setState(()=>_error=e.toString().toLowerCase().contains('unique')
      ? 'This SKU is already in use.':'Cannot save this item. Check the details and retry.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    resizeToAvoidBottomInset:true,
    appBar:AppBar(title:Text(widget.original==null?'New item':'Edit item')),
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:520),
      child:Column(children:[
        Padding(padding:const EdgeInsets.all(20),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('Step '+(_step+1).toString()+' of 3'),
          const SizedBox(height:8),LinearProgressIndicator(value:(_step+1)/3),
          const SizedBox(height:12),
          Text(['Item details','Pricing & stock','Review'][_step],
            style:Theme.of(context).textTheme.titleLarge),
        ])),
        if(_error!=null)Card(color:Theme.of(context).colorScheme.errorContainer,
          child:Padding(padding:const EdgeInsets.all(12),child:Text(_error!))),
        Expanded(child:SingleChildScrollView(
          keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
          padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.viewInsetsOf(context).bottom>0?120:20),
          child:_step==0?Column(children:[
            _field(_name,'Product / service name'),
            DropdownButtonFormField<String>(value:_type,
              decoration:const InputDecoration(labelText:'Type',border:OutlineInputBorder()),
              items:const [
                DropdownMenuItem(value:'product',child:Text('Product')),
                DropdownMenuItem(value:'service',child:Text('Service')),
                DropdownMenuItem(value:'raw_material',child:Text('Raw material')),
                DropdownMenuItem(value:'finished_good',child:Text('Finished good')),
              ],
              onChanged:(v)=>setState((){_type=v??'product';if(_type=='service')_track=false;}),
            ),
            const SizedBox(height:14),_field(_sku,'SKU (optional)'),
            _field(_category,'Category'),_field(_unit,'Unit e.g. pcs, kg, litre, hour'),
          ]):_step==1?Column(children:[
            _field(_sale,'Selling price ('+widget.currency+')',number:true),
            _field(_cost,'Cost price ('+widget.currency+')',number:true),
            if(_type!='service')...[
              _field(_reorder,'Low-stock alert level',number:true),
              SwitchListTile(title:const Text('Track quantity'),value:_track,
                onChanged:(v)=>setState(()=>_track=v)),
            ],
          ]):Column(children:[
            ListTile(title:Text(_name.text),subtitle:Text(_type+' · '+_category.text)),
            ListTile(title:const Text('SKU'),trailing:Text(_sku.text.isEmpty?'None':_sku.text)),
            ListTile(title:const Text('Selling price'),trailing:Text(_sale.text)),
            ListTile(title:const Text('Cost price'),trailing:Text(_cost.text)),
            if(widget.original==null&&_track&&_type!='service')ListTile(title:const Text('Opening stock'),trailing:Text(_opening.text)),
          ]),
        )),
        Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          if(_step>0)...[
            OutlinedButton(onPressed:_busy?null:()=>setState((){_step--;_error=null;}),
              child:const Text('Back')),
            const SizedBox(width:12),
          ],
          Expanded(child:FilledButton(onPressed:_busy?null:(_step==2?_save:_next),
            child:Text(_busy?'Saving...':_step==2?'Save item':'Next'))),
        ])),
      ]),
    ))),
  );
}
