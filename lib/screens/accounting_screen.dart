import 'package:flutter/material.dart';
import '../services/accounting_service.dart';
import '../services/inventory_service.dart';

class AccountingScreen extends StatefulWidget{
  const AccountingScreen({super.key});
  @override State<AccountingScreen> createState()=>_AccountingScreenState();
}
class _AccountingScreenState extends State<AccountingScreen>{
  bool _busy=true;
  String? _error;
  List<Map<String,dynamic>> _posted=[],_pending=[];
  Future<void> _load()async{
    setState((){_busy=true;_error=null;});
    try{
      final business=await InventoryService.instance.preferredBusinessId();
      if(business==null)throw StateError('Open inventory online once.');
      final accounting=AccountingService.instance;
      final posted=await accounting.posted(business);
      final pending=await accounting.pending(business);
      if(mounted)setState((){_posted=posted;_pending=pending;});
    }catch(_){
      if(mounted)setState(()=>_error='Accounting data unavailable. Sign in online once.');
    }finally{if(mounted)setState(()=>_busy=false);}
  }
  @override void initState(){super.initState();_load();}
  Widget _summary(String title,double amount,IconData icon,Color color){
    return Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,
        borderRadius:BorderRadius.circular(17),
        border:Border.all(color:const Color(0xFFE8EDF4))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:42,height:42,
          decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(12)),
          child:Icon(icon,color:Colors.white,size:22)),
        const SizedBox(height:10),
        Text(title,style:const TextStyle(fontSize:12,color:Color(0xFF63748F))),
        const SizedBox(height:5),
        Text(amount.toStringAsFixed(2),maxLines:1,
          style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:Color(0xFF142235))),
      ])));
  }
  Widget _section(String label,List<Map<String,dynamic>> lines){
    final entries=AccountingService.instance.trialBalance(lines).entries.toList()
      ..sort((a,b)=>a.key.compareTo(b.key));
    var debits=0.0,credits=0.0;
    for(final e in entries){
      debits+=e.value['debit']!;
      credits+=e.value['credit']!;
    }
    return Card(child:Padding(
      padding:const EdgeInsets.all(14),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:9),
          if(entries.isEmpty)const Padding(
            padding:EdgeInsets.symmetric(vertical:12),child:Text('No entries')),
          for(final e in entries)Padding(
            padding:const EdgeInsets.symmetric(vertical:5),
            child:Row(children:[
              Expanded(child:Text(
                '${e.key}  ${AccountingService.names[e.key]??e.key}',
                style:const TextStyle(fontSize:12.5))),
              SizedBox(width:90,child:Text(e.value['debit']!.toStringAsFixed(2),
                textAlign:TextAlign.right,style:const TextStyle(fontSize:12.5))),
              SizedBox(width:90,child:Text(e.value['credit']!.toStringAsFixed(2),
                textAlign:TextAlign.right,style:const TextStyle(fontSize:12.5))),
            ]),
          ),
          const Divider(),
          Row(children:[
            const Expanded(child:Text('Total',style:TextStyle(fontWeight:FontWeight.bold))),
            SizedBox(width:90,child:Text(debits.toStringAsFixed(2),textAlign:TextAlign.right)),
            SizedBox(width:90,child:Text(credits.toStringAsFixed(2),textAlign:TextAlign.right)),
          ]),
          if((debits-credits).abs()>0.01)
            const Padding(padding:EdgeInsets.only(top:8),child:Text(
              'Unbalanced entries need review.',style:TextStyle(color:Colors.red))),
        ],
      ),
    ));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Accounting')),
    body:RefreshIndicator(onRefresh:_load,child:_busy
      ?const Center(child:CircularProgressIndicator())
      :ListView(padding:const EdgeInsets.all(12),children:[
        if(_error!=null)Text(_error!),
        Row(children:[
          _summary('Posted debits',
            _posted.fold<double>(0,(sum,e)=>sum+(e['debit'] as num).toDouble()),
            Icons.account_balance_wallet_outlined,const Color(0xFF006FFF)),
          const SizedBox(width:10),
          _summary('Posted credits',
            _posted.fold<double>(0,(sum,e)=>sum+(e['credit'] as num).toDouble()),
            Icons.payments_outlined,const Color(0xFF0AB867)),
        ]),
        const SizedBox(height:10),
        Row(children:[
          _summary('Pending entries',_pending.length.toDouble(),
            Icons.cloud_upload_outlined,const Color(0xFFFF881A)),
          const SizedBox(width:10),
          _summary('Journal records',_posted.length.toDouble(),
            Icons.receipt_long_outlined,const Color(0xFF6254DC)),
        ]),
        const SizedBox(height:12),
        _section('Posted journal',_posted),
        _section('Pending offline',_pending),
        const SizedBox(height:6),
        const Text('Posted entries are confirmed by the server. Pending entries are provisional.',
          style:TextStyle(fontSize:12)),
      ])),
  );
}
