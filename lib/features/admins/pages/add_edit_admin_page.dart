// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddEditAdminPage extends StatefulWidget {
  const AddEditAdminPage({super.key});

  @override
  State<AddEditAdminPage> createState() => _AddEditAdminPageState();
}

class _AddEditAdminPageState extends State<AddEditAdminPage> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _passwordC = TextEditingController();

  String _role = 'staff'; // super | manager | staff
  bool _isActive = true;
  bool _isSaving = false;
  bool _obscure = true;

  DocumentSnapshot? _doc; // jika edit

  String _meRole = 'staff';
  String? _meId;
  bool _meReady = false;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _meId = uid;
    if (uid != null) {
      final me = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      _meRole = (me.data()?['role'] ?? 'staff').toString();
    }
    setState(() {
      _meReady = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_doc == null && args is DocumentSnapshot) {
      _doc = args;
      final d = _doc!.data() as Map<String, dynamic>? ?? {};
      _nameC.text = (d['name'] ?? '').toString();
      _emailC.text = (d['email'] ?? '').toString();
      _phoneC.text = (d['phone'] ?? '').toString();
      _passwordC.text = (d['password'] ?? '').toString();
      _role = (d['role'] ?? 'staff').toString();
      _isActive = (d['isActive'] ?? true) == true;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  List<String> _allowedRoles() {
    final isEdit = _doc != null;
    final targetRole = isEdit
        ? (((_doc!.data() as Map?)?['role'] ?? 'staff').toString())
        : 'staff';
    final targetId = isEdit ? _doc!.id : null;

    if (_meRole == 'super') {
      return const ['super', 'manager', 'staff'];
    }

    if (_meRole == 'manager') {
      if (!isEdit) {
        // tambah → hanya staff
        return const ['staff'];
      }
      if (targetId == _meId) {
        // edit diri sendiri → tetap manager
        return const ['manager'];
      }
      if (targetRole == 'staff') {
        // boleh atur staff (manager <-> staff), tidak bisa super
        return const ['manager', 'staff'];
      }
      // manager tidak boleh edit manager lain / super
      return const <String>[];
    }

    // staff
    if (!isEdit) return const <String>[]; // staff tak boleh add
    if (targetId == _meId) return const ['staff']; // edit diri sendiri
    return const <String>[]; // selain itu tidak boleh
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty || _emailC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nama & email wajib diisi')));
      return;
    }

    final allowed = _allowedRoles();
    if (allowed.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Anda tidak punya akses')));
      Navigator.pop(context);
      return;
    }
    // pastikan role yang disimpan valid
    final roleToSave = allowed.contains(_role) ? _role : allowed.first;

    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _nameC.text.trim(),
        'email': _emailC.text.trim(),
        'phone': _phoneC.text.trim(),
        'password': _passwordC.text.trim(), // UI only
        'role': roleToSave,
        'isActive': _isActive,
      };

      if (_doc == null) {
        await FirebaseFirestore.instance.collection('admins').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        Navigator.pop(context, 'created');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Admin berhasil ditambahkan')));
      } else {
        await FirebaseFirestore.instance.collection('admins').doc(_doc!.id).update(data);
        Navigator.pop(context, 'updated');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Perubahan admin disimpan')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // tunggu data role login tersedia
    if (!_meReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Kalau route sedang mengirim argumen (edit) tapi _doc belum terisi → tahan build
    final hasArgs = ModalRoute.of(context)?.settings.arguments is DocumentSnapshot;
    if (hasArgs && _doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isEdit = _doc != null;
    final allowed = _allowedRoles();

    // Tidak punya akses (mis. manager edit manager lain / super)
    if (isEdit && allowed.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anda tidak punya akses untuk mengedit ini')),
          );
        }
      });
      return const SizedBox.shrink();
    }

    // Hitung nilai aman untuk dropdown TANPA mengubah state saat build
    final String? dropdownValue =
    allowed.isEmpty ? null : (allowed.contains(_role) ? _role : allowed.first);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Admin' : 'Tambah Admin'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // switch aktif: super semua; manager hanya target staff; staff tidak
          Builder(
            builder: (_) {
              bool canToggle = false;
              if (isEdit) {
                final targetRole =
                (((_doc!.data() as Map?)?['role'] ?? 'staff').toString());
                if (_meRole == 'super') {
                  canToggle = true;
                } else if (_meRole == 'manager') {
                  canToggle = targetRole == 'staff';
                }
              } else {
                canToggle = _meRole == 'super' || _meRole == 'manager';
              }
              return canToggle
                  ? Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              )
                  : Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: Text(_isActive ? 'Aktif' : 'Nonaktif')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama
                TextField(
                  controller: _nameC,
                  decoration: InputDecoration(
                    labelText: 'Nama',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Email
                TextField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Phone
                TextField(
                  controller: _phoneC,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'No. HP',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Password (UI only)
                TextField(
                  controller: _passwordC,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Role dropdown
                DropdownButtonFormField<String>(
                  value: dropdownValue,
                  items: allowed
                      .toSet()
                      .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.toUpperCase()),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _role = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 20),

                // Save
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.save),
                    label: Text(_isSaving
                        ? 'Menyimpan...'
                        : (isEdit ? 'Simpan Perubahan' : 'Simpan')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
