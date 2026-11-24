import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import 'business_document.dart';
import 'document_store.dart';
import 'document_pdf.dart';

class _LineFields {
  _LineFields([DocLine? line]) :
    description=TextEditingController(text:line?.description??''),
    quantity=TextEditingController(text:line==null?'1':line.quantity.toString()),
    price=TextEditingController(text:line==null?'':line.price.toString()),
    credit=TextEditingController(text:line==null?'':line.credit.toString());
  final TextEditingController description,quantity,price,credit;
  void dispose(){for(final c in [description,quantity,price,credit]){c.dispose();}}
}

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({super.key,required this.store,required this.kind,this.existing});
  final DocumentStore store;
  final DocKind kind;
  final BusinessDocument? existing;
  @override
  State<DocumentEditor> createState()=>_DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  final form=GlobalKey<FormState>();
  late final String id;
  late final TextEditingController number,business,contact,address,taxId,party,partyContact,reference,terms,subject,notes,tax,discount,opening;
  late String currency;
  late DateTime date;
  final lines=<_LineFields>[];
  bool busy=false;
  DocKind get kind=>widget.kind;
  @override
  void initState(){
    super.initState();
    final d=widget.existing,p=d?.business??widget.store.profile();
    id=d?.id??const Uuid().v4();
    date=d?.date??DateTime.now();
    currency=d?.currency??p.currency;
    number=TextEditingController(text:d?.number??'${kind.prefix}-${DateFormat('yyyyMMdd').format(date)}-${id.substring(0,6).toUpperCase()}');
    business=TextEditingController(text:p.name);
    contact=TextEditingController(text:p.contact);
    address=TextEditingController(text:p.address);
    taxId=TextEditingController(text:p.taxId);
    party=TextEditingController(text:d?.party??'');
    partyContact=TextEditingController(text:d?.partyContact??'');
    reference=TextEditingController(text:d?.reference??'');
    terms=TextEditingController(text:d?.terms??'');
    subject=TextEditingController(text:d?.subject??'');
    notes=TextEditingController(text:d?.notes??'');
    tax=TextEditingController(text:d==null?'0':d.tax.toString());
    discount=TextEditingController(text:d==null?'0':d.discount.toString());
    opening=TextEditingController(text:d==null?'0':d.opening.toString());
    if(!kind.isLetter){
      lines.addAll(d?.lines.map((line)=>_LineFields(line))??[_LineFields()]);
      if(lines.isEmpty)lines.add(_LineFields());
    }
  }
  @override
  void dispose(){
    for(final c in [number,business,contact,address,taxId,party,partyContact,reference,terms,subject,notes,tax,discount,opening]){c.dispose();}
    for(final line in lines){line.dispose();}
    super.dispose();
  }
  double value(TextEditingController c){
    final n=double.tryParse(c.text.trim());
    return n!=null&&n.isFinite&&n.abs()<=1000000000?n:0;
  }
  String? numeric(String? input,{bool positive=false,bool signed=false,double maximum=1000000000}){
    final text=input?.trim()??'';
    if(text.isEmpty)return positive?'Enter a quantity':null;
    final n=double.tryParse(text);
    if(n==null||!n.isFinite||n.abs()>maximum||(!signed&&n<0)||(positive&&n<=0))return 'Enter a valid number';
    return null;
  }
  String? requiredText(String? text)=>text==null||text.trim().isEmpty?'Required':null;
  BusinessDocument snapshot()=>BusinessDocument(
    id:id,kind:kind,number:number.text.trim(),date:date,
    business:BusinessInfo(name:business.text.trim(),contact:contact.text.trim(),address:address.text.trim(),taxId:taxId.text.trim(),currency:currency),
    party:party.text.trim(),partyContact:partyContact.text.trim(),currency:currency,
    lines:lines.map((line)=>DocLine(description:line.description.text.trim(),
      quantity:kind.isStatement?1:value(line.quantity),price:kind.hasPrices||kind.isStatement?value(line.price):0,
      credit:kind.isStatement?value(line.credit):0)).toList(),
    tax:kind.hasTax?value(tax):0,discount:kind.hasTax?value(discount):0,
    opening:kind.isStatement?value(opening):0,reference:reference.text.trim(),
    terms:terms.text.trim(),subject:subject.text.trim(),notes:notes.text.trim(),
  );
  void notice(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  Future<void> output({required bool preview}) async {
    if(busy||!form.currentState!.validate())return;
    final doc=snapshot();
    if((kind==DocKind.receipt||kind==DocKind.paymentVoucher)&&doc.total<=0){notice('Enter the amount actually paid.');return;}
    if(doc.discountMinor>doc.subtotal){notice('Discount cannot exceed the subtotal.');return;}
    if(kind.isStatement&&doc.lines.any((line)=>(line.price>0&&line.credit>0)||(line.price==0&&line.credit==0))){
      notice('Enter either a debit or a credit on each statement row.');return;
    }
    setState(()=>busy=true);
    try{
      if(preview){
        final bytes=await documentPdf(doc);
        if(!mounted)return;
        await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>DocumentPreview(document:doc,bytes:bytes,store:widget.store)));
      }else{
        await widget.store.save(doc);
        if(mounted)notice('Document saved on this device.');
      }
    }catch(e){if(mounted)notice('Unable to finish: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Widget field(TextEditingController controller,String label,{bool required=false,int maxLength=150,int maxLines=1}){
    return Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(
      controller:controller,enabled:!busy,validator:required?requiredText:null,
      maxLength:maxLength,maxLines:maxLines,
      decoration:InputDecoration(labelText:label,counterText:''),
    ));
  }
  Widget numberField(TextEditingController controller,String label,{bool positive=false,bool signed=false,double maximum=1000000000}){
    return TextFormField(controller:controller,enabled:!busy,
      keyboardType:TextInputType.numberWithOptions(decimal:true,signed:signed),
      validator:(input)=>numeric(input,positive:positive,signed:signed,maximum:maximum),
      onChanged:(_)=>setState((){}),
      decoration:InputDecoration(labelText:label));
  }
  Widget section(String text)=>Padding(padding:const EdgeInsets.only(top:12,bottom:10),child:Text(text,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)));
  Widget lineCard(int i){
    final line=lines[i];
    return Card(margin:const EdgeInsets.only(bottom:12),child:Padding(
      padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Text(kind.isStatement?'Transaction ${i+1}':'Item ${i+1}',style:const TextStyle(fontWeight:FontWeight.bold)),
          const Spacer(),IconButton(tooltip:'Remove item',onPressed:busy||lines.length==1?null:()=>setState(()=>lines.removeAt(i).dispose()),icon:const Icon(Icons.close))]),
        field(line.description,kind.isStatement?'Date / transaction description':'Description',required:true,maxLength:250),
        if(kind.isStatement) Row(children:[
          Expanded(child:numberField(line.price,'Debit')),const SizedBox(width:12),Expanded(child:numberField(line.credit,'Credit')),
        ]) else Row(children:[
          Expanded(child:numberField(line.quantity,'Quantity',positive:true,maximum:1000000)),
          if(kind.hasPrices)...[const SizedBox(width:12),Expanded(child:numberField(line.price,'Unit price'))],
        ]),
      ]),
    ));
  }
  @override
  Widget build(BuildContext context){
    final total=snapshot().total;
    return Scaffold(
      appBar:AppBar(title:Text(kind.title),actions:[
        IconButton(tooltip:'Save document',onPressed:busy?null:()=>output(preview:false),icon:const Icon(Icons.save_outlined)),
      ]),
      body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),
        child:Form(key:form,child:ListView(padding:const EdgeInsets.fromLTRB(18,12,18,24),children:[
          if(busy)const LinearProgressIndicator(),
          section('Document details'),
          field(number,'Document number',required:true,maxLength:60),
          OutlinedButton.icon(icon:const Icon(Icons.calendar_today_outlined),
            label:Text(DateFormat('dd MMM yyyy').format(date)),
            onPressed:busy?null:()async{
              final picked=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(1900),lastDate:DateTime(2200));
              if(picked!=null&&mounted)setState(()=>date=picked);
            }),
          const SizedBox(height:12),
          if(!kind.isLetter&&kind!=DocKind.deliveryNote) DropdownButtonFormField<String>(
            initialValue:currency,decoration:const InputDecoration(labelText:'Currency'),
            items:currencies.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
            onChanged:busy?null:(v){if(v!=null)setState(()=>currency=v);}),
          section('Your business'),
          field(business,'Business name',required:true),
          field(contact,'Phone / email'),
          field(address,'Address'),
          field(taxId,'Tax ID (optional)'),
          section(kind.partyLabel),
          field(party,'Name',required:true),
          field(partyContact,'Contact / address'),
          field(reference,'Related document / reference'),
          if(kind.isLetter)...[
            field(subject,'Subject',required:true),
            field(notes,'Letter content',required:true,maxLength:4000,maxLines:9),
          ]else...[
            if(kind.isStatement)...[section('Opening balance'),numberField(opening,'Opening balance',signed:true)],
            section(kind.isStatement?'Transactions':'Items / services'),
            for(var i=0;i<lines.length;i++)lineCard(i),
            OutlinedButton.icon(onPressed:busy||lines.length>=100?null:()=>setState(()=>lines.add(_LineFields())),
              icon:const Icon(Icons.add),label:Text(kind.isStatement?'Add transaction':'Add item')),
            if(kind.hasTax)...[
              section('Discount & tax'),Row(children:[
                Expanded(child:numberField(discount,'Discount amount')),const SizedBox(width:12),
                Expanded(child:numberField(tax,'Tax %',maximum:100)),
              ]),
            ],
            if(kind.hasPrices||kind.isStatement) Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Row(children:[
              Expanded(child:Text(kind.totalLabel,style:const TextStyle(fontWeight:FontWeight.w700))),
              Text(money(total,currency),style:TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:Theme.of(context).colorScheme.primary)),
            ])),
            field(terms,kind==DocKind.receipt||kind==DocKind.paymentVoucher?'Payment method / transaction reference':'Terms / due date / validity'),
            field(notes,'Notes (optional)',maxLength:1000,maxLines:3),
          ],
          const SizedBox(height:8),
          FilledButton.icon(onPressed:busy?null:()=>output(preview:true),icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('Generate & preview PDF')),
          const SizedBox(height:8),
          OutlinedButton.icon(onPressed:busy?null:()=>output(preview:false),icon:const Icon(Icons.save_outlined),label:const Text('Save document locally')),
        ])),
      ))),
    );
  }
}

