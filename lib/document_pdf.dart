import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'business_document.dart';

Future<Uint8List> documentPdf(BusinessDocument doc) async {
  final pdf = pw.Document(title: '${doc.kind.title} ${doc.number}', author:doc.business.name);
  final style=doc.business.style;
  final ink=PdfColor.fromHex(style.secondary);
  final muted=PdfColor.fromHex('#526579');
  final accent=PdfColor.fromHex(style.primary);
  final compact=style.template==DocTemplate.compact||style.paper==DocPaper.a5;
  final fontSize=compact?9.0:10.0;
  final pageFormat=switch(style.paper){DocPaper.a4=>PdfPageFormat.a4,DocPaper.letter=>PdfPageFormat.letter,DocPaper.a5=>PdfPageFormat.a5};
  final foreground=(accent.red*.299+accent.green*.587+accent.blue*.114)>.56?PdfColors.black:PdfColors.white;
  final inkForeground=(ink.red*.299+ink.green*.587+ink.blue*.114)>.56?PdfColors.black:PdfColors.white;
  pw.ImageProvider? logo;
  if(style.logo.isNotEmpty){try{logo=pw.MemoryImage(base64Decode(style.logo));}catch(_){}}
  pw.Widget logoBox()=>logo==null?pw.SizedBox():pw.Container(
    width:compact?46:66,height:compact?40:54,margin:const pw.EdgeInsets.only(bottom:8),
    child:pw.Image(logo,fit:pw.BoxFit.contain));
  pw.Widget company({PdfColor? color,bool center=false})=>pw.Column(
    crossAxisAlignment:center?pw.CrossAxisAlignment.center:pw.CrossAxisAlignment.start,
    children:[
      if(logo!=null)logoBox(),
      pw.Text(doc.business.name,textAlign:center?pw.TextAlign.center:pw.TextAlign.left,
        style:pw.TextStyle(fontSize:compact?15:20,fontWeight:pw.FontWeight.bold,color:color??ink)),
      if(doc.business.address.isNotEmpty)pw.Text(doc.business.address,style:pw.TextStyle(fontSize:fontSize,color:color??muted)),
      if(doc.business.contact.isNotEmpty)pw.Text(doc.business.contact,style:pw.TextStyle(fontSize:fontSize,color:color??muted)),
      if(doc.business.taxId.isNotEmpty)pw.Text('Tax ID: ${doc.business.taxId}',style:pw.TextStyle(fontSize:fontSize,color:color??muted)),
    ]);
  pw.Widget title({PdfColor? color,bool center=false})=>pw.Column(
    crossAxisAlignment:center?pw.CrossAxisAlignment.center:pw.CrossAxisAlignment.end,children:[
    pw.Text(doc.kind.title.toUpperCase(),textAlign:center?pw.TextAlign.center:pw.TextAlign.right,
      style:pw.TextStyle(fontSize:compact?15:21,fontWeight:pw.FontWeight.bold,color:color??accent)),
    pw.SizedBox(height:5),
    pw.Text(doc.number,style:pw.TextStyle(fontSize:fontSize,color:color??muted)),
    pw.Text(DateFormat(style.dateFormat.pattern).format(doc.date),style:pw.TextStyle(fontSize:fontSize,color:color??muted)),
  ]);
  pw.Widget split({PdfColor? color})=>pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
    pw.Expanded(child:company(color:color)),pw.SizedBox(width:12),pw.Expanded(child:title(color:color))]);
  pw.Widget heading()=>switch(style.template){
    DocTemplate.modern=>pw.Column(children:[pw.Container(height:4,color:accent),pw.SizedBox(height:16),split()]),
    DocTemplate.classic=>pw.Container(padding:const pw.EdgeInsets.all(12),decoration:pw.BoxDecoration(border:pw.Border.all(color:ink,width:1.2)),child:split()),
    DocTemplate.executive=>pw.Container(padding:const pw.EdgeInsets.all(15),color:accent,child:split(color:foreground)),
    DocTemplate.minimal=>pw.Column(children:[split(),pw.SizedBox(height:10),pw.Divider(color:ink,thickness:.6)]),
    DocTemplate.elegant=>pw.Column(children:[company(center:true),pw.SizedBox(height:10),pw.Divider(color:accent,thickness:1.5),pw.SizedBox(height:8),title(center:true)]),
    DocTemplate.compact=>pw.Column(children:[split(),pw.SizedBox(height:5),pw.Container(height:2,color:accent)]),
  };
  final lightTable=style.template==DocTemplate.minimal||style.template==DocTemplate.classic;
  final headerColor=style.template==DocTemplate.executive?accent:ink;
  final headerText=lightTable?ink:style.template==DocTemplate.executive?foreground:inkForeground;
  String amount(int n) => money(n,doc.currency);
  pw.Widget label(String value) => pw.Text(value,style:pw.TextStyle(fontSize:10,color:muted));
  pw.Widget totalRow(String key,String value,{bool emphasis=false}) => pw.Padding(
    padding:const pw.EdgeInsets.symmetric(vertical:5),
    child:pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[
      pw.Expanded(child:pw.Text(key,style:pw.TextStyle(fontSize:emphasis?13:10,fontWeight:emphasis?pw.FontWeight.bold:pw.FontWeight.normal))),
      pw.Text(value,style:pw.TextStyle(fontSize:emphasis?15:11,fontWeight:pw.FontWeight.bold,color:ink)),
    ]),
  );
  final payment=doc.kind==DocKind.receipt||doc.kind==DocKind.paymentVoucher;
  final adjustment=doc.kind==DocKind.creditNote||doc.kind==DocKind.debitNote;
  final headers = payment ? ['Payment for','Amount'] : doc.kind.isStatement ? ['Transaction / reference','Debit','Credit','Balance'] :
    doc.kind.hasPrices ? ['Description','Qty','Unit price','Amount'] : ['Description','Quantity'];
  var running = toMinor(doc.opening,doc.currency);
  final rows = <List<String>>[];
  for (final line in doc.lines) {
    if (doc.kind.isStatement) {
      final debit=toMinor(line.price,doc.currency),credit=toMinor(line.credit,doc.currency);
      running += debit-credit;
      rows.add([line.description,amount(debit),amount(credit),amount(running)]);
    } else if(payment){
      rows.add([line.description,amount(line.total(doc.currency))]);
    } else {
      rows.add([line.description,NumberFormat('0.###').format(line.quantity),
        if(doc.kind.hasPrices) ...[amount(toMinor(line.price,doc.currency)),amount(line.total(doc.currency))]]);
    }
  }
  pdf.addPage(pw.MultiPage(
    pageFormat:pageFormat,
    margin:pw.EdgeInsets.all(compact?23:36),
    maxPages:100,
    footer:(context)=>pw.Column(mainAxisSize:pw.MainAxisSize.min,crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
      pw.Divider(color:accent,thickness:style.template==DocTemplate.minimal ? 0.5 : 1),
      if(style.footer.isNotEmpty)pw.Padding(padding:const pw.EdgeInsets.only(bottom:4),child:pw.Text(style.footer,textAlign:pw.TextAlign.center,style:pw.TextStyle(color:muted,fontSize:8))),
      pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[
        pw.Expanded(child:label(doc.number)),label('Page ${context.pageNumber} of ${context.pagesCount}'),
      ]),
    ]),
    build:(context)=>[
      heading(),
      pw.SizedBox(height:22),
      pw.Divider(color:PdfColors.grey300),
      pw.SizedBox(height:8),
      label(doc.kind.partyLabel),
      pw.Text(doc.party,style:pw.TextStyle(fontSize:13,fontWeight:pw.FontWeight.bold,color:ink)),
      if(doc.partyContact.isNotEmpty) label(doc.partyContact),
      if(doc.reference.isNotEmpty) label('Linked document: '+doc.reference),
      if(doc.terms.isNotEmpty) label(doc.kind.termsLabel+': '+doc.terms),
      if(doc.kind==DocKind.proforma) pw.Padding(padding:const pw.EdgeInsets.only(top:8),child:label('Preliminary document. Not a payment receipt.')),
      if(doc.kind==DocKind.quotation) pw.Padding(padding:const pw.EdgeInsets.only(top:8),child:label('Proposed prices and services')),
      if(payment||adjustment) pw.Container(margin:const pw.EdgeInsets.only(top:14),padding:const pw.EdgeInsets.all(13),
        decoration:pw.BoxDecoration(border:pw.Border.all(color:accent),borderRadius:pw.BorderRadius.circular(4)),
        child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
          label(doc.kind.totalLabel),pw.Text(amount(doc.total),style:pw.TextStyle(fontSize:23,color:ink,fontWeight:pw.FontWeight.bold)),
        ])),
      if(doc.kind==DocKind.statement) pw.Container(margin:const pw.EdgeInsets.only(top:12),padding:const pw.EdgeInsets.all(10),color:PdfColors.grey100,
        child:pw.Row(children:[pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[label('Opening balance'),pw.Text(amount(toMinor(doc.opening,doc.currency)))])),
          pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[label('Closing balance'),pw.Text(amount(doc.total),style:pw.TextStyle(fontWeight:pw.FontWeight.bold))]))])),

      pw.SizedBox(height:20),
      if(doc.kind.isLetter) ...[
        pw.Text(doc.subject,style:pw.TextStyle(fontSize:14,fontWeight:pw.FontWeight.bold,color:ink)),
        pw.SizedBox(height:14),
        ...doc.notes.split('\n').map((paragraph)=>pw.Padding(padding:const pw.EdgeInsets.only(bottom:7),child:pw.Text(paragraph,style:const pw.TextStyle(fontSize:11,lineSpacing:3)))),
      ] else ...[
        if(doc.kind==DocKind.deliveryNote) label('Check quantities on receipt. No prices are shown.'),
        pw.TableHelper.fromTextArray(headers:headers,data:rows,
          headerDecoration:pw.BoxDecoration(color:lightTable?PdfColors.grey200:headerColor),
          headerStyle:pw.TextStyle(color:headerText,fontSize:fontSize,fontWeight:pw.FontWeight.bold),
          cellStyle:pw.TextStyle(fontSize:fontSize),cellPadding:pw.EdgeInsets.all(compact?5:8),
          oddRowDecoration:style.template==DocTemplate.modern||style.template==DocTemplate.elegant?const pw.BoxDecoration(color:PdfColors.grey100):null,
          border:style.template==DocTemplate.minimal?pw.TableBorder(horizontalInside:const pw.BorderSide(color:PdfColors.grey300,width:.4)):pw.TableBorder.all(color:PdfColors.grey300,width:.5),
          columnWidths:{0:const pw.FlexColumnWidth(3)},
          cellAlignments:{for(var i=1;i<headers.length;i++) i:pw.Alignment.centerRight}),
        pw.SizedBox(height:14),
        if(doc.kind.hasPrices || doc.kind.isStatement)
          pw.Align(alignment:pw.Alignment.centerRight,child:pw.Container(width:compact?220:260,child:pw.Column(children:[
            if(doc.kind.isStatement) ...[
              totalRow('Total debits',amount(doc.debitTotal)),
              totalRow('Total credits',amount(doc.creditTotal)),
            ] else if(doc.kind.hasTax) ...[
              totalRow('Subtotal',amount(doc.subtotal)),
              if(doc.discountMinor!=0) totalRow('Discount',amount(doc.discountMinor)),
              if(doc.tax!=0) totalRow('${style.taxLabel} (${doc.tax}%)',amount(doc.taxMinor)),
            ],
            pw.Divider(color:accent),pw.Container(padding:const pw.EdgeInsets.symmetric(horizontal:8),color:style.template==DocTemplate.minimal?PdfColors.white:PdfColors.grey100,child:totalRow(doc.kind.totalLabel,amount(doc.total),emphasis:true)),
          ]))),
        if(doc.notes.isNotEmpty) ...[pw.SizedBox(height:18),label('Notes'),pw.Text(doc.notes,style:const pw.TextStyle(fontSize:10))],
      ],
      pw.SizedBox(height:30),
      if(doc.kind.isLetter) ...[
        pw.Text('Yours faithfully,',style:const pw.TextStyle(fontSize:11)),pw.SizedBox(height:24),pw.Text(doc.business.name),
      ],
      if(doc.kind==DocKind.deliveryNote||doc.kind==DocKind.paymentVoucher||doc.kind==DocKind.purchaseOrder||doc.kind==DocKind.quotation||doc.kind==DocKind.receipt) ...[
        pw.Row(children:[
          pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Divider(color:ink),label(doc.kind==DocKind.deliveryNote?'Dispatched by':doc.kind==DocKind.quotation?'Prepared by':'Authorized by')])),
          pw.SizedBox(width:24),
          pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Divider(color:ink),label(doc.kind==DocKind.quotation?'Accepted by':doc.kind==DocKind.purchaseOrder?'Approved by':'Received by')])),
        ]),
      ],
    ],
  ));
  return pdf.save();
}
