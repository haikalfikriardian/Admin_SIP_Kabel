// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';

class CatalogListPage extends StatefulWidget {
  const CatalogListPage({super.key});

  @override
  State<CatalogListPage> createState() => _CatalogListPageState();
}

class _CatalogListPageState extends State<CatalogListPage> {
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

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return DateFormat('dd MMM yyyy, HH:mm').format(d);
  }

  Future<void> _goAdd() async {
    final res = await Navigator.pushNamed(context, '/add-catalog');
    if (res == 'created') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Katalog berhasil ditambahkan')),
      );
    }
  }

  Future<void> _goEdit(String id, Map<String, dynamic> data) async {
    final res = await Navigator.pushNamed(
      context,
      '/add-catalog',
      arguments: {'isEdit': true, 'docId': id, 'data': data},
    );
    if (res == 'updated') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan katalog disimpan')),
      );
    }
  }

  Future<void> _deleteCatalog(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Katalog?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('catalogs').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Katalog dihapus')),
      );
    }
  }

  void _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link disalin ke clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daftar Katalog',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _goAdd,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tambah', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari judul / URL katalog…',
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
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('catalogs')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
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
                      final title = (data['title'] ?? '').toString().toLowerCase();
                      final url = (data['url'] ?? '').toString().toLowerCase();
                      return title.contains(_query) || url.contains(_query);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('Belum ada katalog'));
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final table = DataTable(
                          columnSpacing: 32,
                          headingRowHeight: 48,
                          dataRowMinHeight: 60,   // ✅ tambah tinggi minimum
                          dataRowMaxHeight: 72,   // ✅ tambah tinggi maksimum (boleh 76/80 jika masih mepet)
                          headingRowColor: MaterialStatePropertyAll(Colors.grey.shade200),
                          columns: const [
                            DataColumn(label: Text('Katalog')),
                            DataColumn(label: Text('Tanggal')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: filtered.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final title = (data['title'] ?? '-').toString();
                            final url = (data['url'] ?? '').toString();
                            final createdAt = data['createdAt'] as Timestamp?;
                            final dateStr = _fmtDate(createdAt);

                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisSize: MainAxisSize.min, // ✅ hindari extra space vertikal
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,                           // ✅ paksa 1 baris
                                        overflow: TextOverflow.ellipsis,       // ✅ ellipsis
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              url.isEmpty ? '—' : url,
                                              maxLines: 1,                       // ✅ paksa 1 baris
                                              overflow: TextOverflow.ellipsis,   // ✅ ellipsis
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            tooltip: 'Salin URL',
                                            icon: const Icon(LucideIcons.copy),
                                            onPressed: url.isEmpty ? null : () => _copyUrl(url),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(dateStr)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(LucideIcons.pencil),
                                        onPressed: () => _goEdit(doc.id, data),
                                      ),
                                      IconButton(
                                        tooltip: 'Hapus',
                                        icon: const Icon(LucideIcons.trash2, color: Colors.red),
                                        onPressed: () => _deleteCatalog(doc.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        );


                        // Scroll hor & vert agar responsif
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: SingleChildScrollView(child: table),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
