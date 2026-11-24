import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:arosoft/zoom_pdf_pages.dart';
void main(){
  testWidgets('PDF viewer zoom buttons, pinch, fit and page navigation',(tester)async{
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(320,700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image=MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX2cAAAAASUVORK5CYII='));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ZoomPdfPages(pages:[PdfPreviewPageData(image:image,width:595,height:842),PdfPreviewPageData(image:image,width:595,height:842)]))));
    await tester.pumpAndSettle();
    expect(find.text('100%'),findsOneWidget);
    await tester.tap(find.byTooltip('Zoom in'));await tester.pumpAndSettle();
    expect(find.text('125%'),findsOneWidget);
    await tester.tap(find.byTooltip('Fit page'));await tester.pumpAndSettle();
    expect(find.text('100%'),findsOneWidget);
    final center=tester.getCenter(find.byKey(const Key('pdf_zoom_viewer')));
    final a=await tester.startGesture(center-const Offset(25,0),pointer:1);
    final b=await tester.startGesture(center+const Offset(25,0),pointer:2);
    await a.moveBy(const Offset(-45,0));await b.moveBy(const Offset(45,0));
    await tester.pump();await a.up();await b.up();await tester.pumpAndSettle();
    final viewer=tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(),greaterThan(1));
    await tester.tap(find.byTooltip('Next page'));await tester.pumpAndSettle();
    expect(find.text('2 / 2'),findsOneWidget);
    expect(find.text('100%'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
