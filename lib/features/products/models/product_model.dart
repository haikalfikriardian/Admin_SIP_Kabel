import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String category;
  final int pricePerMeter; // ✅ Ubah jadi jelas: ini harga per meter
  final String imageUrl;
  final String description;
  final List<String> availableColors;
  final List<int> availableLengths;
  final Timestamp? createdAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePerMeter,
    required this.imageUrl,
    required this.description,
    required this.availableColors,
    required this.availableLengths,
    this.createdAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, String docId) {
    return ProductModel(
      id: docId,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      pricePerMeter: map['pricePerMeter'] is int
          ? map['pricePerMeter']
          : int.tryParse(map['pricePerMeter']?.toString() ?? '0') ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      description: map['description'] ?? '',
      availableColors:
          (map['availableColors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      availableLengths: List<int>.from(map['availableLengths'] ?? []),
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'pricePerMeter': pricePerMeter,
      'imageUrl': imageUrl,
      'description': description,
      'availableColors': availableColors,
      'availableLengths': availableLengths,
      'createdAt': createdAt,
    };
  }
}
