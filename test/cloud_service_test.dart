import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:arosoft/cloud_service.dart';
import 'package:arosoft/business_document.dart';
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('analytics is opt-in; payload has only event and kind; opt-out stops collection',()async{
    SharedPreferences.setMockInitialValues({});
    final prefs=await SharedPreferences.getInstance();
    final requests=<Map<String,dynamic>>[];
    final service=CloudService(prefs,client:MockClient((r)async{
      requests.add(jsonDecode(r.body) as Map<String,dynamic>);
      return http.Response('{"ok":true}',200);
    }));
    await service.event('document_generated',kind:DocKind.invoice);
    expect(requests,isEmpty);
    await service.setConsent(true);
    await service.event('document_generated',kind:DocKind.receipt);
    expect(requests.length,2);
    final event=(requests.last['events'] as List).single as Map;
    expect(event.keys.toSet(),{'id','event','kind'});
    expect(event['kind'],'receipt');
    await service.setConsent(false);
    await service.event('share_requested',kind:DocKind.receipt);
    expect(requests.length,2);
    expect(prefs.getStringList(CloudService.queueKey),isNull);
  });
  test('offline usage is bounded and retried with stable event identifiers',()async{
    SharedPreferences.setMockInitialValues({});
    final prefs=await SharedPreferences.getInstance();
    bool online=false;
    final requests=<Map<String,dynamic>>[];
    final service=CloudService(prefs,client:MockClient((r)async{
      if(!online)throw http.ClientException('offline');
      requests.add(jsonDecode(r.body) as Map<String,dynamic>);
      return http.Response('{"ok":true}',200);
    }));
    await service.setConsent(true);
    await service.event('document_generated',kind:DocKind.invoice);
    final queued=prefs.getStringList(CloudService.queueKey)!;
    expect(queued.length,2);
    online=true;
    await service.event('document_saved',kind:DocKind.invoice);
    expect((requests.single['events'] as List).first,jsonDecode(queued.first));
    expect(prefs.getStringList(CloudService.queueKey),isEmpty);
  });
}
