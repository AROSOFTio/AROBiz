import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/inventory_service.dart';
import '../services/offline_sales_service.dart';

class ProductsScreen extends StatefulWidget {
  final bool readOnly;
  final bool newItemOnOpen;
  final VoidCallback? onBack;
  const ProductsScreen({super.key,this.readOnly=false,this.newItemOnOpen=false,this.onBack});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}
class _ProductsScreenState extends State<ProductsScreen> {
  String? _businessId, _error;
  List<Map<String,dynamic>> _products=[];
  Map<String,double> _balances={};
  bool _loading=true;
  bool _launchedItem=false;
  bool _canManageCatalog=false;
  String _baseCurrency='USD';
  String _query='';
  @override
  void initState(){super.initState();_load();}
  String _message(Object e){
    final t=e.toString().toLowerCase();
    if(t.contains('unique')||t.contains('duplicate'))return 'This product name or SKU already exists. Select it and receive stock instead.';
    if(t.contains('insufficient stock'))return 'Not enough stock available.';
    if(t.contains('permission')||t.contains('not allowed'))return 'You do not have permission for this action.';
    return 'Unable to complete this action. Check your connection and try again.';
  }
  Future<void> _load()async{
    setState((){_loading=true;_error=null;});
    try{
      final p=DataService().currentProfile;
      final id=await InventoryService.instance.preferredBusinessId()
        ??await InventoryService.instance.ensureBusiness(
          name:p?.name??'My Business',category:p?.category??'Other');
      final local=await OfflineSalesService.instance.snapshot(id);
      if(local!=null && mounted){
        final catalog=List<Map<String,dynamic>>.from((local['products'] as List)
          .map((v)=>Map<String,dynamic>.from(v as Map)));
        final balances={for(final e in Map<String,dynamic>.from(local['balances'] as Map).entries)
          e.key:(e.value as num).toDouble()};
        final remaining=await OfflineSalesService.instance.effectiveBalances(id,balances);
        setState((){
          _businessId=id;_products=catalog;_balances=remaining;
          _baseCurrency=(local['currency']??'USD').toString();
          _canManageCatalog=false;
        });
      }
      try{
        final products=await InventoryService.instance.products(id)
          .timeout(const Duration(seconds:7));
        final balances=await InventoryService.instance.balances(id)
          .timeout(const Duration(seconds:7));
        final currency=await InventoryService.instance.businessCurrency(id)
          .timeout(const Duration(seconds:7));
        final canManage=await InventoryService.instance.canManageCatalog(id)
          .timeout(const Duration(seconds:7));
        // Any successful catalog visit prepares this business for offline POS.
        await OfflineSalesService.instance.cacheCatalog(
          id,products:products,balances:balances,currency:currency,
          transactions:local==null?[]:
            List<Map<String,dynamic>>.from((local['transactions'] as List)
              .map((v)=>Map<String,dynamic>.from(v as Map))),
        );
        if(mounted){
          final remaining=await OfflineSalesService.instance.effectiveBalances(id,balances);
          if(!mounted)return;
          setState((){
            _businessId=id;_products=products;_balances=remaining;
            _baseCurrency=currency;_canManageCatalog=canManage;
          });
          if(widget.newItemOnOpen&&!widget.readOnly&&canManage&&!_launchedItem){
            _launchedItem=true;
            WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_edit();});
          }
        }
      }catch(_){
        if(local==null)rethrow;
      }
    }catch(e){
      if(mounted)setState(()=>_error='Connect once to download products for offline viewing.');
    }finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _edit([Map<String,dynamic>? product])async{
    if(_businessId==null||!_canManageCatalog)return;
    final ok=await Navigator.push<bool>(context,MaterialPageRoute(
      builder:(_)=>_ProductWizard(businessId:_businessId!,original:product,currency:_baseCurrency)));
    if(ok==true)await _load();
  }
  Future<void> _move(Map<String,dynamic> product,{bool receive=true})async{
    if(_businessId==null)return;
    final qty=TextEditingController(),note=TextEditingController();
    final location=TextEditingController(),receivedAt=TextEditingController(),
      reference=TextEditingController();
    DateTime date=DateTime.now();
    bool incoming=receive,busy=false;
    final saved=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,useSafeArea:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.only(left:20,right:20,top:20,bottom:MediaQuery.viewInsetsOf(ctx).bottom+
          MediaQuery.viewPaddingOf(ctx).bottom+48),
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
          OutlinedButton.icon(
            icon:const Icon(Icons.event_outlined),
            label:Text('Date: '+DateFormat.yMMMd().format(date)),
            onPressed:()async{
              final selected=await showDatePicker(context:ctx,
                initialDate:date,firstDate:DateTime(2000),
                lastDate:DateTime.now().add(const Duration(days:1)));
              if(selected!=null)update(()=>date=selected);
            }),
          const SizedBox(height:12),
          TextField(controller:location,
            decoration:InputDecoration(
              labelText:incoming?'Received from (supplier / branch) *':'Issued to / destination *',
              prefixIcon:Icon(incoming?Icons.call_received:Icons.outbox_outlined),
              border:const OutlineInputBorder())),
          if(incoming)...[
            const SizedBox(height:12),
            TextField(controller:receivedAt,
              decoration:const InputDecoration(labelText:'Received at (store / location) *',
                prefixIcon:Icon(Icons.store_outlined),border:OutlineInputBorder())),
          ],
          const SizedBox(height:12),
          TextField(controller:reference,
            decoration:const InputDecoration(labelText:'Reference / GRN / delivery note',
              prefixIcon:Icon(Icons.tag),border:OutlineInputBorder())),
          const SizedBox(height:12),
          TextField(controller:note,
            decoration:const InputDecoration(labelText:'Remarks (optional)',border:OutlineInputBorder())),
          const SizedBox(height:18),
          SizedBox(width:double.infinity,child:FilledButton(
            onPressed:busy?null:()async{
              final n=double.tryParse(qty.text.trim());
              if(n==null||!n.isFinite||n<=0||n>999999999||(n*1000).roundToDouble()!=n*1000){
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a positive quantity with up to 3 decimal places.')));
                return;
              }
              if(location.text.trim().isEmpty||(incoming&&receivedAt.text.trim().isEmpty)){
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content:Text('Enter the source and receiving store, or the issue destination.')));
                return;
              }
              update(()=>busy=true);
              try{
                await InventoryService.instance.postStock(_businessId!,product['id'].toString(),
                  delta:incoming?n:-n,kind:incoming?'receive':'adjustment',
                  note:note.text.trim(),movementDate:date,
                  sourceLocation:incoming?location.text.trim():'',
                  destinationLocation:incoming?receivedAt.text.trim():location.text.trim(),
                  documentReference:reference.text.trim());
                if(ctx.mounted)Navigator.pop(ctx,true);
              }catch(e){
                if(ctx.mounted){update(()=>busy=false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_message(e))));}
              }
            },child:Text(busy?'Saving...':incoming?'Add stock':'Issue stock'),
          )),
        ]))),
      ));
    qty.dispose();note.dispose();location.dispose();receivedAt.dispose();reference.dispose();
    if(saved==true){
      if(_businessId!=null){
        final snap=await OfflineSalesService.instance.snapshot(_businessId!);
        if(snap!=null){
          final base={for(final entry in Map<String,dynamic>.from(snap['balances'] as Map).entries)
            entry.key:(entry.value as num).toDouble()};
          final effective=await OfflineSalesService.instance.effectiveBalances(_businessId!,base);
          if(mounted)setState(()=>_balances=effective);
        }
      }
      await _load();
    }
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
                subtitle:Text([
                  if(r['movement_date']!=null)r['movement_date'].toString(),
                  if(r['source_location']!=null)'From: '+r['source_location'].toString(),
                  if(r['destination_location']!=null)'To: '+r['destination_location'].toString(),
                  if(r['document_reference']!=null)'Ref: '+r['document_reference'].toString(),
                  if((r['note']??'').toString().isNotEmpty)r['note'].toString(),
                  'Recorded: '+r['created_at'].toString().substring(0,16),
                ].join(' · ')),
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
      floatingActionButton:_businessId==null||widget.readOnly||!_canManageCatalog?null:FloatingActionButton.extended(
        onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('New item')),
      body:RefreshIndicator(onRefresh:_load,child:_loading?
        const Center(child:CircularProgressIndicator()):
        ListView(padding:const EdgeInsets.fromLTRB(16,16,16,100),children:[
          Row(children:[
            IconButton(tooltip:'Back',onPressed:widget.onBack??()=>Navigator.maybePop(context),
              icon:const Icon(Icons.arrow_back)),
            Expanded(child:Text('Products & Inventory',
              style:Theme.of(context).textTheme.titleLarge)),
          ]),

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

            TextField(onChanged:(v)=>setState(()=>_query=v),
              decoration:const InputDecoration(labelText:'Search items',
                prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
            const SizedBox(height:12),
            if(items.isEmpty)const Padding(padding:EdgeInsets.all(24),
              child:Text('No items found. Add your first product or service.',textAlign:TextAlign.center)),
            LayoutBuilder(builder:(context,constraints){
              final cols=constraints.maxWidth>=800?4:constraints.maxWidth>=540?3:2;
              final cardWidth=(constraints.maxWidth-10*(cols-1))/cols;
              return Wrap(spacing:10,runSpacing:10,children:items.map((p){
                final track=p['track_stock']==true;
                final qty=_balances[p['id'].toString()]??0;
                final image=InventoryService.instance.publicProductImageUrl(p['image_path']);
                return SizedBox(width:cardWidth,child:Card(
                  margin:EdgeInsets.zero,clipBehavior:Clip.antiAlias,
                  child:Padding(padding:const EdgeInsets.all(9),child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,children:[
                      SizedBox(height:105,width:double.infinity,
                        child:ClipRRect(borderRadius:BorderRadius.circular(9),
                          child:image==null
                            ?ColoredBox(color:Theme.of(context).colorScheme.surfaceContainerHigh,
                                child:const Icon(Icons.inventory_2_outlined,size:35))
                            :Image.network(image,fit:BoxFit.cover,cacheWidth:250,
                              errorBuilder:(_,__,___)=>const Icon(Icons.inventory_2_outlined)))),
                      const SizedBox(height:8),
                      Text(p['name'].toString(),maxLines:2,
                        overflow:TextOverflow.ellipsis,
                        style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),
                      const SizedBox(height:3),
                      Text(_baseCurrency+' '+p['sale_price'].toString(),
                        maxLines:1,overflow:TextOverflow.ellipsis,
                        style:Theme.of(context).textTheme.labelMedium),
                      Text(track?'Stock: $qty ${p['unit']}':'Service',
                        maxLines:1,overflow:TextOverflow.ellipsis,
                        style:TextStyle(fontSize:11,
                          color:track&&qty<=(p['reorder_level'] as num).toDouble()
                            ?Colors.deepOrange:null)),
                      const SizedBox(height:8),
                      Wrap(spacing:3,runSpacing:2,children:[
                        if(!widget.readOnly&&_canManageCatalog)IconButton(
                          visualDensity:VisualDensity.compact,
                          tooltip:'Edit item',onPressed:()=>_edit(p),
                          icon:const Icon(Icons.edit_outlined,size:20)),
                        if(track)IconButton(
                          visualDensity:VisualDensity.compact,
                          tooltip:'Stock history',onPressed:()=>_history(p),
                          icon:const Icon(Icons.history,size:20)),
                        if(track&&!widget.readOnly)IconButton.filledTonal(
                          visualDensity:VisualDensity.compact,
                          tooltip:'Add stock',onPressed:()=>_move(p),
                          icon:const Icon(Icons.add,size:20)),
                        if(track&&!widget.readOnly)IconButton(
                          visualDensity:VisualDensity.compact,
                          tooltip:'Issue stock',onPressed:()=>_move(p,receive:false),
                          icon:const Icon(Icons.remove_circle_outline,size:20)),
                      ]),
                    ]),
                  )));
              }).toList());
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
  List<String> _categories=[];
  XFile? _image;
  @override
  void initState(){
    super.initState();
    _loadCategories();
    final p=widget.original;
    if(p!=null){
      _name.text=p['name'].toString();_sku.text=(p['sku']??'').toString();
      _category.text=(p['category']??'').toString();_unit.text=p['unit'].toString();
      _sale.text=p['sale_price'].toString();_cost.text=p['cost_price'].toString();
      _reorder.text=p['reorder_level'].toString();_type=p['item_type'].toString();
      _track=p['track_stock']==true;
    }else{_unit.text='pcs';_sale.text='0';_cost.text='0';_reorder.text='0';}
  }
  Future<void> _loadCategories()async{
    try {
      final names=await InventoryService.instance.productCategories(widget.businessId);
      if(mounted)setState(()=>_categories=names);
    }catch(_){/* Existing category stays available when offline. */}
  }
  Future<void> _addCategory()async{
    final controller=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('New category'),
      content:TextField(controller:controller,autofocus:true,
        decoration:const InputDecoration(labelText:'Category name')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),
          child:const Text('Add')),
      ],
    ));
    controller.dispose();
    if(name==null||name.isEmpty)return;
    try{
      await InventoryService.instance.addProductCategory(widget.businessId,name);
      _category.text=name;
      await _loadCategories();
    }catch(e){
      if(mounted)setState(()=>_error=e.toString().toLowerCase().contains('unique')
        ? 'Category already exists. Select it from the list.'
        : 'Unable to create category. Check access and connection.');
    }
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
  Future<void> _pickImage(ImageSource source)async{
    try{
      final image=await ImagePicker().pickImage(source:source,
        imageQuality:62,maxWidth:640,maxHeight:640);
      if(image!=null && mounted)setState(()=>_image=image);
    }catch(_){if(mounted)setState(()=>_error='Camera or gallery access was unsuccessful.');}
  }
  Future<void> _save()async{
    if(_busy)return;
    setState((){_busy=true;_error=null;});
    try{
      final savedId=await InventoryService.instance.saveProduct(widget.businessId,
        id:widget.original?['id']?.toString(),name:_name.text,sku:_sku.text,
        category:_category.text,type:_type,unit:_unit.text,
        salePrice:double.parse(_sale.text),costPrice:double.parse(_cost.text),
        reorderLevel:double.parse(_reorder.text),trackStock:_track,
        openingStock:widget.original==null&&_track&&_type!='service'?
          (double.tryParse(_opening.text.trim())??0):0);
      if(_image!=null){
        await InventoryService.instance.uploadProductImage(widget.businessId,savedId,_image!);
      }
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)setState(()=>_error=e.toString().toLowerCase().contains('unique')
      ? 'This product name or SKU already exists. Select the existing product and receive stock.':'Cannot save this item. Check the details and retry.');}
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
          LinearProgressIndicator(value:(_step+1)/3,minHeight:3),
          const SizedBox(height:12),
          Text(['Item details','Pricing','Review'][_step],
            style:Theme.of(context).textTheme.titleLarge),
        ])),
        if(_error!=null)Card(color:Theme.of(context).colorScheme.errorContainer,
          child:Padding(padding:const EdgeInsets.all(12),child:Text(_error!))),
        Expanded(child:SingleChildScrollView(
          keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
          padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.viewInsetsOf(context).bottom>0?120:20),
          child:_step==0?Column(children:[
            Container(height:110,width:110,
              clipBehavior:Clip.antiAlias,
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),
                color:Theme.of(context).colorScheme.surfaceContainerHigh),
              child:_image!=null?Image.file(File(_image!.path),fit:BoxFit.cover):
                (widget.original?['image_path']!=null
                  ?Image.network(InventoryService.instance.publicProductImageUrl(
                    widget.original!['image_path'])!,fit:BoxFit.cover,
                    errorBuilder:(_,__,___)=>const Icon(Icons.image_outlined,size:40))
                  :const Icon(Icons.image_outlined,size:40))),
            const SizedBox(height:8),
            Wrap(spacing:8,alignment:WrapAlignment.center,children:[
              OutlinedButton.icon(onPressed:()=>_pickImage(ImageSource.camera),
                icon:const Icon(Icons.camera_alt_outlined),label:const Text('Camera')),
              OutlinedButton.icon(onPressed:()=>_pickImage(ImageSource.gallery),
                icon:const Icon(Icons.photo_library_outlined),label:const Text('Gallery')),
            ]),

            const SizedBox(height:12),
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
            Row(children:[
              Expanded(child:DropdownButtonFormField<String>(
                value:_categories.contains(_category.text)?_category.text:null,
                isExpanded:true,
                decoration:const InputDecoration(labelText:'Category',
                  border:OutlineInputBorder()),
                items:_categories.map((value)=>DropdownMenuItem(
                  value:value,child:Text(value,overflow:TextOverflow.ellipsis))).toList(),
                onChanged:(value){if(value!=null)setState(()=>_category.text=value);},
              )),
              const SizedBox(width:8),
              IconButton.filledTonal(tooltip:'New category',onPressed:_addCategory,
                icon:const Icon(Icons.add)),
            ]),
            const SizedBox(height:14),
            _field(_unit,'Unit e.g. pcs, kg, litre, hour'),
          ]):_step==1?Column(children:[
            _field(_sale,'Selling price ('+widget.currency+')',number:true),
            _field(_cost,'Cost price ('+widget.currency+')',number:true),
            if(_type!='service')...[
              _field(_reorder,'Low-stock alert level',number:true),
              if(widget.original==null&&_track)_field(_opening,'Opening stock',number:true),
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
