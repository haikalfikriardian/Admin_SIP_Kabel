// lib/features/users/pages/user_list_page.dart
// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../users/models/user_model.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final _firestore = FirebaseFirestore.instance;
  final _searchC = TextEditingController();
  String _q = '';

  // cache alamat {userId: provinsiKota}
  final Map<String, String> _addrCache = {};
  static const String kAddressesCollection = 'addresses';

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      setState(() => _q = _searchC.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus User?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _avatar(AppUser u) {
    if ((u.photoUrl ?? '').isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(u.photoUrl!), radius: 18);
    }
    final initials = (u.name.isNotEmpty
        ? u.name.trim().split(RegExp(r'\s+')).map((e) => e[0]).take(2).join()
        : '?')
        .toUpperCase();
    return CircleAvatar(radius: 18, child: Text(initials));
  }

  /// Ambil alamat utama (provinsiKota) user:
  /// 1) Coba addresses.doc(userId)
  /// 2) Fallback: query where('userId'==userId).limit(1)
  Future<String> _getUserAddress(String userId) async {
    if (_addrCache.containsKey(userId)) return _addrCache[userId]!;
    String result = '—';
    try {
      // 1) Dokumen dengan ID = userId
      final doc = await _firestore.collection(kAddressesCollection).doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final s = (data?['provinsiKota'] ?? data?['alamat'] ?? '').toString().trim();
        if (s.isNotEmpty) {
          result = s;
          _addrCache[userId] = result;
          return result;
        }
      }

      // 2) Fallback query by userId (tanpa orderBy supaya tidak perlu index)
      final q = await _firestore
          .collection(kAddressesCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data() as Map<String, dynamic>;
        final s = (d['provinsiKota'] ?? d['alamat'] ?? '').toString().trim();
        if (s.isNotEmpty) result = s;
      }
    } catch (e) {
      // biarkan result tetap '—'
      // debugPrint('get address error: $e');
    }
    _addrCache[userId] = result;
    return result;
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
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.people_alt, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  const Text('Manajemen User',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final res = await Navigator.pushNamed(context, '/add-user');
                      if (res == 'created') _snack('User berhasil ditambahkan');
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Tambah User', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search
              TextField(
                controller: _searchC,
                decoration: InputDecoration(
                  hintText: 'Cari nama / email / telepon',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(height: 16),

              // List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .orderBy('name') // lebih enak dibaca berurutan
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text('Terjadi kesalahan'));
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final all = snap.data!.docs.map((d) => AppUser.fromDoc(d)).toList();
                    final filtered = all.where((u) {
                      final name = u.name.toLowerCase();
                      final email = u.email.toLowerCase();
                      final phone = (u.phone ?? '').toLowerCase();
                      return name.contains(_q) || email.contains(_q) || phone.contains(_q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('Belum ada user / tidak ditemukan.'));
                    }

                    return LayoutBuilder(builder: (context, c) {
                      final narrow = c.maxWidth < 900;

                      if (narrow) {
                        // Mobile / sempit: Card list
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final u = filtered[i];
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _avatar(u),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(u.name,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w600)),
                                              Text(u.email,
                                                  style: const TextStyle(
                                                      fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    FutureBuilder<String>(
                                      future: _getUserAddress(u.id),
                                      builder: (_, a) => Text(
                                        'Alamat: ${a.data ?? '—'}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Telp: ${u.phone ?? '-'}'),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Edit'),
                                          onPressed: () async {
                                            final res = await Navigator.pushNamed(
                                              context,
                                              '/edit-user',
                                              arguments: u.id,
                                            );
                                            if (res == 'updated') {
                                              _snack('Perubahan user disimpan');
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          label: const Text('Hapus',
                                              style: TextStyle(color: Colors.red)),
                                          onPressed: () async {
                                            final ok = await _confirmDelete();
                                            if (!ok) return;
                                            await _firestore.collection('users').doc(u.id).delete();
                                            _snack('User dihapus');
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }

                      // Desktop: DataTable (User, Email, Telepon, Alamat, Aksi)
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints:
                            BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                            child: DataTable(
                              headingRowColor:
                              MaterialStateProperty.all(Colors.grey.shade200),
                              columnSpacing: 36,
                              columns: const [
                                DataColumn(label: Text('User')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Telepon')),
                                DataColumn(label: Text('Alamat')),
                                DataColumn(label: Text('Aksi')),
                              ],
                              rows: filtered.map((u) {
                                return DataRow(cells: [
                                  DataCell(Row(
                                    children: [
                                      _avatar(u),
                                      const SizedBox(width: 10),
                                      Text(u.name),
                                    ],
                                  )),
                                  DataCell(Text(u.email)),
                                  DataCell(Text(u.phone ?? '-')),
                                  DataCell(
                                    FutureBuilder<String>(
                                      future: _getUserAddress(u.id),
                                      builder: (_, a) => Text(a.data ?? '—'),
                                    ),
                                  ),
                                  DataCell(Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit),
                                        onPressed: () async {
                                          final res = await Navigator.pushNamed(
                                            context,
                                            '/edit-user',
                                            arguments: u.id,
                                          );
                                          if (res == 'updated') {
                                            _snack('Perubahan user disimpan');
                                          }
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Hapus',
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final ok = await _confirmDelete();
                                          if (!ok) return;
                                          await _firestore.collection('users').doc(u.id).delete();
                                          _snack('User dihapus');
                                        },
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    });
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
