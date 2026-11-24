import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arosoft/main.dart';
import 'package:arosoft/business_document.dart';
import 'package:arosoft/document_store.dart';
import 'package:arosoft/document_pdf.dart';

BusinessDocument sample(DocKind kind)=>BusinessDocument(
  id:'test',kind:kind,number:'TEST-001',date:DateTime(2026,11,24),
  business:const BusinessInfo(name:'Sample Business'),party:'Sample Client',partyContact:'',
  currency:'USD',lines:kind.isLetter?[]:const [DocLine(description:'Consulting',quantity:2,price:25)],
  tax:10,discount:5,opening:20,subject:'Business correspondence',notes:'Thank you.',
);
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('invoice calculations use minor units; receipts exclude tax and discount',(){
    expect(sample(DocKind.invoice).subtotal,5000);
    expect(sample(DocKind.invoice).taxMinor,450);
    expect(sample(DocKind.invoice).total,4950);
    expect(sample(DocKind.receipt).total,5000);
    expect(sample(DocKind.statement).total,4500);
    expect(toMinor(1234,'UGX'),1234);
  });
  test('all eleven document types generate PDF bytes without network fonts',()async{
    for(final kind in DocKind.values){
      final doc=sample(kind);
      final decoded=BusinessDocument.fromJson(doc.toJson());
      expect(decoded.kind,kind);
      final bytes=await documentPdf(decoded);
      expect(String.fromCharCodes(bytes.take(4)),'%PDF');
      expect(bytes.length,greaterThan(500));
    }
  });
  test('local saves preserve unrelated legacy settings and support updates/deletion',()async{
    SharedPreferences.setMockInitialValues({'legacy':'keep'});
    final prefs=await SharedPreferences.getInstance();
    final store=DocumentStore(prefs);
    await store.saveProfile(const BusinessInfo(name:'Example',currency:'UGX'));
    await store.save(sample(DocKind.invoice));
    await store.save(sample(DocKind.receipt));
    expect(store.documents().length,1);
    expect(store.documents().single.kind,DocKind.receipt);
    expect(store.profile().currency,'UGX');
    await store.delete('test');
    expect(store.documents(),isEmpty);
    expect(prefs.getString('legacy'),'keep');
  });
  testWidgets('home opens document editor directly without a sign-in or POS', (tester)async{
    SharedPreferences.setMockInitialValues({});
    final prefs=await SharedPreferences.getInstance();
    await tester.pumpWidget(CrownDocsApp(store:DocumentStore(prefs)));
    expect(find.text('Crown Business Docs'),findsOneWidget);
    expect(find.text('Create a document'),findsOneWidget);
    expect(find.text('Sign in'),findsNothing);
    await tester.tap(find.byKey(const Key('create_invoice')));
    await tester.pumpAndSettle();
    expect(find.text('Document details'),findsOneWidget);
    expect(find.text('Your business'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
