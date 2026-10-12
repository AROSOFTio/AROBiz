import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/inventory_service.dart';
import '../services/sales_service.dart';

class HomeScreen extends StatefulWidget{
  final ValueChanged<int>? onNavigate;
  const HomeScreen({super.key,this.onNavigate});
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>{
  bool _loading=true; String? _error;
  String _currency='USD'; String _businessName='';
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
      final productsFuture=InventoryService.instance.products(business);
      final stockFuture=InventoryService.instance.balances(business);
      final moneyFuture=InventoryService.instance.businessCurrency(business);
      final salesFuture=SalesService.instance.list(business);
      final products=await productsFuture,stock=await stockFuture;
      final currency=await moneyFuture,transactions=await salesFuture;
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
        _businessName=p?.name??'My Business';_currency=currency;
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
  Widget _metric(String label,String value,IconData icon){
    final scheme=Theme.of(context).colorScheme;
    return Container(padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),
        color:scheme.surfaceContainerLow,border:Border.all(color:scheme.outlineVariant)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,color:scheme.primary,size:22),const SizedBox(height:10),
        Text(value,maxLines:2,overflow:TextOverflow.ellipsis,
          style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:4),Text(label,style:Theme.of(context).textTheme.labelMedium),
      ]));
  }
  Widget _salesChart(NumberFormat money){
    final high=_days.fold<double>(0,(a,b)=>a>b?a:b);
    final first=DateTime.now().subtract(const Duration(days:6));
    return Card(child:Padding(padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Sales trend',style:Theme.of(context).textTheme.titleMedium),
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
                Container(height:height,
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
  @override Widget build(BuildContext context){
    final money=NumberFormat.currency(name:_currency,symbol:_currency+' ');
    final denominator=_collected+_outstanding;
    final ratio=denominator>0?(_collected/denominator).clamp(0.0,1.0):0.0;
    return RefreshIndicator(onRefresh:_load,child:_loading?
      const Center(child:CircularProgressIndicator()):
      ListView(padding:const EdgeInsets.fromLTRB(16,16,16,55),children:[
        Text('Business overview',style:Theme.of(context).textTheme.headlineSmall),
        Text(_businessName),const SizedBox(height:12),
        if(_error!=null)Padding(padding:const EdgeInsets.all(10),child:Text(_error!)),
        LayoutBuilder(builder:(ctx,c){
          final columns=c.maxWidth>=600?3:2;
          final w=(c.maxWidth-10*(columns-1))/columns;
          return Wrap(spacing:10,runSpacing:10,children:[
            SizedBox(width:w,child:_metric('Net sales',money.format(_sales),Icons.trending_up)),
            SizedBox(width:w,child:_metric('Collected',money.format(_collected),Icons.account_balance_wallet_outlined)),
            SizedBox(width:w,child:_metric('Outstanding',money.format(_outstanding),Icons.receipt_long)),
            SizedBox(width:w,child:_metric('Sales',_saleCount.toString(),Icons.point_of_sale)),
            SizedBox(width:w,child:_metric('Open debtors',_debtorCount.toString(),Icons.people_outline)),
            SizedBox(width:w,child:_metric('Low stock / products',
              _lowCount.toString()+' / '+_productCount.toString(),Icons.inventory_2_outlined)),
          ]);
        }),
        const SizedBox(height:16),_salesChart(money),
        Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Collections vs debt',style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:12),
            ClipRRect(borderRadius:BorderRadius.circular(8),
              child:LinearProgressIndicator(value:ratio,minHeight:12,
                backgroundColor:Colors.orange.shade100)),
            const SizedBox(height:8),
            Text('Collected '+(ratio*100).toStringAsFixed(0)+
              '% · Outstanding '+((1-ratio)*100).toStringAsFixed(0)+'%'),
          ]))),
        const SizedBox(height:12),
        Text('Recent sales',style:Theme.of(context).textTheme.titleMedium),
        if(_recent.isEmpty)const Padding(padding:EdgeInsets.all(20),
          child:Text('No recent transactions.')),
        ..._recent.map((sale)=>ListTile(
          dense:true,leading:const Icon(Icons.receipt_long_outlined),
          title:Text(sale['document_number'].toString()),
          subtitle:Text(sale['customer_name'].toString(),maxLines:1),
          trailing:Column(mainAxisAlignment:MainAxisAlignment.center,
            crossAxisAlignment:CrossAxisAlignment.end,children:[
              Text(sale['currency'].toString()+' '+_n(sale['total']).toStringAsFixed(2)),
              Text(sale['payment_status'].toString(),
                style:Theme.of(context).textTheme.labelSmall),
            ]),
        )),
        const SizedBox(height:10),
        Text('Summary of the latest 100 catalog transactions in the business accounting currency. '
          'Standalone documents are excluded.',
          style:Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
