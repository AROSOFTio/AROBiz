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

  String prefix(DocKind kind) => preferences.getString('prefix_'+kind.name) ?? kind.prefix;
  bool get includeYear => preferences.getBool('number_year') ?? true;
  Future<void> setNumbering(Map<DocKind,String> values,bool year) async {
    for(final entry in values.entries){
      final v=entry.value.trim().toUpperCase();
      if(!RegExp(r'^[A-Z0-9]{1,12}$').hasMatch(v))throw ArgumentError('Prefixes must contain 1 to 12 letters or digits.');
    }
    for(final entry in values.entries){await preferences.setString('prefix_'+entry.key.name,entry.value.trim().toUpperCase());}
    await preferences.setBool('number_year',year);
  }
  Future<String> reserveNumber(DocKind kind,DateTime date) async {
    final key='sequence_'+kind.name;
    var n=preferences.getInt(key)??0;
    final used={...documents().map((d)=>d.number),...(preferences.getStringList('reserved_numbers')??<String>[])};
    String result;
    do {
      n++;
      result=[prefix(kind),if(includeYear)date.year.toString(),n.toString().padLeft(5,'0')].join('-');
    } while(used.contains(result));
    if(!await preferences.setStringList('reserved_numbers',[...used,result]))throw StateError('Unable to reserve document number.');
    if(!await preferences.setInt(key,n))throw StateError('Unable to reserve document number.');
    return result;
  }

  Future<void> countActivity(String name) async {
    final key='local_activity_'+name;
    await preferences.setInt(key,(preferences.getInt(key)??0)+1);
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

  Future<int> mergeBackup(List<BusinessDocument> incoming,BusinessInfo backupProfile) async {
    final local=documents();
    final ids=local.map((d)=>d.id).toSet();
    final added=incoming.where((d)=>ids.add(d.id)).toList();
    final numbers=local.map((d)=>d.number).toSet();
    if(added.any((d)=>!numbers.add(d.number)))throw StateError('A backup document number conflicts with a local record. Local data has not changed.');
    await _write([...local,...added]);
    if(profile().name.trim().isEmpty&&backupProfile.name.trim().isNotEmpty){await saveProfile(backupProfile);}
    return added.length;
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
