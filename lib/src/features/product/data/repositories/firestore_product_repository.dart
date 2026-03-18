import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_cost.dart';
import '../../domain/entities/product_page.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const Duration _cacheTtl = Duration(minutes: 5);
  final Set<String> _brandCache = <String>{};
  DateTime? _brandCacheAt;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _brands =>
      _firestore.collection('brands');

  @override
  Future<void> addBrand(String brand) async {
    final normalized = brand.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (_brandCache.contains(normalized)) {
      return;
    }

    await _brands.doc(normalized).set({
      'name': normalized,
    }, SetOptions(merge: true));
    _brandCache.add(normalized);
    _brandCacheAt = DateTime.now();
  }

  @override
  Future<void> addCostToProduct(String sku, ProductCost cost) async {
    final current = await findBySku(sku);
    if (current == null) {
      return;
    }

    final updated = current.copyWith(
      costHistory: [...current.costHistory, cost],
    );
    await _products.doc(sku).set(ProductModel.fromEntity(updated).toMap());
  }

  @override
  Future<Product?> findBySku(String sku) async {
    final doc = await _products.doc(sku).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return ProductModel.fromMap(doc.data()!);
  }

  @override
  Future<List<String>> listBrands() async {
    final now = DateTime.now();
    final hasFreshCache =
        _brandCacheAt != null && now.difference(_brandCacheAt!) <= _cacheTtl;
    if (_brandCache.isNotEmpty && hasFreshCache) {
      final cached = _brandCache.toList(growable: false)..sort();
      return cached;
    }

    final snapshot = await _brands.get();
    final brands =
        snapshot.docs
            .map((doc) => (doc.data()['name'] as String? ?? '').trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false)
          ..sort();

    _brandCache
      ..clear()
      ..addAll(brands);
    _brandCacheAt = now;

    return brands;
  }

  @override
  Future<List<Product>> listProducts() async {
    final snapshot = await _products.get();
    return snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<ProductPage> listProductsPage({
    required int limit,
    String? afterSku,
  }) async {
    var query = _products.orderBy(FieldPath.documentId).limit(limit);

    if (afterSku != null && afterSku.isNotEmpty) {
      query = query.startAfter([afterSku]);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.data()))
        .toList(growable: false);
    final nextCursor = snapshot.docs.length < limit
        ? null
        : snapshot.docs.last.id;

    return ProductPage(items: items, nextCursor: nextCursor);
  }

  @override
  Future<void> saveProduct(Product product) async {
    await addBrand(product.brand);
    await _products
        .doc(product.sku)
        .set(ProductModel.fromEntity(product).toMap());
  }

  @override
  Future<void> deleteProduct(String sku) async {
    await _products.doc(sku).delete();
  }

  @override
  Future<void> updateStock(String sku, int newStock) async {
    await _products.doc(sku).update({'stock': newStock});
  }

  @override
  Future<void> updateExpirationDate(
    String sku,
    DateTime newExpirationDate,
  ) async {
    await _products.doc(sku).update({
      'expirationDate': newExpirationDate.toIso8601String(),
    });
  }
}
