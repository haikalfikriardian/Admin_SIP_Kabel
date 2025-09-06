import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BannerPage extends StatefulWidget {
  const BannerPage({super.key});

  @override
  State<BannerPage> createState() => _BannerPageState();
}

class _BannerPageState extends State<BannerPage> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Banner?'),
        content: const Text('Aksi ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                      const Icon(Icons.image, color: Colors.orange, size: 32),
                      const SizedBox(width: 8),
                      const Text('Daftar Banner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final res = await Navigator.pushNamed(context, '/add-banner');
                      if (res == 'created') _snack('Banner berhasil ditambahkan');
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Tambah Banner Baru', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari Banner',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Table
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('banners').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Terjadi kesalahan'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    final filtered = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final t = (data['title'] ?? '').toString().toLowerCase();
                      final desc = (data['description'] ?? '').toString().toLowerCase();
                      return t.contains(_query) || desc.contains(_query);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('Belum ada banner.'));
                    }

                    return Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                          child: DataTable(
                            columnSpacing: 48,
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text('Banner')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Tanggal Dibuat')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: filtered.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final imageUrl = (data['imageUrl'] ?? '').toString();
                              final title = (data['title'] ?? '').toString();
                              final description = (data['description'] ?? '').toString();
                              final isActive = (data['isActive'] ?? true) == true;
                              final createdAt = data['createdAt'] as Timestamp?;
                              final dateStr =
                              createdAt != null ? DateFormat('dd/MM/yyyy').format(createdAt.toDate()) : '—';

                              return DataRow(cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          imageUrl,
                                          width: 60,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.image),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          if (description.isNotEmpty)
                                            Text(
                                              description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Switch(
                                    value: isActive,
                                    onChanged: (v) {
                                      _firestore.collection('banners').doc(doc.id).update({'isActive': v});
                                    },
                                  ),
                                ),
                                DataCell(Text(dateStr)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(LucideIcons.edit),
                                        onPressed: () async {
                                          final res = await Navigator.pushNamed(
                                            context,
                                            '/edit-banner',
                                            arguments: {'id': doc.id}, // ⬅️ kirim ID simpel & aman
                                          );
                                          if (res == 'updated') _snack('Perubahan banner disimpan');
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Hapus',
                                        icon: const Icon(LucideIcons.trash2, color: Colors.red),
                                        onPressed: () async {
                                          final ok = await _confirmDelete();
                                          if (!ok) return;
                                          await _firestore.collection('banners').doc(doc.id).delete();
                                          _snack('Banner dihapus');
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
