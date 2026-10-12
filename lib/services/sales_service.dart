import 'dart:async';
import 'offline_sales_service.dart';
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
    String address = '',
    required String paymentMethod,
    List<Map<String, dynamic>>? payments,
    String? dueDate,
  }) async {
    if (quantities.isEmpty) throw ArgumentError('Add at least one item.');
    if(kind=='sale'){
      final local=await OfflineSalesService.instance.queueSale(
        business:businessId,quantities:quantities,customer:customer,
        phone:phone,address:address,payments:payments??[],dueDate:dueDate);
      // Attempt upload without making POS dependent on network availability.
      unawaited(OfflineSalesService.instance.sync(businessId));
      return local;
    }
    if(kind=='quotation'){
      final local=await OfflineSalesService.instance.queueQuotation(
        business:businessId,quantities:quantities,
        customer:customer,phone:phone);
      unawaited(OfflineSalesService.instance.syncQuotes(businessId));
      return local;
    }
    final lines = quantities.entries.map((entry) =>
      {'product_id': entry.key, 'quantity': entry.value}).toList();
    final useCheckout = kind == 'sale';
    final result = await _client.rpc(useCheckout ? 'arodesk_checkout_customer' : 'arodesk_record_sale', params: useCheckout ? { 
      'p_business': businessId,
      'p_lines': lines,
      'p_customer': customer,
      'p_phone': phone,
      'p_address': address,
      'p_payments': payments ?? [],
      'p_due_date': dueDate,
    } : {
      'p_business': businessId,
      'p_kind': kind,
      'p_lines': lines,
      'p_customer': customer,
      'p_phone': phone,
      'p_payment': paymentMethod,
    });
    return result.toString();
  }

  Future<String> returnItem({
    required String businessId, required String saleId,
    required String productId, required double quantity, required double refundAmount,
    String? refundMethod, required bool restock, String reason = '',
  }) async {
    final id=await _client.rpc('arodesk_return_sale_item',params:{
      'p_business':businessId,'p_sale':saleId,'p_product':productId,
      'p_quantity':quantity,'p_refund':refundAmount,
      'p_method':refundAmount>0?refundMethod:null,
      'p_restock':restock,'p_reason':reason,
    });
    return id.toString();
  }

  Future<List<Map<String,dynamic>>> returns(String businessId,String saleId) async {
    final rows=await _client.from('arodesk_sale_returns')
      .select('id,product_id,quantity,refund_amount,refund_method,reason,restock,created_at')
      .eq('business_id',businessId).eq('sale_id',saleId)
      .order('created_at',ascending:false);
    return List<Map<String,dynamic>>.from(rows);
  }

  Future<double> addPayment({
    required String businessId, required String saleId,
    required double amount, required String method, String reference = '',
  }) async {
    final remaining = await _client.rpc('arodesk_add_sale_payment', params: {
      'p_business': businessId, 'p_sale': saleId,
      'p_amount': amount, 'p_method': method, 'p_reference': reference,
    });
    return (remaining as num).toDouble();
  }

  Future<List<Map<String,dynamic>>> debtors(String businessId) async {
    final rows=await _client.rpc('arodesk_debtors',params:{'p_business':businessId});
    return List<Map<String,dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> payments(String businessId, String saleId) async {
    final rows = await _client.from('arodesk_sale_payments')
      .select('amount,method,reference,paid_at')
      .eq('business_id', businessId).eq('sale_id', saleId)
      .order('paid_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> byId(String businessId, String id) async {
    final row = await _client.from('arodesk_sales')
      .select('id,business_id,document_number,kind,customer_name,customer_phone,customer_address,payment_method,currency,subtotal,total,paid_total,returned_total,refunded_total,payment_status,due_date,lines,created_at')
      .eq('business_id', businessId).eq('id', id).single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> list(String businessId) async {
    final rows = await _client.from('arodesk_sales')
      .select('id,document_number,kind,customer_name,currency,total,paid_total,returned_total,refunded_total,payment_status,due_date,created_at')
      .eq('business_id',businessId).order('created_at',ascending:false).limit(100);
    return List<Map<String,dynamic>>.from(rows);
  }
}
