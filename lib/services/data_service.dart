import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_profile.dart';
import '../models/invoice.dart';
import 'database_helper.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  SharedPreferences? _prefs;
  BusinessProfile? currentProfile;
  List<Invoice> invoices = [];

  bool get _onlineAuth => const String.fromEnvironment('SUPABASE_URL').isNotEmpty && const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY').isNotEmpty;
  bool get isLoggedIn => _onlineAuth ? Supabase.instance.client.auth.currentSession != null : (_prefs?.getBool('is_logged_in') ?? false);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadProfile();
    await loadInvoices();
  }

  Future<void> login(String identifier, String password) async {
    if (_onlineAuth) {
      final auth = Supabase.instance.client.auth;
      final result = await auth.signInWithPassword(
        email: identifier.contains('@') ? identifier.trim().toLowerCase() : null,
        phone: identifier.contains('@') ? null : identifier.trim(),
        password: password,
      );
      if (result.session == null) throw Exception('Please confirm your email or phone before logging in.');
      final metadata = result.user?.userMetadata ?? {};
      await saveProfile(BusinessProfile(
        name: (metadata['businessName'] ?? 'My Business').toString(),
        category: (metadata['businessCategory'] ?? '').toString(),
        location: (metadata['location'] ?? '').toString(),
        email: result.user?.email,
        phone: result.user?.phone,
      ));
      return;
    }
    final user = await DatabaseHelper().loginUser(identifier, password);
    if (user != null) {
      await _prefs?.setBool('is_logged_in', true);
      
      // Merge or load their profile
      BusinessProfile profile = BusinessProfile(
        name: user['businessName'],
        category: user['businessCategory'],
        location: user['location'],
        email: user['email'],
        phone: user['phone'],
        logoPath: currentProfile?.logoPath, // Retain logo if it was there
        servicesOffered: currentProfile?.servicesOffered ?? [],
        localPaymentDetails: currentProfile?.localPaymentDetails,
      );
      await saveProfile(profile);
    } else {
      throw Exception('Invalid credentials');
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
    if (_onlineAuth) {
      final result = await Supabase.instance.client.auth.signUp(
        email: isEmail ? identifier.trim().toLowerCase() : null,
        phone: isEmail ? null : identifier.trim(),
        password: password,
        data: {'businessName': businessName, 'businessCategory': category, 'location': location},
      );
      if (result.user == null) throw Exception('Registration failed. Please try again.');
      if (result.session == null) throw Exception('Account created. Please verify your email or phone, then log in.');
      await saveProfile(BusinessProfile(name: businessName, category: category, location: location, email: isEmail ? identifier.trim().toLowerCase() : null, phone: isEmail ? null : identifier.trim()));
      return;
    }
    await DatabaseHelper().registerUser(
      identifier: identifier,
      isEmail: isEmail,
      password: password,
      businessName: businessName,
      category: category,
      location: location,
    );
    // Auto login
    await login(identifier, password);
  }

  Future<void> logout() async {
    if (_onlineAuth) await Supabase.instance.client.auth.signOut();
    await _prefs?.setBool('is_logged_in', false);
    // Clear from memory, but you can choose to keep the profile string or delete it.
    // For local-first, keeping the data string doesn't hurt, but for security:
    currentProfile = null;
  }

  Future<void> loadProfile() async {
    final String? profileJson = _prefs?.getString('business_profile');
    if (profileJson != null) {
      currentProfile = BusinessProfile.fromJson(jsonDecode(profileJson));
    }
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    currentProfile = profile;
    await _prefs?.setString('business_profile', jsonEncode(profile.toJson()));
  }

  Future<void> loadInvoices() async {
    final List<String>? invoicesJson = _prefs?.getStringList('invoices');
    if (invoicesJson != null) {
      invoices = invoicesJson
          .map((jsonStr) => Invoice.fromJson(jsonDecode(jsonStr)))
          .toList();
    }
  }

  Future<void> saveInvoice(Invoice invoice) async {
    final int index = invoices.indexWhere((i) => i.id == invoice.id);
    if (index >= 0) {
      invoices[index] = invoice;
    } else {
      invoices.add(invoice);
    }
    await _saveInvoicesToStorage();
  }

  Future<void> deleteInvoice(String id) async {
    invoices.removeWhere((i) => i.id == id);
    await _saveInvoicesToStorage();
  }

  Future<void> _saveInvoicesToStorage() async {
    final List<String> invoicesJson = invoices
        .map((i) => jsonEncode(i.toJson()))
        .toList();
    await _prefs?.setStringList('invoices', invoicesJson);
  }
}
