import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../services/data_service.dart';
import 'invoice_preview_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});
  @override
  State<InvoiceListScreen> createState()=>_InvoiceListScreenState();
}
class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String _query='';
  bool _archived=false;
  DocumentType? _type;

  Future<bool> _confirm(String title, String message) async =>
    (await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(title),content:Text(message),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirm')),
      ],
    )))??false;

  Future<void> _action(Invoice document,String action) async {
    if(action=='preview'){
      await Navigator.push(context,MaterialPageRoute(
        builder:(_)=>InvoicePreviewScreen(invoice:document)));
      return;
    }
    if(action=='delete') {
      final yes=await _confirm('Delete standalone document?',
        'Permanently delete ${document.invoiceNumber}? This cannot be undone. Sales and payments will not be changed.');
      if(!yes)return;
      await DataService().deleteInvoice(document.id);
    }else if(action=='archive'||action=='restore'){
      await DataService().setInvoiceArchived(document.id,action=='archive');
    }else if(action=='duplicate'){
      await DataService().duplicateInvoice(document.id);
    }
    if(mounted){
      setState((){});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(action=='delete'?'Document deleted.':
          action=='duplicate'?'Document copied.':
          action=='archive'?'Document archived.':'Document restored.')));
    }
  }

  @override
  Widget build(BuildContext context){
    final all=DataService().invoices;
    final visible=all.where((d)=>d.archived==_archived &&
      (_type==null||d.type==_type)&&
      [d.invoiceNumber,d.clientName,d.clientPhone].any(
        (v)=>v.toLowerCase().contains(_query.toLowerCase()))).toList()
      ..sort((a,b)=>b.issueDate.compareTo(a.issueDate));
    return Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        TextField(onChanged:(v)=>setState(()=>_query=v),
          decoration:const InputDecoration(labelText:'Search documents',
            prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:SegmentedButton<bool>(
            segments:const [
              ButtonSegment(value:false,label:Text('Active')),
              ButtonSegment(value:true,label:Text('Archived')),
            ],selected:{_archived},
            onSelectionChanged:(s)=>setState(()=>_archived=s.first))),
          const SizedBox(width:8),
          PopupMenuButton<DocumentType?>(
            tooltip:'Filter document type',
            icon:const Icon(Icons.filter_list),
            onSelected:(v)=>setState(()=>_type=v),
            itemBuilder:(_)=>const [
              PopupMenuItem(value:null,child:Text('All types')),
              PopupMenuItem(value:DocumentType.invoice,child:Text('Invoices')),
              PopupMenuItem(value:DocumentType.receipt,child:Text('Receipts')),
              PopupMenuItem(value:DocumentType.quotation,child:Text('Quotations')),
            ],
          ),
        ]),
      ])),
      Expanded(child:visible.isEmpty
        ?Center(child:Text(_archived?'No archived documents.':'No matching documents.'))
        :ListView.builder(padding:const EdgeInsets.fromLTRB(12,0,12,90),
          itemCount:visible.length,itemBuilder:(ctx,i){
            final d=visible[i];
            final code=d.currencyCode??DataService().currentProfile?.currencyCode??'USD';
            final total=NumberFormat.currency(name:code,symbol:code+' ').format(d.finalTotal);
            return Card(child:ListTile(
              onTap:()=>_action(d,'preview'),
              leading:Icon(d.type==DocumentType.receipt?Icons.receipt_long:
                d.type==DocumentType.quotation?Icons.request_quote:Icons.description_outlined),
              title:Text(d.invoiceNumber,maxLines:1,overflow:TextOverflow.ellipsis),
              subtitle:Text('${d.clientName} · ${d.type.name}\n${DateFormat.yMMMd().format(d.issueDate)} · $total'),
              isThreeLine:true,
              trailing:PopupMenuButton<String>(
                tooltip:'Manage document',
                onSelected:(action)=>_action(d,action),
                itemBuilder:(_)=>[
                  const PopupMenuItem(value:'preview',child:Text('View / print / share')),
                  const PopupMenuItem(value:'duplicate',child:Text('Duplicate')),
                  PopupMenuItem(value:d.archived?'restore':'archive',
                    child:Text(d.archived?'Restore':'Archive')),
                  const PopupMenuItem(value:'delete',child:Text('Delete permanently')),
                ],
              ),
            ));
          })),
    ]);
  }
}
