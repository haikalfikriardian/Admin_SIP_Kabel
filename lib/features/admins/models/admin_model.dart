import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String id;
  final String name;
  final String email;
  final String role;       // super | manager | staff
  final bool isActive;
  final String? phone;
  final String? password;  // disimpan untuk ditampilkan (bukan buat Auth)
  final DateTime? createdAt;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
    this.password,
    this.createdAt,
  });

  factory AdminModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AdminModel(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      role: (d['role'] ?? 'staff').toString(),
      isActive: (d['isActive'] ?? true) == true,
      phone: (d['phone'] ?? '').toString().isEmpty ? null : d['phone'].toString(),
      password: (d['password'] ?? '').toString().isEmpty ? null : d['password'].toString(),
      createdAt: (d['createdAt'] is Timestamp)
          ? (d['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap({bool forCreate = false}) => {
    'name': name,
    'email': email,
    'role': role,
    'isActive': isActive,
    'phone': phone,
    'password': password,
    if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
  };
}
