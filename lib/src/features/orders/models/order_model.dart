import 'package:cloud_firestore/cloud_firestore.dart';



class OrderModel {
  final String id;
  final String userId;
  final String userName;
  final String address;
  final String status;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.address,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    return OrderModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      address: map['address'] ?? '',
      status: map['status'] ?? 'Menunggu pembayaran',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