class DocumentPreview extends StatefulWidget {
  const DocumentPreview({super.key,required this.document,required this.bytes,required this.store});
  final BusinessDocument document;
  final Uint8List bytes;
  final DocumentStore store;
  @override
  State<DocumentPreview> createState()=>_DocumentPreviewState();
}
class _DocumentPreviewState extends State<DocumentPreview> {
  bool busy=false;
  String get filename=>'${widget.document.number.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'),'_')}.pdf';
  Future<void> run(Future<void> Function() action)async{
    if(busy)return;
    setState(()=>busy=true);
    try{await action();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not complete action: $e')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.document.kind.title)),
    body:PdfPreview(build:(_)=>widget.bytes,allowPrinting:false,allowSharing:false,canChangeOrientation:false,canChangePageFormat:false,canDebug:false),
    bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
      Expanded(child:OutlinedButton.icon(onPressed:busy?null:()=>run(()async{
        await widget.store.save(widget.document);
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved on this device.')));
      }),icon:const Icon(Icons.save_outlined),label:const Text('Save'))),
      const SizedBox(width:6),
      Expanded(child:FilledButton.icon(onPressed:busy?null:()=>run(()async{
        await Printing.sharePdf(bytes:widget.bytes,filename:filename);
      }),icon:const Icon(Icons.share_outlined),label:const Text('Share'))),
      const SizedBox(width:6),
      Expanded(child:OutlinedButton.icon(onPressed:busy?null:()=>run(()async{
        await Printing.layoutPdf(name:filename,onLayout:(_)=>widget.bytes);
      }),icon:const Icon(Icons.print_outlined),label:const Text('Print'))),
    ]))),
  );
}
