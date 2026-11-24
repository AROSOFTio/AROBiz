import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'business_document.dart';

Future<Uint8List> documentPdf(BusinessDocument doc) async {
  final pdf = pw.Document(title: '${doc.kind.title} ${doc.number}', author:doc.business.name);
  final ink = PdfColor.fromHex('#152D45');
  final muted = PdfColor.fromHex('#526579');
  final accent = PdfColor.fromHex('#196B74');
  String amount(int n) => money(n,doc.currency);
  pw.Widget label(String value) => pw.Text(value,style:pw.TextStyle(fontSize:10,color:muted));
  pw.Widget totalRow(String key,String value,{bool emphasis=false}) => pw.Padding(
    padding:const pw.EdgeInsets.symmetric(vertical:5),
    child:pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[
      pw.Expanded(child:pw.Text(key,style:pw.TextStyle(fontSize:emphasis?13:10,fontWeight:emphasis?pw.FontWeight.bold:pw.FontWeight.normal))),
      pw.Text(value,style:pw.TextStyle(fontSize:emphasis?15:11,fontWeight:pw.FontWeight.bold,color:ink)),
    ]),
  );
  final headers = doc.kind.isStatement ? ['Transaction / reference','Debit','Credit','Balance'] :
    doc.kind.hasPrices ? ['Description','Qty','Unit price','Amount'] : ['Description','Quantity'];
  var running = toMinor(doc.opening,doc.currency);
  final rows = <List<String>>[];
  for (final line in doc.lines) {
    if (doc.kind.isStatement) {
      final debit=toMinor(line.price,doc.currency),credit=toMinor(line.credit,doc.currency);
      running += debit-credit;
      rows.add([line.description,amount(debit),amount(credit),amount(running)]);
    } else {
      rows.add([line.description,NumberFormat('0.###').format(line.quantity),
        if(doc.kind.hasPrices) ...[amount(toMinor(line.price,doc.currency)),amount(line.total(doc.currency))]]);
    }
  }
  pdf.addPage(pw.MultiPage(
    pageFormat:PdfPageFormat.a4,
    margin:const pw.EdgeInsets.fromLTRB(36,38,36,36),
    maxPages:100,
    footer:(context)=>pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[
      label(doc.number),label('Page ${context.pageNumber} of ${context.pagesCount}'),
    ]),
    build:(context)=>[
      pw.Container(height:4,color:accent),
      pw.SizedBox(height:18),
      pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
        pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
          pw.Text(doc.business.name,style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold,color:ink)),
          if(doc.business.address.isNotEmpty) label(doc.business.address),
          if(doc.business.contact.isNotEmpty) label(doc.business.contact),
          if(doc.business.taxId.isNotEmpty) label('Tax ID: ${doc.business.taxId}'),
        ])),
        pw.SizedBox(width:18),
        pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.end,children:[
          pw.Text(doc.kind.title.toUpperCase(),textAlign:pw.TextAlign.right,
            style:pw.TextStyle(fontSize:21,fontWeight:pw.FontWeight.bold,color:accent)),
          pw.SizedBox(height:4),label(doc.number),
          label(DateFormat('dd MMM yyyy').format(doc.date)),
        ])),
      ]),
      pw.SizedBox(height:22),
      pw.Divider(color:PdfColors.grey300),
      pw.SizedBox(height:8),
      label(doc.kind.partyLabel),
      pw.Text(doc.party,style:pw.TextStyle(fontSize:13,fontWeight:pw.FontWeight.bold,color:ink)),
      if(doc.partyContact.isNotEmpty) label(doc.partyContact),
      if(doc.reference.isNotEmpty) label('Reference: ${doc.reference}'),
      if(doc.terms.isNotEmpty) label(doc.terms),
      pw.SizedBox(height:20),
      if(doc.kind.isLetter) ...[
        pw.Text(doc.subject,style:pw.TextStyle(fontSize:14,fontWeight:pw.FontWeight.bold,color:ink)),
        pw.SizedBox(height:14),
        ...doc.notes.split('\n').map((paragraph)=>pw.Padding(padding:const pw.EdgeInsets.only(bottom:7),child:pw.Text(paragraph,style:const pw.TextStyle(fontSize:11,lineSpacing:3)))),
      ] else ...[
        if(doc.kind.isStatement) totalRow('Opening balance',amount(toMinor(doc.opening,doc.currency))),
        pw.TableHelper.fromTextArray(headers:headers,data:rows,
          headerDecoration:pw.BoxDecoration(color:ink),
          headerStyle:pw.TextStyle(color:PdfColors.white,fontSize:10,fontWeight:pw.FontWeight.bold),
          cellStyle:const pw.TextStyle(fontSize:10),cellPadding:const pw.EdgeInsets.all(8),
          border:pw.TableBorder.all(color:PdfColors.grey300,width:.5),
          columnWidths:{0:const pw.FlexColumnWidth(3)},
          cellAlignments:{for(var i=1;i<headers.length;i++) i:pw.Alignment.centerRight}),
        pw.SizedBox(height:14),
        if(doc.kind.hasPrices || doc.kind.isStatement)
          pw.Align(alignment:pw.Alignment.centerRight,child:pw.Container(width:260,child:pw.Column(children:[
            if(doc.kind.isStatement) ...[
              totalRow('Total debits',amount(doc.debitTotal)),
              totalRow('Total credits',amount(doc.creditTotal)),
            ] else if(doc.kind.hasTax) ...[
              totalRow('Subtotal',amount(doc.subtotal)),
              if(doc.discountMinor!=0) totalRow('Discount',amount(doc.discountMinor)),
              if(doc.tax!=0) totalRow('Tax (${doc.tax}%)',amount(doc.taxMinor)),
            ],
            pw.Divider(color:accent),totalRow(doc.kind.totalLabel,amount(doc.total),emphasis:true),
          ]))),
        if(doc.notes.isNotEmpty) ...[pw.SizedBox(height:18),label('Notes'),pw.Text(doc.notes,style:const pw.TextStyle(fontSize:10))],
      ],
      pw.SizedBox(height:30),
      if(doc.kind==DocKind.deliveryNote || doc.kind==DocKind.paymentVoucher) ...[
        pw.Text('Authorized by: ____________________    Received by: ____________________',style:const pw.TextStyle(fontSize:10)),
      ],
    ],
  ));
  return pdf.save();
}
