import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> data, String documentId) {
    final ts = data['createdAt'];
    return NotificationModel(
      id: documentId,
      title: (data['title'] ?? '').toString(),
      // kompatibel kalau ada data lama pakai 'body'
      message: (data['message'] ?? data['body'] ?? '').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
