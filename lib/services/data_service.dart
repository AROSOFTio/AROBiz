import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/business_profile.dart';
import '../models/invoice.dart';

/// Cloud authentication and business-scoped offline draft cache.
///
/// Offline drafts remain local until cloud synchronization succeeds. This is a
/// foundational sync implementation, not an encrypted storage solution.
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final SupabaseClient _cloud = Supabase.instance.client;
  SharedPreferences? _prefs;
  String? _businessId;
  BusinessProfile? currentProfile;
  List<Invoice> invoices = [];
  String? syncError;

  String? get businessId => _businessId;
  bool get isLoggedIn => _cloud.auth.currentUser != null && _businessId != null;

  String _key(String item) {
    final uid = _cloud.auth.currentUser?.id;
    if (uid == null || _businessId == null) {
      throw StateError('No authenticated business selected');
    }
    return 'arodesk:${uid}:${_businessId}:$item';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    currentProfile = null;
    invoices = [];
    _businessId = null;
    await _prefs?.remove('is_logged_in');
    final user = _cloud.auth.currentUser;
    if (user == null) return;
    // Offline restart uses only the last business owned by this auth identity.
    _businessId = _prefs?.getString('arodesk:${user.id}:business');
    if (_businessId != null) {
      await loadProfile();
      await loadInvoices();
    }
    try {
      await _activateBusiness();
    } catch (e) {
      syncError = e.toString();
    }
  }

  Future<void> _activateBusiness() async {
    final user = _cloud.auth.currentUser;
    if (user == null) throw StateError('Sign in first');
    final memberships = await _cloud.from('business_memberships')
      .select('business_id').eq('user_id', user.id).limit(1);
    if (memberships.isEmpty) {
      final pending = _prefs?.getString('arodesk:pending:${user.email?.toLowerCase()}');
      if (pending == null) throw StateError('No business found. Complete business registration.');
      final profile = BusinessProfile.fromJson(jsonDecode(pending));
      final created = await _cloud.rpc('create_my_business', params: {
        'p_name': profile.name,
        'p_category': profile.category,
        'p_currency': profile.currency,
        'p_address': profile.location,
      });
      _businessId = created as String;
      await _prefs?.remove('arodesk:pending:${user.email?.toLowerCase()}');
    } else {
      _businessId = memberships.first['business_id'] as String;
    }
    await _prefs?.setString('arodesk:${user.id}:business', _businessId!);
    final business = await _cloud.from('businesses').select()
      .eq('id', _businessId!).single();
    currentProfile = BusinessProfile(
      name: business['name'] as String?,
      category: business['category'] as String?,
      currency: (business['currency'] as String?) ?? 'USD',
      location: business['address'] as String?,
      phone: business['phone'] as String?,
      email: business['email'] as String?,
    );
    await _prefs?.setString(_key('business_profile'), jsonEncode(currentProfile!.toJson()));
    await loadInvoices();
    await syncNow();
  }

  Future<void> login(String identifier, String password) async {
    await _cloud.auth.signInWithPassword(email: identifier.trim(), password: password);
    _businessId = null;
    currentProfile = null;
    invoices = [];
    await _activateBusiness();
  }

  /// Registration requires internet. When email confirmation is enabled,
  /// business creation completes after the user verifies and signs in.
  Future<void> register({
    required String identifier,
    required bool isEmail,
    required String password,
    required String businessName,
    required String category,
    required String location,
    String currency = 'USD',
  }) async {
    if (!isEmail) throw StateError('Use an email address for cloud signup. Phone OTP is not configured.');
    final email = identifier.trim().toLowerCase();
    if (!RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$').hasMatch(email)) {
      throw StateError('Enter a valid email address');
    }
    final profile = BusinessProfile(name: businessName, category: category,
      location: location, email: email, currency: currency);
    await _prefs?.setString('arodesk:pending:$email', jsonEncode(profile.toJson()));
    final result = await _cloud.auth.signUp(email: email, password: password);
    if (result.session == null) {
      throw StateError('Account created. Confirm your email and then sign in to finish setup.');
    }
    await _activateBusiness();
  }

  Future<void> logout() async {
    await _cloud.auth.signOut();
    _businessId = null;
    currentProfile = null;
    invoices = [];
    syncError = null;
  }

  Future<void> loadProfile() async {
    final raw = _prefs?.getString(_key('business_profile'));
    currentProfile = raw == null ? null : BusinessProfile.fromJson(jsonDecode(raw));
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    await _prefs?.setString(_key('business_profile'), jsonEncode(profile.toJson()));
    currentProfile = profile;
    try {
      await _cloud.from('businesses').update({
        'name': profile.name, 'category': profile.category,
        'currency': profile.currency, 'address': profile.location,
        'phone': profile.phone, 'email': profile.email,
      }).eq('id', _businessId!);
      syncError = null;
    } catch (e) {
      syncError = e.toString();
      // A later sync retries documents; profile update retry is not yet supported.
    }
  }

  Future<void> loadInvoices() async {
    final values = _prefs?.getStringList(_key('invoices')) ?? [];
    invoices = values.map((e) => Invoice.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveInvoice(Invoice invoice) async {
    final updated = List<Invoice>.from(invoices);
    final index = updated.indexWhere((e) => e.id == invoice.id);
    if (index < 0) { updated.add(invoice); } else { updated[index] = invoice; }
    await _persistInvoices(updated);
    final dirty = _prefs?.getStringList(_key('pending_docs')) ?? [];
    if (!dirty.contains(invoice.id)) dirty.add(invoice.id);
    await _prefs?.setStringList(_key('pending_docs'), dirty);
    await syncNow();
  }

  Future<void> deleteInvoice(String id) async {
    // Deletion cannot safely be synchronized without tombstones. Keep deletion
    // local only for documents never uploaded; otherwise block destructive action.
    final pending = _prefs?.getStringList(_key('pending_docs')) ?? [];
    if (!pending.contains(id)) {
      throw StateError('Deleting synced documents needs an audited void/credit-note workflow');
    }
    await _persistInvoices(List<Invoice>.from(invoices)..removeWhere((e) => e.id == id));
    pending.remove(id);
    await _prefs?.setStringList(_key('pending_docs'), pending);
  }

  Future<void> _persistInvoices(List<Invoice> updated) async {
    if (await _prefs?.setStringList(_key('invoices'),
      updated.map((e) => jsonEncode(e.toJson())).toList()) != true) {
      throw StateError('Local document save failed');
    }
    invoices = updated;
  }

  Future<void> syncNow() async {
    final user = _cloud.auth.currentUser;
    final business = _businessId;
    if (user == null || business == null) return;
    try {
      final dirty = List<String>.from(_prefs?.getStringList(_key('pending_docs')) ?? []);
      for (final id in dirty) {
        final matches = invoices.where((e) => e.id == id);
        if (matches.isEmpty) continue;
        final inv = matches.first;
        await _cloud.from('documents').upsert({
          'id': inv.id, 'business_id': business, 'created_by': user.id,
          'type': inv.type.name.toLowerCase(), 'status': 'draft',
          'document_number': inv.invoiceNumber, 'currency': inv.currency,
          'issue_date': inv.issueDate.toIso8601String().substring(0, 10),
          'lines': inv.items.map((e) => e.toJson()).toList(),
          'subtotal': inv.subtotal, 'discount_total': inv.discount,
          'tax_total': inv.taxAmount, 'total': inv.finalTotal,
        }, onConflict: 'business_id,id');
        dirty.remove(id);
        await _prefs?.setStringList(_key('pending_docs'), dirty);
      }
      syncError = null;
    } catch (e) {
      syncError = e.toString();
    }
  }
}
