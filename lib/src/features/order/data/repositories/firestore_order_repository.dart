import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../domain/entities/order.dart';
import '../../domain/entities/order_origin.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/order_model.dart';

class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository(this._firestore);

  final fs.FirebaseFirestore _firestore;

  fs.CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  fs.CollectionReference<Map<String, dynamic>> get _origins =>
      _firestore.collection('origins');

  @override
  Future<Order?> findById(String id) async {
    final doc = await _orders.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return OrderModel.fromMap(doc.data()!);
  }

  @override
  Future<List<Order>> listOrders() async {
    final snapshot = await _orders.get();
    return snapshot.docs
        .map((doc) => OrderModel.fromMap(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<OrderOrigin>> listOrigins() async {
    final snapshot = await _origins.get();
    final origins =
        snapshot.docs
            .map((doc) {
              final data = doc.data();
              final name = (data['name'] as String? ?? '').trim();
              final iconUrl = data['iconUrl'] as String?;
              return OrderOrigin(
                name: name,
                iconUrl: iconUrl?.isEmpty == true ? null : iconUrl,
              );
            })
            .where((o) => o.name.isNotEmpty)
            .toList(growable: false)
          ..sort((a, b) => a.name.compareTo(b.name));

    return origins;
  }

  @override
  Future<void> addOrigin(OrderOrigin origin) async {
    final normalized = origin.name.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _origins.doc(normalized).set({
      'name': normalized,
      if (origin.iconUrl != null && origin.iconUrl!.isNotEmpty)
        'iconUrl': origin.iconUrl,
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> saveOrder(Order order) async {
    await addOrigin(
      OrderOrigin(name: order.origin, iconUrl: order.originIconUrl),
    );
    await _orders.doc(order.id).set(OrderModel.fromEntity(order).toMap());
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _orders.doc(id).delete();
  }
}
