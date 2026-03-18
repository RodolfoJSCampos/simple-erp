import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../domain/entities/order.dart';
import '../../domain/entities/order_page.dart';
import '../../domain/entities/order_origin.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/order_model.dart';

class FirestoreOrderRepository implements OrderRepository {
  static const String _cursorSeparator = '|';

  FirestoreOrderRepository(this._firestore);

  final fs.FirebaseFirestore _firestore;
  static const Duration _cacheTtl = Duration(minutes: 5);
  final Map<String, OrderOrigin> _originCache = <String, OrderOrigin>{};
  DateTime? _originCacheAt;

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
  Future<OrderPage> listOrdersPage({
    required int limit,
    String? afterCursor,
  }) async {
    var query = _orders
        .orderBy('registeredAt', descending: true)
        .orderBy(fs.FieldPath.documentId, descending: true)
        .limit(limit);

    if (afterCursor != null && afterCursor.isNotEmpty) {
      final cursorParts = afterCursor.split(_cursorSeparator);
      if (cursorParts.length == 2) {
        query = query.startAfter([cursorParts[0], cursorParts[1]]);
      }
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => OrderModel.fromMap(doc.data()))
        .toList(growable: false);

    String? nextCursor;
    if (snapshot.docs.length == limit && snapshot.docs.isNotEmpty) {
      final lastDoc = snapshot.docs.last;
      final registeredAt = (lastDoc.data()['registeredAt'] as String?) ?? '';
      nextCursor = '$registeredAt$_cursorSeparator${lastDoc.id}';
    }

    return OrderPage(items: items, nextCursor: nextCursor);
  }

  @override
  Future<List<OrderOrigin>> listOrigins() async {
    final now = DateTime.now();
    final hasFreshCache =
        _originCacheAt != null && now.difference(_originCacheAt!) <= _cacheTtl;
    if (_originCache.isNotEmpty && hasFreshCache) {
      final cached = _originCache.values.toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));
      return cached;
    }

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

    _originCache
      ..clear()
      ..addEntries(origins.map((o) => MapEntry(o.name, o)));
    _originCacheAt = now;

    return origins;
  }

  @override
  Future<void> addOrigin(OrderOrigin origin) async {
    final normalized = origin.name.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (_originCache.containsKey(normalized)) {
      return;
    }

    await _origins.doc(normalized).set({
      'name': normalized,
      if (origin.iconUrl != null && origin.iconUrl!.isNotEmpty)
        'iconUrl': origin.iconUrl,
    }, fs.SetOptions(merge: true));

    _originCache[normalized] = OrderOrigin(
      name: normalized,
      iconUrl: origin.iconUrl?.isEmpty == true ? null : origin.iconUrl,
    );
    _originCacheAt = DateTime.now();
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
