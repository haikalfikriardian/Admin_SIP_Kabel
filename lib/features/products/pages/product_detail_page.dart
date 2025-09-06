import 'package:flutter/material.dart';
import '../../products/models/product_model.dart';

class ProductDetailPage extends StatelessWidget {
  final ProductModel product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imageUrl.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    product.imageUrl,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 100),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            buildDetailTile('Nama Produk', product.name),
            buildDetailTile('Kategori', product.category),
            buildDetailTile('Harga', 'Rp ${product.pricePerMeter}/meter'),
            buildDetailTile('Deskripsi', product.description),
            buildDetailTile(
              'Warna Tersedia',
              product.availableColors.join(', '),
            ),
            buildDetailTile(
              'Panjang Tersedia',
              product.availableLengths.map((e) => '$e m').join(', '),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDetailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }

  TextStyle get labelStyle => const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 14,
    color: Colors.grey,
  );

  TextStyle get valueStyle =>
      const TextStyle(fontSize: 16, color: Colors.black87);
}
