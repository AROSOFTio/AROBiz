import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 1 workspace gateway. Requires the accompanying Supabase migration.
/// Do not enable in a production release until tenant/RLS tests pass.
class WorkspaceService {
  WorkspaceService._();
  static final WorkspaceService instance = WorkspaceService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listWorkspaces() async {
    final user = _db.auth.currentUser;
    if (user == null) throw StateError('Sign in to view your businesses.');
    final rows = await _db
        .from('arodesk_organizations')
        .select('id, name, industry, country_code, currency_code, location')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createWorkspace({
    required String name,
    required String industry,
    required String countryCode,
    required String currencyCode,
    String? location,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw StateError('Sign in before creating a business.');
    if (name.trim().length < 2) throw ArgumentError('Business name is too short.');
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      throw ArgumentError('Choose a valid two-letter country code.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      throw ArgumentError('Choose a valid three-letter currency code.');
    }
    return await _db.from('arodesk_organizations').insert({
      'owner_id': user.id,
      'name': name.trim(),
      'industry': industry.trim().isEmpty ? 'Other' : industry.trim(),
      'country_code': countryCode,
      'currency_code': currencyCode,
      'location': location?.trim(),
    }).select('id, name, industry, country_code, currency_code, location').single();
  }
}
