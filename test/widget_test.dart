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
  test('numbering reserves sequential unique numbers and supports custom prefixes',()async{
    SharedPreferences.setMockInitialValues({});
    final store=DocumentStore(await SharedPreferences.getInstance());
    final date=DateTime(2026,11,24);
    expect(await store.reserveNumber(DocKind.invoice,date),'INV-2026-00001');
    expect(await store.reserveNumber(DocKind.invoice,date),'INV-2026-00002');
    await store.setNumbering({DocKind.invoice:'BILL',DocKind.receipt:'BILL'},false);
    expect(await store.reserveNumber(DocKind.invoice,date),'BILL-00003');
    expect(await store.reserveNumber(DocKind.receipt,date),'BILL-00001');
    expect(await store.reserveNumber(DocKind.receipt,date),'BILL-00002');
    expect(await store.reserveNumber(DocKind.receipt,date),'BILL-00004');
  });
  testWidgets('home opens document editor directly without a sign-in or POS', (tester)async{
    SharedPreferences.setMockInitialValues({});
    final prefs=await SharedPreferences.getInstance();
    final store=DocumentStore(prefs);
    await store.saveProfile(const BusinessInfo(name:'Sample Business'));
    await tester.pumpWidget(CrownDocsApp(store:store));
    expect(find.text('Crown Business Docs'),findsOneWidget);
    expect(find.text('Create a document'),findsOneWidget);
    expect(find.text('Sign in'),findsNothing);
    await tester.drag(find.byType(ListView).first,const Offset(0,-440));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create_invoice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_invoice')));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 3'),findsOneWidget);
    expect(find.text('Business name'),findsNothing);
    await tester.enterText(find.byType(TextFormField).first,'Client A');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 3'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  for(final width in [320.0,360.0,412.0]){
    testWidgets('clean home and receipt wizard fit phone width '+width.toString(),(tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=Size(width,760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store=DocumentStore(await SharedPreferences.getInstance());
      await store.saveProfile(const BusinessInfo(name:'Sample Business'));
      await tester.pumpWidget(CrownDocsApp(store:store));
      await tester.pumpAndSettle();
      final receipt=find.byKey(const Key('create_receipt'));
      await tester.drag(find.byType(ListView).first,const Offset(0,-490));
      await tester.pumpAndSettle();
      await tester.ensureVisible(receipt);
      await tester.pumpAndSettle();
      await tester.tap(receipt);
      await tester.pumpAndSettle();
      expect(find.text('Received from'),findsOneWidget);
      expect(find.text('Business name'),findsNothing);
      await tester.enterText(find.byType(TextFormField).first,'Client A');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Payment details'),findsOneWidget);
      expect(find.text('Amount'),findsOneWidget);
      expect(find.text('Quantity'),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
}
