import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  final _orders = FirebaseFirestore.instance.collection('orders');

  Stream<List<OrderModel>> getOrders() {
    return _orders.orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs.map((doc) {
          return OrderModel.fromMap(doc.id, doc.data());
        }).toList();
      },
    );
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    await _orders.doc(orderId).update({'status': newStatus});
  }
}
