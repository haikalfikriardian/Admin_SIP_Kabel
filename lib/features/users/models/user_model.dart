import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? gender;      // "Laki-laki" / "Perempuan" (opsional)
  final String? photoUrl;
  final Timestamp? createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.gender,
    this.photoUrl,
    this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      phone: (d['phone'] ?? '').toString().isEmpty ? null : d['phone'].toString(),
      gender: (d['gender'] ?? '').toString().isEmpty ? null : d['gender'].toString(),
      photoUrl: (d['photoUrl'] ?? '').toString().isEmpty ? null : d['photoUrl'].toString(),
      createdAt: d['createdAt'] is Timestamp ? d['createdAt'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'phone': phone,
    'gender': gender,
    'photoUrl': photoUrl,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
  };
}
