import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
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

  Future<void> _goAdd() async {
    final res = await Navigator.pushNamed(context, '/add-notification');
    if (!mounted) return;
    if (res == 'created') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi berhasil ditambahkan')),
      );
    }
  }

  Future<void> _goEdit(String id, Map<String, dynamic> data) async {
    final res = await Navigator.pushNamed(
      context,
      '/add-notification',
      arguments: {
        'isEdit': true,
        'docId': id,
        'data': data,
      },
    );
    if (!mounted) return;
    if (res == 'updated') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan notifikasi disimpan')),
      );
    }
  }

  Future<void> _delete(BuildContext context, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Notifikasi?'),
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
      await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi dihapus')),
      );
    }
  }

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return DateFormat('dd MMM yyyy, HH:mm').format(d);
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
        title: const Text('Notifikasi', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        actions: [
          const SizedBox(width: 8),
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
            // Pencarian
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari judul / isi notifikasi…',
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

            // Tabel
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
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
                      final msg = (data['message'] ?? data['body'] ?? '').toString().toLowerCase();
                      return title.contains(_query) || msg.contains(_query);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('Belum ada notifikasi'));
                    }

                    // Scroll horizontal & vertical supaya responsif
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final table = DataTable(
                          columnSpacing: 32,
                          headingRowColor: MaterialStatePropertyAll(Colors.grey.shade200),
                          columns: const [
                            DataColumn(label: Text('Notifikasi')),
                            DataColumn(label: Text('Tanggal')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: filtered.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final createdAt = data['createdAt'] as Timestamp?;
                            final dateStr = _fmtDate(createdAt);

                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        (data['title'] ?? '-').toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (data['message'] ?? data['body'] ?? '-').toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
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
                                        onPressed: () => _delete(context, doc.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        );

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: SingleChildScrollView(
                              child: table,
                            ),
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
