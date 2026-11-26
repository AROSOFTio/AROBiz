import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

ImageProvider? platformLogo(String? path){
  if(path==null||path.isEmpty)return null;
  if(path.startsWith('data:')){
    try{return MemoryImage(UriData.parse(path).contentAsBytes());}catch(_){return null;}
  }
  if(kIsWeb)return null;
  return FileImage(File(path));
}
Future<Uint8List?> platformLogoBytes(String path)async{
  if(path.startsWith('data:')){
    try{return UriData.parse(path).contentAsBytes();}catch(_){return null;}
  }
  if(kIsWeb)return null;
  final file=File(path);
  return await file.exists()?file.readAsBytes():null;
}
