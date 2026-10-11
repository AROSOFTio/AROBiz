import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_service.dart';
import 'country_currency.dart';

/// Products, services, raw materials and finished goods share one business catalog.
class InventoryService {
  InventoryService._();
  static final InventoryService instance = InventoryService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> ensureBusiness({
    required String name,
    required String category,
    String? currency,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Please sign in to use inventory.');
    final memberships = await _client
        .from('business_memberships')
        .select('business_id')
        .eq('user_id', user.id)
        .limit(1);
    if (memberships.isNotEmpty) return memberships.first['business_id'].toString();
    // Creates the business and its owner membership in a single DB transaction.
    final result = await _client.rpc('arodesk_create_business', params: {
      'p_name': name.trim().isEmpty ? 'My Business' : name.trim(),
      'p_category': category.trim().isEmpty ? 'Other' : category.trim(),
      'p_currency': currency ?? DataService().currentProfile?.currencyCode ?? CountryCurrency.currency(DataService().currentProfile?.countryCode),
    });
    return result.toString();
  }

  Future<void> updateBusinessSettings({
    String? countryCode, required String currencyCode,
  }) async {
    final p=DataService().currentProfile;
    final business=await ensureBusiness(name:p?.name??'My Business',
      category:p?.category??'Other',
      currency:p?.currencyCode??CountryCurrency.currency(countryCode));
    await _client.rpc('arodesk_update_business_preferences',params:{
      'p_business':business,'p_country':countryCode,
      'p_display_currency':currencyCode,
    });
  }

  Future<List<Map<String, dynamic>>> products(String businessId) async {
    final result = await _client.from('arodesk_products')
        .select('id,name,sku,barcode,category,item_type,unit,sale_price,cost_price,reorder_level,track_stock,active')
        .eq('business_id', businessId).eq('active', true).order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, double>> balances(String businessId) async {
    final rows = await _client.from('arodesk_inventory_balances')
        .select('product_id,quantity').eq('business_id', businessId);
    return {for (final row in rows) row['product_id'].toString():
      (row['quantity'] as num).toDouble()};
  }

  Future<void> saveProduct(String businessId, {
    String? id,
    required String name,
    String? sku,
    required String category,
    required String type,
    required String unit,
    required double salePrice,
    required double costPrice,
    required double reorderLevel,
    required bool trackStock,
  }) async {
    if (name.trim().length < 2) throw ArgumentError('Enter a product name.');
    if (salePrice < 0 || costPrice < 0 || reorderLevel < 0) {
      throw ArgumentError('Amounts cannot be negative.');
    }
    final values = <String, dynamic>{
      'business_id': businessId,
      'name': name.trim(),
      'sku': sku == null || sku.trim().isEmpty ? null : sku.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'item_type': type,
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
      'sale_price': salePrice,
      'cost_price': costPrice,
      'reorder_level': reorderLevel,
      'track_stock': trackStock && type != 'service',
    };
    if (id == null) {
      await _client.from('arodesk_products').insert(values);
    } else {
      // RLS and business scope prevent cross-tenant edits.
      await _client.from('arodesk_products').update(values)
          .eq('business_id', businessId).eq('id', id);
    }
  }

  Future<void> postStock(String businessId, String productId, {
    required double delta,
    required String kind,
    String note = '',
  }) async {
    if (delta == 0) throw ArgumentError('Quantity must not be zero.');
    await _client.rpc('arodesk_post_stock', params: {
      'p_business': businessId, 'p_product': productId,
      'p_delta': delta, 'p_kind': kind, 'p_note': note,
    });
  }

  Future<List<Map<String, dynamic>>> movements(String businessId, String productId) async {
    final rows = await _client.from('arodesk_stock_movements')
        .select('change_qty,quantity_after,kind,note,created_at')
        .eq('business_id',businessId).eq('product_id', productId)
        .order('created_at', ascending:false).limit(100);
    return List<Map<String,dynamic>>.from(rows);
  }
}
