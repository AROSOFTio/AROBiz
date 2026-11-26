import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/inventory_service.dart';
import '../services/sales_service.dart';
import 'team_screen.dart';

class HomeScreen extends StatefulWidget{
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onNewSale,onAccounting,onDebtors,onBusinessChanged;
  final bool reportsOnly;
  const HomeScreen({super.key,this.onNavigate,this.onNewSale,this.onAccounting,this.onDebtors,this.onBusinessChanged,this.reportsOnly=false});
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>{
  bool _loading=true; String? _error;
  String _currency=''; String _businessName='';
  String? _displayCurrency;
  int _productCount=0,_lowCount=0,_saleCount=0,_debtorCount=0;
  double _sales=0,_collected=0,_outstanding=0;
  List<double> _days=List.filled(7,0);
  List<Map<String,dynamic>> _recent=[];
  @override void initState(){super.initState();_load();}
  double _n(dynamic x)=>x is num?x.toDouble():0;
  Future<void> _load()async{
    setState((){_loading=true;_error=null;});
    try{
      final p=DataService().currentProfile;
      final business=await InventoryService.instance.ensureBusiness(
        name:p?.name??'My Business',category:p?.category??'Other');
      final teamsFuture=TeamService.instance.businesses();
      final productsFuture=InventoryService.instance.products(business);
      final stockFuture=InventoryService.instance.balances(business);
      final moneyFuture=InventoryService.instance.businessCurrency(business);
      final displayFuture=InventoryService.instance.businessDisplayCurrency(business);
      final salesFuture=SalesService.instance.list(business);
      final products=await productsFuture,stock=await stockFuture;
      final currency=await moneyFuture,transactions=await salesFuture;
      final displayed=await displayFuture;
      final memberships=await teamsFuture;
      final current=memberships.where((m)=>m['business_id'].toString()==business).toList();
      final first=DateTime.now();
      final start=DateTime(first.year,first.month,first.day).subtract(const Duration(days:6));
      final daily=List<double>.filled(7,0);
      var gross=0.0,collected=0.0,owed=0.0,count=0,debtors=0;
      for(final sale in transactions){
        if(sale['kind']!='sale'||sale['currency']!=currency)continue;
        count++;
        final value=_n(sale['total'])-_n(sale['returned_total']);
        final payment=_n(sale['paid_total'])-_n(sale['refunded_total']);
        final debt=(value-payment).clamp(0,double.infinity).toDouble();
        gross+=value;collected+=payment;owed+=debt;
        if(debt>0.005)debtors++;
        final dt=DateTime.tryParse(sale['created_at'].toString())?.toLocal();
        if(dt!=null){
          final i=DateTime(dt.year,dt.month,dt.day).difference(start).inDays;
          if(i>=0&&i<7)daily[i]+=value;
        }
      }
      if(mounted)setState((){
        _businessName=current.isNotEmpty?current.first['business_name'].toString():
          (p?.name??'My Business');_currency=currency;
        _displayCurrency=displayed;
        _productCount=products.length;
        _lowCount=products.where((x)=>x['track_stock']==true&&
          (stock[x['id'].toString()]??0)<=_n(x['reorder_level'])).length;
        _saleCount=count;_debtorCount=debtors;_sales=gross;
        _collected=collected;_outstanding=owed;_days=daily;
        _recent=transactions.where((x)=>x['kind']=='sale').take(6).toList();
      });
    }catch(_){if(mounted)setState(()=>_error='Business statistics could not load. Pull down to retry.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Widget _metric(String label,String value,IconData icon,Color color){
    return Container(
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:Colors.white,
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:const Color(0xFFE8EDF4))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:35,height:35,
          decoration:BoxDecoration(color:color.withAlpha(24),borderRadius:BorderRadius.circular(9)),
          child:Icon(icon,color:color,size:20)),
        const SizedBox(height:8),
        Text(label,maxLines:2,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:12,color:Color(0xFF61708B))),
        const SizedBox(height:5),
        Text(value,maxLines:2,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,
            color:Color(0xFF142235),letterSpacing:-0.35)),
      ]));
  }
  Widget _salesChart(NumberFormat money){
    final high=_days.fold<double>(0,(a,b)=>a>b?a:b);
    final first=DateTime.now().subtract(const Duration(days:6));
    return Card(child:Padding(padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Sales overview',style:Theme.of(context).textTheme.titleMedium),
        Text('Past seven days · '+_currency,style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:14),
        SizedBox(height:170,child:Row(crossAxisAlignment:CrossAxisAlignment.end,
          children:List.generate(7,(i){
            final amount=_days[i];
            final height=high<=0?4.0:(amount/high*120).clamp(4,120).toDouble();
            return Expanded(child:Tooltip(
              message:DateFormat.yMd().format(first.add(Duration(days:i)))+
                ' · '+money.format(amount),
              child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
                Text(amount==0?'':NumberFormat.compact().format(amount),
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:9)),
                const SizedBox(height:5),
                AnimatedContainer(duration:const Duration(milliseconds:260),
                  curve:Curves.easeOutCubic,height:height,
                  margin:const EdgeInsets.symmetric(horizontal:5),
                  decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary,
                    borderRadius:const BorderRadius.vertical(top:Radius.circular(6)))),
                const SizedBox(height:7),
                Text(DateFormat.E().format(first.add(Duration(days:i))),
                  style:const TextStyle(fontSize:10)),
              ])));
          })),
        ),
      ])));
  }
  Future<void> _switchBusiness()async{
    try{
      final rows=await TeamService.instance.businesses();
      if(!mounted)return;
      final chosen=await showModalBottomSheet<String>(context:context,builder:(ctx)=>SafeArea(child:ListView(shrinkWrap:true,children:[
        const ListTile(title:Text('Select business',style:TextStyle(fontWeight:FontWeight.w700))),
        for(final row in rows)ListTile(leading:const Icon(Icons.store_outlined),title:Text(row['business_name'].toString()),onTap:()=>Navigator.pop(ctx,row['business_id'].toString())),
      ])));
      if(chosen==null||!mounted)return;
      await InventoryService.instance.selectBusiness(chosen);
      if(!mounted)return;
      widget.onBusinessChanged?.call();
      await _load();
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Unable to change business.')));}
  }
  Widget _modules(BuildContext context){
    final items=<({String label,IconData icon,VoidCallback? action})>[
      (label:'Products',icon:Icons.inventory_2_outlined,action:widget.onNavigate==null?null:()=>widget.onNavigate!(2)),
      (label:'Inventory',icon:Icons.warehouse_outlined,action:widget.onNavigate==null?null:()=>widget.onNavigate!(2)),
      (label:'Customers',icon:Icons.people_outline,action:widget.onDebtors),
      (label:'Sales',icon:Icons.receipt_long_outlined,action:widget.onNewSale==null?null:()=>widget.onNavigate?.call(3)),
      (label:'Accounting',icon:Icons.account_balance_outlined,action:widget.onAccounting),
      (label:'Documents',icon:Icons.description_outlined,action:widget.onNavigate==null?null:()=>widget.onNavigate!(1)),
      (label:'Reports',icon:Icons.bar_chart_outlined,action:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const Scaffold(body:SafeArea(child:HomeScreen(reportsOnly:true)))))),
    ].where((x)=>x.action!=null).toList();
    return LayoutBuilder(builder:(ctx,box){
      final cols=box.maxWidth>=760?6:box.maxWidth>=340?4:3;
      final width=(box.maxWidth-8*(cols-1))/cols;
      return Wrap(spacing:8,runSpacing:8,children:[
        for(final item in items)SizedBox(width:width,height:94,child:Material(color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10),side:const BorderSide(color:Color(0xFFDCE3EC))),child:InkWell(borderRadius:BorderRadius.circular(10),onTap:item.action,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(item.icon,color:const Color(0xFF2563EB),size:27),const SizedBox(height:9),
          Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:Text(item.label,textAlign:TextAlign.center,maxLines:2,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:Color(0xFF202020)))),
        ])))),
      ]);
    });
  }
  @override Widget build(BuildContext context){
    final money=NumberFormat.currency(name:_currency.isEmpty?'USD':_currency,symbol:_currency+' ',decimalDigits:_currency=='UGX'?0:2);
    return RefreshIndicator(onRefresh:_load,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,20,16,30),children:[
      if(widget.reportsOnly)...[
        Row(children:[IconButton(onPressed:()=>Navigator.maybePop(context),icon:const Icon(Icons.arrow_back)),Text('Reports',style:Theme.of(context).textTheme.headlineSmall)]),
        const Text('Up to 100 recent sales records; not a complete financial statement.'),
        if(!_loading&&_error==null)...[
          const SizedBox(height:14),
          LayoutBuilder(builder:(ctx,b){final cols=b.maxWidth>=760?3:2;final w=(b.maxWidth-8*(cols-1))/cols;return Wrap(spacing:8,runSpacing:8,children:[
            SizedBox(width:w,child:_metric('Recent revenue',money.format(_sales),Icons.shopping_cart_outlined,const Color(0xFF2563EB))),
            SizedBox(width:w,child:_metric('Recent payments',money.format(_collected),Icons.payments_outlined,const Color(0xFF2563EB))),
            SizedBox(width:w,child:_metric('Outstanding',money.format(_outstanding),Icons.receipt_long_outlined,const Color(0xFF2563EB))),
            SizedBox(width:w,child:_metric('Sales',_saleCount.toString(),Icons.point_of_sale_outlined,const Color(0xFF2563EB))),
            SizedBox(width:w,child:_metric('Unpaid sales',_debtorCount.toString(),Icons.people_outline,const Color(0xFF2563EB))),
            SizedBox(width:w,child:_metric('Low stock / products','$_lowCount / $_productCount',Icons.inventory_2_outlined,const Color(0xFF2563EB))),
          ]);}),
          const SizedBox(height:12),_salesChart(money),
        ],
      ]else...[
        const Text('Welcome to AroPOS',style:TextStyle(fontSize:15,color:Color(0xFF64748B))),
        const SizedBox(height:5),
        Text(_businessName.isEmpty?(DataService().currentProfile?.name??'My Business'):_businessName,style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:22),
        if(widget.onNewSale!=null)SizedBox(height:54,child:FilledButton.icon(onPressed:widget.onNewSale,icon:const Icon(Icons.point_of_sale_outlined),label:const Text('New Sale (POS)',style:TextStyle(fontSize:17,fontWeight:FontWeight.w700)))),
        const SizedBox(height:16),_modules(context),const SizedBox(height:18),
        Card(child:ListTile(leading:const Icon(Icons.store_outlined,color:Color(0xFF2563EB)),title:const Text('Business',style:TextStyle(fontSize:12)),subtitle:Text(_businessName.isEmpty?'Select business':_businessName,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:15)),trailing:const Icon(Icons.expand_more),onTap:_switchBusiness)),
        const SizedBox(height:18),
        Row(children:[Expanded(child:Text('Recent activity',style:Theme.of(context).textTheme.titleMedium)),if(widget.onNewSale!=null)TextButton(onPressed:()=>widget.onNavigate?.call(3),child:const Text('View all'))]),
        if(!_loading&&_error==null)Card(child:Column(children:[
          if(_recent.isEmpty)const Padding(padding:EdgeInsets.all(18),child:Text('No recent sales.')),
          for(final sale in _recent.take(3))ListTile(leading:const Icon(Icons.receipt_long_outlined,color:Color(0xFF2563EB)),title:Text(sale['document_number']?.toString()??'Sale'),subtitle:Text(sale['customer_name']?.toString()??'Walk-in customer'),trailing:Text((sale['currency']??_currency).toString()+' '+_n(sale['total']).toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.w600)),onTap:widget.onNewSale==null?null:()=>widget.onNavigate?.call(3)),
        ])),
      ],
      if(_loading)const Padding(padding:EdgeInsets.all(20),child:Center(child:CircularProgressIndicator())),
      if(_error!=null)Card(child:ListTile(title:Text(_error!),trailing:IconButton(onPressed:_load,icon:const Icon(Icons.refresh)))),
    ]));
  }
}
