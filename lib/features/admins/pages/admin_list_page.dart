import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/admin_model.dart';

class AdminListPage extends StatefulWidget {
  const AdminListPage({super.key});

  @override
  State<AdminListPage> createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  final _firestore = FirebaseFirestore.instance;
  final _searchC = TextEditingController();
  String _query = '';

  String _meRole = 'staff';
  String? _meId;

  // track baris yang password-nya ditampilkan
  final Set<String> _reveal = {};

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      setState(() => _query = _searchC.text.trim().toLowerCase());
    });
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _meId = uid;
    if (uid == null) return;
    final snap = await _firestore.collection('admins').doc(uid).get();
    if (mounted) {
      setState(() {
        _meRole = (snap.data()?['role'] ?? 'staff').toString();
      });
    }
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
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Admin?'),
        content: const Text('Aksi ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ??
        false;
  }

  // ---- RULES helpers ----
  bool _canAdd() {
    if (_meRole == 'super') return true;
    if (_meRole == 'manager') return true; // tambah staff
    return false;
  }

  bool _canDelete(AdminModel target) {
    if (_meRole == 'super') return true;
    if (_meRole == 'manager') return target.role == 'staff';
    return false; // staff tidak boleh hapus
  }

  bool _canEdit(AdminModel target) {
    if (_meRole == 'super') return true;
    if (_meRole == 'manager') {
      if (target.id == _meId) return true; // diri sendiri
      return target.role == 'staff';
    }
    // staff
    return target.id == _meId;
  }

  bool _canToggleActive(AdminModel target) {
    if (_meRole == 'super') return true;
    if (_meRole == 'manager') return target.role == 'staff';
    return false;
  }

  // HAK LIHAT PASSWORD
  bool _canRevealPassword(AdminModel target) {
    if (_meRole == 'super') return true;                       // semua
    if (_meRole == 'manager') {
      return target.id == _meId || target.role == 'staff';     // diri sendiri + staff
    }
    return target.id == _meId;                                  // staff: diri sendiri
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _canAdd();

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
                  const Icon(Icons.verified_user, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  const Text('Daftar Admin',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (canAdd)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final res = await Navigator.pushNamed(context, '/add-admin');
                        if (res == 'created') _snack('Admin berhasil ditambahkan');
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label:
                      const Text('Tambah Admin', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Search
              TextField(
                controller: _searchC,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email',
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('admins')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text('Terjadi kesalahan'));
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    final items = docs
                        .map((d) => AdminModel.fromDoc(d))
                        .where((m) =>
                    m.name.toLowerCase().contains(_query) ||
                        m.email.toLowerCase().contains(_query))
                        .toList();

                    if (items.isEmpty) {
                      return const Center(child: Text('Belum ada admin.'));
                    }

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
                            columnSpacing: 28,
                            headingRowColor:
                            MaterialStateProperty.all(Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text('Nama')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Password')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: items.map((m) {
                              final canEdit = _canEdit(m);
                              final canDelete = _canDelete(m);
                              final canToggle = _canToggleActive(m);
                              final canReveal = _canRevealPassword(m);
                              final isRevealed = _reveal.contains(m.id);
                              final hasPassword = (m.password ?? '').isNotEmpty;

                              return DataRow(cells: [
                                DataCell(Text(m.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(m.email)),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: m.role == 'super'
                                        ? Colors.purple.shade50
                                        : (m.role == 'manager'
                                        ? Colors.blue.shade50
                                        : Colors.green.shade50),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    m.role.toUpperCase(),
                                    style: TextStyle(
                                      color: m.role == 'super'
                                          ? Colors.purple
                                          : (m.role == 'manager'
                                          ? Colors.blue
                                          : Colors.green),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )),
                                // Password + eye per row (sesuai rules)
                                DataCell(Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        (canReveal && isRevealed)
                                            ? (m.password ?? '—')
                                            : (hasPassword ? '••••••' : '—'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: canReveal
                                          ? (isRevealed ? 'Sembunyikan' : 'Lihat')
                                          : 'Tidak boleh lihat',
                                      icon: Icon(
                                        (canReveal && isRevealed)
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: (canReveal && hasPassword)
                                          ? () {
                                        setState(() {
                                          if (isRevealed) {
                                            _reveal.remove(m.id);
                                          } else {
                                            _reveal.add(m.id);
                                          }
                                        });
                                      }
                                          : null,
                                    ),
                                  ],
                                )),
                                DataCell(
                                  canToggle
                                      ? Switch(
                                    value: m.isActive,
                                    onChanged: (v) async {
                                      await _firestore
                                          .collection('admins')
                                          .doc(m.id)
                                          .update({'isActive': v});
                                    },
                                  )
                                      : Text(m.isActive ? 'Aktif' : 'Nonaktif'),
                                ),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      tooltip: canEdit ? 'Edit' : 'Tidak boleh edit',
                                      icon: const Icon(Icons.edit),
                                      onPressed: canEdit
                                          ? () async {
                                        final res = await Navigator.pushNamed(
                                          context,
                                          '/edit-admin',
                                          arguments: docs.firstWhere((d) => d.id == m.id),
                                        );
                                        if (res == 'updated') {
                                          _snack('Perubahan admin disimpan');
                                        }
                                      }
                                          : null,
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip: canDelete ? 'Hapus' : 'Tidak boleh hapus',
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: canDelete
                                          ? () async {
                                        final ok = await _confirmDelete();
                                        if (!ok) return;
                                        await _firestore
                                            .collection('admins')
                                            .doc(m.id)
                                            .delete();
                                        _snack('Admin dihapus');
                                      }
                                          : null,
                                    ),
                                  ],
                                )),
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
