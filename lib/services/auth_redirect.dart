import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

String authRedirect({bool recovery=false}){
  if(kIsWeb)return Uri.base.resolve('./').replace(query:'',fragment:'').toString();
  return recovery?'io.supabase.arodesk://reset-password/':'io.supabase.arodesk://auth-callback/';
}
LaunchMode get authLaunchMode=>kIsWeb?LaunchMode.platformDefault:LaunchMode.externalApplication;
