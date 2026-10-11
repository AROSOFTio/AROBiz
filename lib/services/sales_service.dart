import 'package:supabase_flutter/supabase_flutter.dart';

/// Catalog-driven sales/quotes are separate from manually prepared documents.
class SalesService {
  SalesService._();
  static final SalesService instance = SalesService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> record({
    required String businessId,
    required String kind,
    required Map<String, double> quantities,
    required String customer,
    required String phone,
    required String paymentMethod,
  }) async {
    if (quantities.isEmpty) throw ArgumentError('Add at least one item.');
    final lines = quantities.entries.map((entry) =>
      {'product_id': entry.key, 'quantity': entry.value}).toList();
    final result = await _client.rpc('arodesk_record_sale', params: {
      'p_business': businessId,
      'p_kind': kind,
      'p_lines': lines,
      'p_customer': customer,
      'p_phone': phone,
      'p_payment': paymentMethod,
    });
    return result.toString();
  }

  Future<Map<String, dynamic>> byId(String businessId, String id) async {
    final row = await _client.from('arodesk_sales')
      .select('id,business_id,document_number,kind,customer_name,customer_phone,payment_method,currency,subtotal,total,lines,created_at')
      .eq('business_id', businessId).eq('id', id).single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> list(String businessId) async {
    final rows = await _client.from('arodesk_sales')
      .select('id,document_number,kind,customer_name,currency,total,created_at')
      .eq('business_id',businessId).order('created_at',ascending:false).limit(100);
    return List<Map<String,dynamic>>.from(rows);
  }
}
