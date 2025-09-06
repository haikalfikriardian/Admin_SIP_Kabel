import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../products/models/product_model.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // selection
  Set<String> selectedProductIds = {};

  // search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';
  Timer? _debounce;

  // deleting state
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchTerm = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _fmtCurrency(num n) {
    final s = n.toStringAsFixed(0);
    final rev = s.split('').reversed.toList();
    final parts = <String>[];
    for (int i = 0; i < rev.length; i += 3) {
      parts.add(rev.sublist(i, (i + 3).clamp(0, rev.length)).join());
    }
    final withDots =
    parts.map((e) => e.split('').reversed.join()).toList().reversed.join('.');
    return 'Rp $withDots';
  }

  bool _matchesSearch(ProductModel p, String q) {
    if (q.isEmpty) return true;
    final fields = <String>[
      p.id,
      p.name,
      p.category,
      p.pricePerMeter.toString(),
      p.availableColors.join(','),
      p.availableLengths.map((e) => e.toString()).join(','),
    ].map((e) => e.toLowerCase());

    for (final f in fields) {
      if (f.contains(q)) return true;
    }
    return false;
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
    String confirmLabel = 'Hapus',
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _deleteSelectedProducts() async {
    if (selectedProductIds.isEmpty) return;

    final ok = await _confirmDelete(
      title: 'Hapus Produk Terpilih?',
      message:
      'Yakin ingin menghapus ${selectedProductIds.length} produk? Tindakan ini tidak bisa dibatalkan.',
    );
    if (!ok) return;

    try {
      setState(() => _isDeleting = true);
      final batch = firestore.batch();
      for (final id in selectedProductIds) {
        batch.delete(firestore.collection('products').doc(id));
      }
      await batch.commit();
      final count = selectedProductIds.length;
      setState(() {
        selectedProductIds.clear();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count produk berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.interTextTheme()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F3),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Kembali ke Dashboard',
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Manajemen Produk',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ACTION BAR
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final res =
                        await Navigator.pushNamed(context, '/add-product');
                        if (!mounted) return;
                        if (res == 'saved') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Data berhasil disimpan')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Tambah Produk Baru',
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    if (selectedProductIds.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _isDeleting ? null : _deleteSelectedProducts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: Text(
                          _isDeleting
                              ? 'Menghapus...'
                              : 'Hapus Produk Terpilih (${selectedProductIds.length})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(width: 24),

                    // SEARCH
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText:
                          'Cari produk (nama, kategori, ID, warna, panjang, harga)',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // INFO BAR
                StreamBuilder<QuerySnapshot>(
                  stream: firestore.collection('products').snapshots(),
                  builder: (context, snapshot) {
                    int total = 0, filtered = 0;
                    if (snapshot.hasData) {
                      final products = snapshot.data!.docs
                          .map((doc) => ProductModel.fromMap(
                          doc.data() as Map<String, dynamic>, doc.id))
                          .toList();
                      total = products.length;
                      filtered = products
                          .where((p) => _matchesSearch(p, _searchTerm))
                          .length;
                    }
                    return Text(
                      'Menampilkan $filtered dari $total produk',
                      style:
                      const TextStyle(color: Colors.black54, fontSize: 12),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // TABLE
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                            child: StreamBuilder<QuerySnapshot>(
                              stream: firestore
                                  .collection('products')
                                  .orderBy('name')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const SizedBox(
                                    height: 200,
                                    child:
                                    Center(child: Text('Belum ada produk')),
                                  );
                                }

                                final products = snapshot.data!.docs
                                    .map((doc) => ProductModel.fromMap(
                                    doc.data() as Map<String, dynamic>,
                                    doc.id))
                                    .toList();

                                final filtered = products
                                    .where((p) => _matchesSearch(
                                  p,
                                  _searchTerm,
                                ))
                                    .toList();

                                if (filtered.isEmpty) {
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(
                                        child: Text(
                                            'Tidak ada hasil untuk kata kunci ini')),
                                  );
                                }

                                return DataTable(
                                  headingRowColor:
                                  MaterialStateColor.resolveWith(
                                        (states) => Colors.grey.shade200,
                                  ),
                                  columnSpacing: 24,
                                  columns: const [
                                    DataColumn(label: Text('')),
                                    DataColumn(label: Text('Produk')),
                                    DataColumn(label: Text('Kategori')),
                                    DataColumn(label: Text('Harga')),
                                    DataColumn(label: Text('Dibuat')),
                                    DataColumn(label: Text('Warna')),
                                    DataColumn(label: Text('Edit')),
                                  ],
                                  rows: filtered.map((product) {
                                    final isSelected = selectedProductIds
                                        .contains(product.id);
                                    return DataRow(
                                      selected: isSelected,
                                      cells: [
                                        DataCell(
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  selectedProductIds
                                                      .add(product.id);
                                                } else {
                                                  selectedProductIds
                                                      .remove(product.id);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                BorderRadius.circular(8),
                                                child: product.imageUrl
                                                    .isNotEmpty
                                                    ? Image.network(
                                                  product.imageUrl,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                  const Icon(Icons
                                                      .image_not_supported),
                                                )
                                                    : const Icon(Icons.image,
                                                    size: 40),
                                              ),
                                              const SizedBox(width: 12),
                                              Flexible(
                                                child: Text(
                                                  product.name,
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(product.category)),
                                        DataCell(Text(
                                            '${_fmtCurrency(product.pricePerMeter)}/meter')),
                                        DataCell(Text(product.createdAt != null
                                            ? _formatDate(product.createdAt!)
                                            : '-')),
                                        DataCell(Text(
                                          product.availableColors.isNotEmpty
                                              ? product.availableColors.first
                                              : '-',
                                        )),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    LucideIcons.pencil,
                                                    size: 18),
                                                onPressed: () async {
                                                  final res =
                                                  await Navigator.pushNamed(
                                                    context,
                                                    '/edit-product',
                                                    arguments: product,
                                                  );
                                                  if (!mounted) return;
                                                  if (res == 'updated') {
                                                    ScaffoldMessenger.of(
                                                        context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Data berhasil disimpan')),
                                                    );
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  LucideIcons.trash2,
                                                  size: 18,
                                                  color: Colors.red,
                                                ),
                                                onPressed: _isDeleting
                                                    ? null
                                                    : () async {
                                                  final ok =
                                                  await _confirmDelete(
                                                    title:
                                                    'Hapus Produk?',
                                                    message:
                                                    'Produk "${product.name}" akan dihapus permanen.',
                                                  );
                                                  if (!ok) return;
                                                  try {
                                                    setState(() =>
                                                    _isDeleting =
                                                    true);
                                                    await firestore
                                                        .collection(
                                                        'products')
                                                        .doc(product.id)
                                                        .delete();
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                        context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              'Produk "${product.name}" berhasil dihapus')),
                                                    );
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                        context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              'Gagal menghapus: $e')),
                                                    );
                                                  } finally {
                                                    if (mounted) {
                                                      setState(() =>
                                                      _isDeleting =
                                                      false);
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
