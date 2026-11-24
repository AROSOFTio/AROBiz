import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import 'business_document.dart';
import 'document_store.dart';
import 'document_pdf.dart';
import 'design_editor.dart';
import 'cloud_service.dart';
import 'zoom_pdf_pages.dart';

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
  const DocumentEditor({super.key,required this.store,required this.kind,this.existing,this.assignedNumber,this.initialTemplate});
  final DocumentStore store;
  final DocKind kind;
  final BusinessDocument? existing;
  final String? assignedNumber;
  final DocTemplate? initialTemplate;
  @override
  State<DocumentEditor> createState()=>_DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  final form=GlobalKey<FormState>();
  late final String id;
  late final TextEditingController number,business,contact,address,taxId,party,partyContact,reference,terms,subject,notes,tax,discount,opening;
  late String currency;
  late DocStyle design;
  late DateTime date;
  final lines=<_LineFields>[];
  bool busy=false;
  int step=0;
  final scroll=ScrollController();
  DocKind get kind=>widget.kind;
  @override
  void initState(){
    super.initState();
    final d=widget.existing,p=d?.business??widget.store.profile();
    id=d?.id??const Uuid().v4();
    date=d?.date??DateTime.now();
    currency=d?.currency??p.currency;
    design=d==null?p.style.copyWith(template:widget.initialTemplate??kind.layouts.first):p.style;
    number=TextEditingController(text:d?.number??widget.assignedNumber??'${kind.prefix}-${DateFormat('yyyyMMdd').format(date)}-${id.substring(0,6).toUpperCase()}');
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
    scroll.dispose();
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
    business:BusinessInfo(name:business.text.trim(),contact:contact.text.trim(),address:address.text.trim(),taxId:taxId.text.trim(),currency:currency,style:design),
    party:party.text.trim(),partyContact:partyContact.text.trim(),currency:currency,
    lines:lines.map((line)=>DocLine(description:line.description.text.trim(),
      quantity:kind.isStatement||kind==DocKind.receipt||kind==DocKind.paymentVoucher?1:value(line.quantity).clamp(0,1000000).toDouble(),price:kind.hasPrices||kind.isStatement?value(line.price):0,
      credit:kind.isStatement?value(line.credit):0)).toList(),
    tax:kind.hasTax?value(tax).clamp(0,100).toDouble():0,discount:kind.hasTax?value(discount):0,
    opening:kind.isStatement?value(opening):0,reference:reference.text.trim(),
    terms:terms.text.trim(),subject:subject.text.trim(),notes:notes.text.trim(),
  );
  void notice(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  Future<void> output({required bool preview}) async {
    if(busy)return;
    final valid=form.currentState!.validate();
    // The scrolling form may unmount fields outside the viewport. Validate
    // every controller independently before storing or generating any PDF.
    if(!valid||[number,business,party].any((c)=>requiredText(c.text)!=null)){
      notice('Complete document number, business and recipient details.');return;
    }
    if(kind.isLetter&&(requiredText(subject.text)!=null||requiredText(notes.text)!=null)){
      notice('Enter the letter subject and content.');return;
    }
    if(!kind.isLetter&&lines.any((line)=>
      requiredText(line.description.text)!=null||
      (!kind.isStatement&&numeric(line.quantity.text,positive:true,maximum:1000000)!=null)||
      ((kind.hasPrices||kind.isStatement)&&numeric(line.price.text)!=null)||
      (kind.isStatement&&numeric(line.credit.text)!=null))){
      notice('Complete each item with a description and valid amounts.');return;
    }
    if((kind.hasTax&&(numeric(tax.text,maximum:100)!=null||numeric(discount.text)!=null))||
      (kind.isStatement&&numeric(opening.text,signed:true)!=null)){
      notice('Check the discount, tax or opening balance.');return;
    }
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
        await widget.store.countActivity('generated');
        recordUsage('document_generated',kind:doc.kind);
        if(!mounted)return;
        await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>DocumentPreview(document:doc,bytes:bytes,store:widget.store)));
      }else{
        await widget.store.save(doc);
        recordUsage('document_saved',kind:doc.kind);
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
        field(line.description,kind.isStatement?'Date / transaction description':kind==DocKind.receipt||kind==DocKind.paymentVoucher?'Payment for':'Description',required:true,maxLength:250),
        if(kind==DocKind.receipt||kind==DocKind.paymentVoucher) numberField(line.price,'Amount')
        else if(kind.isStatement) Row(children:[
          Expanded(child:numberField(line.price,'Debit')),const SizedBox(width:12),Expanded(child:numberField(line.credit,'Credit')),
        ]) else Row(children:[
          Expanded(child:numberField(line.quantity,'Quantity',positive:true,maximum:1000000)),
          if(kind.hasPrices)...[const SizedBox(width:12),Expanded(child:numberField(line.price,'Unit price'))],
        ]),
      ]),
    ));
  }
  void advance(){
    if(!(form.currentState?.validate()??true))return;
    if(step==0&&party.text.trim().isEmpty){notice('Enter the recipient name.');return;}
    if(step==1){
      if(kind.isLetter&&(subject.text.trim().isEmpty||notes.text.trim().isEmpty)){notice('Complete the letter.');return;}
      if(!kind.isLetter&&lines.any((l)=>l.description.text.trim().isEmpty||(!kind.isStatement&&numeric(l.quantity.text,positive:true,maximum:1000000)!=null)||((kind.hasPrices||kind.isStatement)&&numeric(l.price.text)!=null)||(kind.isStatement&&numeric(l.credit.text)!=null))){notice('Complete each item or transaction.');return;}
    }
    setState(()=>step++);
    if(scroll.hasClients)scroll.jumpTo(0);
  }
  void back(){
    if(step==0){Navigator.maybePop(context);return;}
    setState(()=>step--);
    if(scroll.hasClients)scroll.jumpTo(0);
  }
  List<BusinessDocument> get linkable => widget.store.documents().where((d)=>
    d.id!=id&&d.party.trim().toLowerCase()==party.text.trim().toLowerCase()&&
    (kind==DocKind.invoice?d.kind==DocKind.quotation||d.kind==DocKind.purchaseOrder:
     kind==DocKind.deliveryNote?d.kind==DocKind.purchaseOrder||d.kind==DocKind.invoice:
     d.kind==DocKind.invoice||d.kind==DocKind.purchaseOrder)).toList();
  @override
  Widget build(BuildContext context){
    final doc=snapshot();
    final steps=[kind.partyLabel,kind.contentTitle,'Review & design'];
    final layouts={...kind.layouts,design.template};
    return Scaffold(
      appBar:AppBar(title:Text(kind.title),leading:IconButton(onPressed:busy?null:back,icon:const Icon(Icons.arrow_back))),
      body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),
        child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(20,12,20,8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('STEP ${step+1} OF 3',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1.4,color:Colors.black54)),
            const SizedBox(height:8),
            Row(children:List.generate(3,(i)=>Expanded(child:AnimatedContainer(duration:const Duration(milliseconds:220),height:4,margin:EdgeInsets.only(right:i==2?0:5),color:i<=step?Theme.of(context).colorScheme.primary:const Color(0xFFE5E7EB))))),
          ])),
          Expanded(child:Form(key:form,child:ListView(controller:scroll,padding:const EdgeInsets.fromLTRB(20,12,20,24),children:[
            Text(steps[step],style:const TextStyle(fontSize:28,fontWeight:FontWeight.w800,letterSpacing:-.8)),
            const SizedBox(height:6),
            Text(step==0?'Who is this document for?':step==1?'Enter the information needed for this document.':'Check the details and select a layout.',style:const TextStyle(color:Colors.black54)),
            const SizedBox(height:22),
            if(step==0)...[
              field(party,'Name',required:true),field(partyContact,'Contact / address (optional)'),
              OutlinedButton.icon(icon:const Icon(Icons.calendar_today_outlined),label:Text(DateFormat(design.dateFormat.pattern).format(date)),onPressed:busy?null:()async{
                final picked=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(1900),lastDate:DateTime(2200));
                if(picked!=null&&mounted)setState(()=>date=picked);
              }),
            ],
            if(step==1)...[
              if(!kind.isLetter&&kind!=DocKind.deliveryNote) ...[
                DropdownButtonFormField<String>(initialValue:currency,decoration:const InputDecoration(labelText:'Currency'),
                  items:currencies.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
                  onChanged:busy?null:(v){if(v!=null)setState(()=>currency=v);}),const SizedBox(height:14),
              ],
              if(kind.isLetter)...[field(subject,'Subject',required:true),field(notes,'Letter content',required:true,maxLength:4000,maxLines:9)]
              else ...[
                if(kind.isStatement)...[numberField(opening,'Opening balance',signed:true),const SizedBox(height:12)],
                for(var i=0;i<lines.length;i++)lineCard(i),
                OutlinedButton.icon(onPressed:busy||lines.length>=100?null:()=>setState(()=>lines.add(_LineFields())),icon:const Icon(Icons.add),label:Text(kind.isStatement?'Add transaction':'Add item')),
                if(kind.hasTax)...[section('Discount & tax'),Row(children:[
                  Expanded(child:numberField(discount,'Discount amount')),const SizedBox(width:12),
                  Expanded(child:numberField(tax,'${design.taxLabel} %',maximum:100)),
                ])],
                const SizedBox(height:16),
                field(terms,kind.termsLabel),field(notes,'Notes (optional)',maxLength:1000,maxLines:3),
              ],
            ],
            if(step==2)...[
              Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(doc.number,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
                const SizedBox(height:8),Text(doc.party),
                if(kind.hasPrices||kind.isStatement)...[const SizedBox(height:12),Text(kind.totalLabel,style:const TextStyle(color:Colors.black54)),Text(money(doc.total,currency),style:const TextStyle(fontSize:27,fontWeight:FontWeight.w800))],
              ]))),
              if(kind.canLink&&linkable.isNotEmpty)...[
                const SizedBox(height:14),
                DropdownButtonFormField<String>(key:ValueKey('link_${reference.text}'),initialValue:linkable.any((d)=>d.number==reference.text)?reference.text:'',
                  decoration:const InputDecoration(labelText:'Link an existing document (optional)'),
                  items:[const DropdownMenuItem(value:'',child:Text('No linked document')),for(final d in linkable)DropdownMenuItem(value:d.number,child:Text(d.number))],
                  onChanged:(v)=>setState(()=>reference.text=v??'')),
              ],
              section('Choose a template'),
              for(final t in layouts) Padding(padding:const EdgeInsets.only(bottom:8),child:InkWell(onTap:()=>setState(()=>design=design.copyWith(template:t)),child:Container(
                padding:const EdgeInsets.all(10),decoration:BoxDecoration(border:Border.all(color:design.template==t?Colors.black:const Color(0xFFE5E7EB),width:design.template==t?2:1),borderRadius:BorderRadius.circular(8)),
                child:Row(children:[SizedBox(width:66,height:82,child:TemplateThumbnail(template:t,style:design,kind:kind)),const SizedBox(width:14),Expanded(child:Text(kind.layoutTitle(t),style:const TextStyle(fontWeight:FontWeight.w600))),Icon(design.template==t?Icons.check_circle:Icons.radio_button_unchecked,color:Colors.black)])))),
              if(busy)const LinearProgressIndicator(),
            ],
          ]))),
          Container(padding:const EdgeInsets.fromLTRB(20,12,20,16),decoration:const BoxDecoration(color:Colors.white,border:Border(top:BorderSide(color:Color(0xFFE5E7EB)))),child:Row(children:[
            if(step>0)...[OutlinedButton(onPressed:busy?null:back,child:const Text('Back')),const SizedBox(width:10)],
            Expanded(child:FilledButton(onPressed:busy?null:step<2?advance:()=>output(preview:true),child:Text(step<2?'Next':'Generate PDF'))),
            if(step==2)...[const SizedBox(width:8),IconButton(tooltip:'Save locally',onPressed:busy?null:()=>output(preview:false),icon:const Icon(Icons.save_outlined))],
          ])),
        ]),
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
    body:PdfPreview.builder(build:(_)=>widget.bytes,useActions:false,allowPrinting:false,allowSharing:false,canChangeOrientation:false,canChangePageFormat:false,canDebug:false,dpi:160,
      pagesBuilder:(_,pages)=>ZoomPdfPages(pages:pages)),
    bottomNavigationBar:SafeArea(child:Container(decoration:const BoxDecoration(border:Border(top:BorderSide(color:Color(0xFFE5E0EB)))),padding:const EdgeInsets.symmetric(horizontal:8,vertical:8),child:Row(children:[
      action('Save',Icons.bookmark_border,()async{
        await widget.store.save(widget.document);
        recordUsage('document_saved',kind:widget.document.kind);
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved on this device.')));
      }),
      action('Print',Icons.print_outlined,()async{
        recordUsage('print_requested',kind:widget.document.kind);
        await Printing.layoutPdf(name:filename,onLayout:(_)=>widget.bytes);
      }),
      action('Share',Icons.share_outlined,()async{
        await widget.store.countActivity('shared');
        recordUsage('share_requested',kind:widget.document.kind);
        await Printing.sharePdf(bytes:widget.bytes,filename:filename);
      }),
      action('Download',Icons.download_outlined,()async{
        final saved=await const MethodChannel('crown_docs/export').invokeMethod<bool>('savePdf',{'name':filename,'bytes':widget.bytes});
        if(saved==true){
          await widget.store.countActivity('downloaded');
          if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PDF saved to your selected location.')));
        }
      },primary:true),
    ]))),
  );
  Widget action(String label,IconData icon,Future<void> Function() call,{bool primary=false})=>Expanded(child:Padding(
    padding:const EdgeInsets.symmetric(horizontal:2),
    child:Material(color:primary?Theme.of(context).colorScheme.primary:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7),side:BorderSide(color:primary?Theme.of(context).colorScheme.primary:const Color(0xFFE1DCE9))),
      child:InkWell(borderRadius:BorderRadius.circular(7),onTap:busy?null:()=>run(call),child:Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(icon,size:20,color:primary?Colors.white:Theme.of(context).colorScheme.primary),
        const SizedBox(height:4),Text(label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:primary?Colors.white:Colors.black87)),
      ]))))));
}
