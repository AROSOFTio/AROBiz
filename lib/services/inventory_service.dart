import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'data_service.dart';
import 'country_currency.dart';

Uint8List _compressProductPhoto(Uint8List source) {
  final decoded=img.decodeImage(source);
  if(decoded==null)throw const FormatException('Unsupported image. Select a JPG or PNG.');
  var photo=decoded;
  if(photo.width>640||photo.height>640){
    final ratio=640/photo.width.clamp(photo.height,double.infinity);
    final width=(photo.width*ratio).round().clamp(1,640).toInt();
    final height=(photo.height*ratio).round().clamp(1,640).toInt();
    photo=img.copyResize(photo,width:width,height:height);
  }
  for(final quality in [76,60,48,36]){
    final bytes=Uint8List.fromList(img.encodeJpg(photo,quality:quality));
    if(bytes.lengthInBytes<1024*1024)return bytes;
  }
  throw StateError('Photo remains too large after compression.');
}

/// Products, services, raw materials and finished goods share one business catalog.
class InventoryService {
  InventoryService._();
  static final InventoryService instance = InventoryService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String?> preferredBusinessId() async {
    final uid=_client.auth.currentUser?.id;
    if(uid==null)return null;
    final prefs=await SharedPreferences.getInstance();
    return prefs.getString('active_business_'+uid);
  }

  Future<void> selectBusiness(String id) async {
    final uid=_client.auth.currentUser?.id;
    if(uid==null)throw StateError('Sign in first.');
    final rows=await _client.rpc('arodesk_my_businesses');
    if(!(rows as List).any((b)=>b['business_id'].toString()==id)){
      throw StateError('Business not available for this user.');
    }
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('active_business_'+uid,id);
  }


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
        .order('created_at').limit(100);
    if (memberships.isNotEmpty) {
      final chosen=await preferredBusinessId();
      final selected=memberships.where((m)=>m['business_id'].toString()==chosen).toList();
      return (selected.isNotEmpty?selected.first:memberships.first)['business_id'].toString();
    }
    // Creates the business and its owner membership in a single DB transaction.
    final result = await _client.rpc('arodesk_create_business', params: {
      'p_name': name.trim().isEmpty ? 'My Business' : name.trim(),
      'p_category': category.trim().isEmpty ? 'Other' : category.trim(),
      'p_currency': currency ?? DataService().currentProfile?.currencyCode ?? CountryCurrency.currency(DataService().currentProfile?.countryCode),
    });
    await selectBusiness(result.toString());
    return result.toString();
  }

  Future<void> updateBusinessProfile({
    required String name,required String category,
    required String address,required String phone,required String email,
  }) async {
    final profile=DataService().currentProfile;
    final business=await ensureBusiness(name:profile?.name??'My Business',
      category:profile?.category??'Other');
    await _client.from('businesses').update({
      'name':name.trim(),'category':category,
      'address':address.trim(),'phone':phone.trim(),'email':email.trim(),
    }).eq('id',business);
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
    if (_client.auth.currentUser != null) {
      await _client.auth.updateUser(UserAttributes(data:{
        'countryCode':countryCode,'currencyCode':currencyCode,
      }));
    }
  }

  Future<String> businessCurrency(String businessId) async {
    final row=await _client.from('businesses').select('currency')
      .eq('id',businessId).single();
    return (row['currency']??'USD').toString();
  }

  Future<List<Map<String, dynamic>>> products(String businessId) async {
    final result = await _client.from('arodesk_products')
        .select('id,name,sku,barcode,category,item_type,unit,sale_price,cost_price,reorder_level,track_stock,active,image_path')
        .eq('business_id', businessId).eq('active', true).order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, double>> balances(String businessId) async {
    final rows = await _client.from('arodesk_inventory_balances')
        .select('product_id,quantity').eq('business_id', businessId);
    return {for (final row in rows) row['product_id'].toString():
      (row['quantity'] as num).toDouble()};
  }

  Future<String> saveProduct(String businessId, {
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
    double openingStock = 0,
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
      if(openingStock>0 && trackStock && type!='service'){
        final created=await _client.rpc('arodesk_create_product_with_stock',params:{
          'p_item':values,'p_opening':openingStock,
        });
        return created.toString();
      }else{
        final created=await _client.from('arodesk_products')
          .insert(values).select('id').single();
        return created['id'].toString();
      }
    } else {
      // RLS and business scope prevent cross-tenant edits.
      await _client.from('arodesk_products').update(values)
          .eq('business_id', businessId).eq('id', id);
      return id;
    }
  }

  String? publicProductImageUrl(dynamic path){
    if(path==null||path.toString().isEmpty)return null;
    return _client.storage.from('arodesk-product-images').getPublicUrl(path.toString());
  }

  Future<void> uploadProductImage(String businessId,String productId,XFile file)async{
    final original=await file.readAsBytes();
    final bytes=await compute(_compressProductPhoto,original);
    final path='$businessId/$productId.jpg';
    await _client.storage.from('arodesk-product-images').uploadBinary(
      path,bytes,fileOptions:const FileOptions(upsert:true,contentType:'image/jpeg'));
    await _client.from('arodesk_products').update({'image_path':path})
      .eq('business_id',businessId).eq('id',productId);
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
