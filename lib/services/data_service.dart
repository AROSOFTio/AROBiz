import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_profile.dart';
import '../models/invoice.dart';
import 'database_helper.dart';

/// Local, offline account storage. This is not a cloud SaaS session.
/// Old unscoped data deliberately remains untouched pending owner-reviewed migration.
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  SharedPreferences? _prefs;
  int? _userId;
  BusinessProfile? currentProfile;
  List<Invoice> invoices = [];

  bool get isLoggedIn => _userId != null;
  String _key(String item) {
    if (_userId == null) throw StateError('Sign in before accessing business data');
    return 'account:${_userId!}:$item';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Intentionally require fresh login after upgrade; do not reuse old boolean
    // which had no verified user identity attached to it.
    _userId = null;
    currentProfile = null;
    invoices = [];
    await _prefs?.remove('is_logged_in');
  }

  Future<void> login(String identifier, String password) async {
    final user = await DatabaseHelper().loginUser(identifier, password);
    if (user == null) throw Exception('Invalid credentials');
    // Always drop previous account's cached state before changing accounts.
    _userId = user['id'] as int;
    currentProfile = null;
    invoices = [];
    await loadProfile();
    await loadInvoices();
    if (currentProfile == null) {
      await saveProfile(BusinessProfile(
        name: user['businessName'] as String?,
        category: user['businessCategory'] as String?,
        location: user['location'] as String?,
        email: user['email'] as String?,
        phone: user['phone'] as String?,
      ));
    }
  }

  Future<void> register({
    required String identifier,
    required bool isEmail,
    required String password,
    required String businessName,
    required String category,
    required String location,
  }) async {
    await DatabaseHelper().registerUser(
      identifier: identifier,
      isEmail: isEmail,
      password: password,
      businessName: businessName,
      category: category,
      location: location,
    );
    await login(identifier, password);
  }

  Future<void> logout() async {
    _userId = null;
    currentProfile = null;
    invoices = [];
    await _prefs?.remove('is_logged_in');
  }

  Future<void> loadProfile() async {
    final data = _prefs?.getString(_key('business_profile'));
    currentProfile = data == null ? null : BusinessProfile.fromJson(jsonDecode(data));
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    await _prefs?.setString(_key('business_profile'), jsonEncode(profile.toJson()));
    currentProfile = profile;
  }

  Future<void> loadInvoices() async {
    final values = _prefs?.getStringList(_key('invoices')) ?? [];
    invoices = values.map((value) => Invoice.fromJson(jsonDecode(value))).toList();
  }

  Future<void> saveInvoice(Invoice invoice) async {
    _key('invoices'); // Validate active account before any mutation.
    final index = invoices.indexWhere((value) => value.id == invoice.id);
    final updated = List<Invoice>.from(invoices);
    if (index == -1) {
      updated.add(invoice);
    } else {
      updated[index] = invoice;
    }
    await _persistInvoices(updated);
  }

  Future<void> deleteInvoice(String id) async {
    _key('invoices');
    final updated = List<Invoice>.from(invoices)..removeWhere((value) => value.id == id);
    await _persistInvoices(updated);
  }

  Future<void> _persistInvoices(List<Invoice> updated) async {
    final prefs = _prefs;
    if (prefs == null) throw StateError('Storage not initialized');
    final ok = await prefs.setStringList(
      _key('invoices'),
      updated.map((value) => jsonEncode(value.toJson())).toList(),
    );
    if (!ok) throw StateError('Could not save document locally');
    invoices = updated;
  }
}
