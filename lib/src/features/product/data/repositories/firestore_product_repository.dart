import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_cost.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository(this._firestore);

  final FirebaseFirestore _firestore;

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

    await _brands.doc(normalized).set({'name': normalized});
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
    final snapshot = await _brands.get();
    final brands =
        snapshot.docs
            .map((doc) => (doc.data()['name'] as String? ?? '').trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false)
          ..sort();

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
