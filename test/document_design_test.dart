import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:arosoft/business_document.dart';
import 'package:arosoft/document_pdf.dart';
import 'package:arosoft/document_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final logo=base64Encode(img.encodePng(img.Image(width:30,height:20)..setPixelRgb(5,5,10,100,150)));
  BusinessDocument sample(DocKind kind,DocStyle style)=>BusinessDocument(
    id:kind.name,kind:kind,number:'TEST-01',date:DateTime(2026,11,24),
    business:BusinessInfo(name:'Business Name',style:style),party:'Customer Name',partyContact:'',
    currency:'KWD',lines:kind.isLetter?[]:const [DocLine(description:'Sample item',quantity:2,price:25)],
    tax:5,discount:2,subject:'Letter subject',notes:'Notes');
  for(final template in DocTemplate.values){
    test('${template.title}: all 11 types on all 3 paper sizes with logo and custom colors',()async{
      for(final paper in DocPaper.values){
        final style=DocStyle(template:template,paper:paper,logo:logo,primary:'FFC600',secondary:'263145',footer:'Custom company footer',dateFormat:DocDate.monthFirst,taxLabel:'GST');
        for(final kind in DocKind.values){
          final doc=sample(kind,style);
          final restored=BusinessDocument.fromJson(doc.toJson());
          expect(restored.business.style.toJson(),style.toJson());
          final bytes=await documentPdf(restored);
          expect(String.fromCharCodes(bytes.take(4)),'%PDF');
          expect(bytes.length,greaterThan(500));
        }
      }
    });
  }
  test('legacy document records remain readable and repeated logos are stored only once',()async{
    SharedPreferences.setMockInitialValues({});
    final prefs=await SharedPreferences.getInstance(),store=DocumentStore(await SharedPreferences.getInstance());
    final style=DocStyle(logo:logo,template:DocTemplate.elegant);
    final legacy=sample(DocKind.invoice,style).toJson();
    (legacy['business'] as Map).remove('style');
    await prefs.setString(DocumentStore.documentsKey,jsonEncode([legacy]));
    expect(store.documents().single.business.style.template,DocTemplate.modern);
    await store.save(sample(DocKind.invoice,style));
    await store.save(sample(DocKind.receipt,style));
    final raw=jsonDecode(prefs.getString(DocumentStore.documentsKey)!) as Map;
    expect(raw['logos'],[logo]);
    expect(store.documents().every((d)=>d.business.style.logo==logo),isTrue);
    expect(toMinor(1.234,'KWD'),1234);
    expect(toMinor(1234,'JPY'),1234);
  });
}
