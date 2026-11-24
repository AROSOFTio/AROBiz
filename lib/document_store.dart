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
    return (jsonDecode(raw) as List).map((entry) =>
      BusinessDocument.fromJson(Map<String,dynamic>.from(entry as Map))).toList()
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
    if (!await preferences.setString(documentsKey,jsonEncode(records.map((d)=>d.toJson()).toList()))) {
      throw StateError('Unable to save documents on this device.');
    }
  }
}
