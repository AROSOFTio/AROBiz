import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'business_document.dart';

/// Only compact JSON and business defaults are stored. PDFs are regenerated
/// locally on demand. Old ARODesk keys and cloud data are left untouched.
class DocumentStore {
  DocumentStore(this.preferences);
  final SharedPreferences preferences;
  static const profileKey = 'crown_docs_v1_profile';
  static const documentsKey = 'crown_docs_v1_documents';

  BusinessInfo profile() {
    final raw = preferences.getString(profileKey);
    return raw == null ? const BusinessInfo() : BusinessInfo.fromJson(
      Map<String,dynamic>.from(jsonDecode(raw) as Map));
  }

  List<BusinessDocument> documents() {
    final raw = preferences.getString(documentsKey);
    if (raw == null) return [];
    final decoded=jsonDecode(raw);
    final List records=decoded is List?decoded:(decoded as Map)['records'] as List;
    final List logos=decoded is List?[]:decoded['logos'] as List;
    return records.map((entry){
      final json=Map<String,dynamic>.from(entry as Map);
      final business=Map<String,dynamic>.from(json['business'] as Map);
      final style=Map<String,dynamic>.from(business['style'] as Map? ?? {});
      final index=style.remove('logoIndex');
      if(index is int && index>=0 && index<logos.length)style['logo']=logos[index];
      business['style']=style;json['business']=business;
      return BusinessDocument.fromJson(json);
    }).toList()
      ..sort((a,b)=>b.date.compareTo(a.date));
  }

  Future<void> saveProfile(BusinessInfo profile) async {
    if (!await preferences.setString(profileKey,jsonEncode(profile.toJson()))) {
      throw StateError('Business details could not be saved.');
    }
  }

  Future<void> save(BusinessDocument document) async {
    final records = documents()..removeWhere((d)=>d.id==document.id);
    records.insert(0,document);
    await _write(records);
  }

  Future<void> delete(String id) async {
    final records = documents()..removeWhere((d)=>d.id==id);
    await _write(records);
  }

  Future<void> _write(List<BusinessDocument> records) async {
    final logos=<String>[];
    final encoded=records.map((d){
      final json=d.toJson();
      final business=json['business'] as Map<String,dynamic>;
      final style=business['style'] as Map<String,dynamic>;
      final logo=style.remove('logo') as String? ?? '';
      if(logo.isNotEmpty){if(!logos.contains(logo))logos.add(logo);style['logoIndex']=logos.indexOf(logo);}
      return json;
    }).toList();
    if (!await preferences.setString(documentsKey,jsonEncode({'records':encoded,'logos':logos}))) {
      throw StateError('Unable to save documents on this device.');
    }
  }
}
