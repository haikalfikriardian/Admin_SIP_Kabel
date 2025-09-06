// lib/features/users/pages/user_form_page.dart
// ignore_for_file: use_build_context_synchronously
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class UserFormPage extends StatefulWidget {
  final bool isEdit;
  final DocumentSnapshot<Map<String, dynamic>>? doc; // diisi saat edit (dokumen dari 'users')

  const UserFormPage({super.key, required this.isEdit, this.doc});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();

  // user fields
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  String _gender = 'Laki-laki';

  // address fields
  final _alamatRingkasC = TextEditingController();
  final _provinsiKotaC = TextEditingController();
  final _jalanC = TextEditingController();
  final _kodePosC = TextEditingController();
  final _teleponAlamatC = TextEditingController();

  // photo
  String? _photoUrl;           // URL dari Storage (kalau ada)
  Uint8List? _previewBytes;    // preview foto baru (kalau user pilih)
  bool _uploadingPhoto = false;

  bool _saving = false;

  String? get _editingUserId => widget.doc?.id;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.doc != null) {
      final d = widget.doc!.data() ?? {};
      _nameC.text  = (d['name']  ?? '').toString();
      _emailC.text = (d['email'] ?? '').toString();
      _phoneC.text = (d['phone'] ?? '').toString();
      _gender      = (d['gender'] ?? 'Laki-laki').toString();
      _photoUrl    = (d['photoUrl'] ?? '').toString();

      _loadAddress(_editingUserId!);
    }
  }

  Future<void> _loadAddress(String userId) async {
    // 1) coba addresses.doc(userId)
    final col = FirebaseFirestore.instance.collection('addresses');
    final doc = await col.doc(userId).get();
    Map<String, dynamic>? data;
    if (doc.exists) {
      data = doc.data();
    } else {
      // 2) fallback where userId == userId
      final q = await col.where('userId', isEqualTo: userId).limit(1).get();
      if (q.docs.isNotEmpty) data = q.docs.first.data();
    }
    if (data != null) {
      _alamatRingkasC.text = (data['alamat'] ?? '').toString();
      _provinsiKotaC.text  = (data['provinsiKota'] ?? '').toString();
      _jalanC.text         = (data['jalan'] ?? '').toString();
      _kodePosC.text       = (data['kodePos'] ?? '').toString();
      _teleponAlamatC.text = (data['telepon'] ?? '').toString();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _alamatRingkasC.dispose();
    _provinsiKotaC.dispose();
    _jalanC.dispose();
    _kodePosC.dispose();
    _teleponAlamatC.dispose();
    super.dispose();
  }

  ImageProvider _avatarImage() {
    if (_previewBytes != null) {
      return MemoryImage(_previewBytes!);
    }
    if ((_photoUrl ?? '').isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return const AssetImage('assets/placeholder_profile.png');
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // supaya dapat bytes di semua platform
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() {
        _previewBytes = bytes;
        _uploadingPhoto = true;
      });

      // path penyimpanan: profile_pictures/<uid-atau-newdoc>.jpg
      // kalau tambah user baru (belum ada id), pakai sementara id random,
      // lalu saat save create lagi (namun supaya sekali upload: lakukan upload saat SAVE)
      // => DI SINI kita upload langsung hanya saat EDIT.
      if (widget.isEdit && _editingUserId != null) {
        final url = await _uploadBytesToStorage(bytes, _editingUserId!);
        setState(() => _photoUrl = url);
      }
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  Future<String> _uploadBytesToStorage(Uint8List bytes, String userId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_pictures')
        .child('$userId.jpg');
    final meta = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, meta);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final usersCol = FirebaseFirestore.instance.collection('users');
    final addrCol  = FirebaseFirestore.instance.collection('addresses');

    try {
      if (widget.isEdit && _editingUserId != null) {
        final userId = _editingUserId!;

        // kalau user sudah pilih foto baru tapi belum upload (karena form EDIT),
        // _photoUrl sudah di-set saat _pickAndUploadPhoto.
        // kalau form TAMBAH, upload dilakukan setelah doc user dibuat di bawah.

        final userPayload = {
          'name': _nameC.text.trim(),
          'email': _emailC.text.trim(),
          'phone': _phoneC.text.trim(),
          'gender': _gender,
          if ((_photoUrl ?? '').isNotEmpty) 'photoUrl': _photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await usersCol.doc(userId).update(userPayload);

        final addrPayload = {
          'alamat': _alamatRingkasC.text.trim(),
          'provinsiKota': _provinsiKotaC.text.trim(),
          'jalan': _jalanC.text.trim(),
          'kodePos': _kodePosC.text.trim(),
          'telepon': _teleponAlamatC.text.trim(),
          'isUtama': true,
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // simpan sebagai doc(userId) supaya konsisten
        await addrCol.doc(userId).set(addrPayload, SetOptions(merge: true));

        Navigator.pop(context, 'updated');
      } else {
        // TAMBAH USER BARU
        // 1) buat dokumen user terlebih dahulu
        final userRef = await usersCol.add({
          'name': _nameC.text.trim(),
          'email': _emailC.text.trim(),
          'phone': _phoneC.text.trim(),
          'gender': _gender,
          // photoUrl diset setelah upload (kalau user pilih foto)
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        String? photoUrl;
        if (_previewBytes != null) {
          photoUrl = await _uploadBytesToStorage(_previewBytes!, userRef.id);
          await userRef.update({'photoUrl': photoUrl});
        }

        // 2) buat dokumen alamat dengan id = userId
        await addrCol.doc(userRef.id).set({
          'alamat': _alamatRingkasC.text.trim(),
          'provinsiKota': _provinsiKotaC.text.trim(),
          'jalan': _jalanC.text.trim(),
          'kodePos': _kodePosC.text.trim(),
          'telepon': _teleponAlamatC.text.trim(),
          'isUtama': true,
          'userId': userRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context, 'created');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(16);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Pengguna' : 'Tambah Pengguna')),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 980;
            final content = [
              // KARTU DATA PENGGUNA
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: cardRadius,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person, size: 18),
                          SizedBox(width: 8),
                          Text('Data Pengguna',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: _avatarImage(),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
                            icon: _uploadingPhoto
                                ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.image),
                            label: const Text('Ubah Foto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _field(
                        label: 'Nama',
                        controller: _nameC,
                        validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Email',
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                          if (!v.contains('@')) return 'Email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Telepon',
                        controller: _phoneC,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        items: const [
                          DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                          DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                        ],
                        onChanged: (v) => setState(() => _gender = v ?? 'Laki-laki'),
                        decoration: InputDecoration(
                          labelText: 'Jenis Kelamin',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16, height: 16),

              // KARTU ALAMAT
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: cardRadius,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.place, size: 18),
                          SizedBox(width: 8),
                          Text('Alamat Utama',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field(label: 'Alamat (ringkas)', controller: _alamatRingkasC),
                      const SizedBox(height: 12),
                      _field(label: 'Provinsi / Kota', controller: _provinsiKotaC),
                      const SizedBox(height: 12),
                      _field(label: 'Jalan', controller: _jalanC),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Kode Pos',
                        controller: _kodePosC,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Telepon (Alamat)',
                        controller: _teleponAlamatC,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: content)
                    else ...content,
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
