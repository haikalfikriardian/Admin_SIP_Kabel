// ignore_for_file: use_build_context_synchronously
import 'dart:html' as html; // web only
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditBannerPage extends StatefulWidget {
  const EditBannerPage({super.key});

  @override
  State<EditBannerPage> createState() => _EditBannerPageState();
}

class _EditBannerPageState extends State<EditBannerPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;

  String? _bannerId;
  String? _imageUrl;
  Uint8List? _imageBytes;
  String? _fileName;
  bool _loading = true;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerId != null) return; // only once

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['id'] is String) {
      _bannerId = args['id'] as String;
    } else if (args is DocumentSnapshot) {
      _bannerId = args.id;
    } else if (args is String) {
      _bannerId = args;
    }

    if (_bannerId == null) {
      setState(() => _loading = false);
      return;
    }

    _fetchAndFill(_bannerId!);
  }

  Future<void> _fetchAndFill(String id) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('banners').doc(id).get();
      final data = snap.data();
      if (data == null) {
        setState(() => _loading = false);
        return;
      }
      _titleController.text = (data['title'] ?? '').toString();
      _descController.text = (data['description'] ?? '').toString();
      final tsStart = data['startDate'];
      final tsEnd = data['endDate'];
      _startDate = tsStart is Timestamp ? tsStart.toDate() : null;
      _endDate = tsEnd is Timestamp ? tsEnd.toDate() : null;
      _imageUrl = (data['imageUrl'] ?? '').toString();
      _isActive = (data['isActive'] ?? true) == true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _pickImage() {
    final input = html.FileUploadInputElement()..accept = 'image/*'..click();
    input.onChange.listen((event) {
      final f = input.files?.first;
      if (f != null) {
        _fileName = f.name;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(f);
        reader.onLoadEnd.listen((e) {
          setState(() => _imageBytes = reader.result as Uint8List);
        });
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _fmt(DateTime? d) => d == null ? 'Pilih Tanggal' : DateFormat('dd/MM/yyyy').format(d);

  Future<void> _save() async {
    if (_bannerId == null) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul wajib diisi')));
      return;
    }

    setState(() => _saving = true);
    try {
      String? imageUrl = _imageUrl;
      if (_imageBytes != null && _fileName != null) {
        final path = 'banners/${DateTime.now().millisecondsSinceEpoch}_$_fileName';
        final ref = FirebaseStorage.instance.ref().child(path);
        await ref.putData(_imageBytes!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('banners').doc(_bannerId!).update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
        'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'imageUrl': imageUrl ?? '',
        'isActive': _isActive,
      });

      Navigator.pop(context, 'updated'); // ⬅️ biar list show snackbar
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_bannerId == null) {
      return const Scaffold(body: Center(child: Text('Banner tidak ditemukan')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Banner'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          Row(
            children: [
              const Text('Aktif'),
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gambar Banner', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : (_imageUrl != null && _imageUrl!.isNotEmpty
                      ? Image.network(_imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))
                      : const Center(child: Icon(Icons.image, size: 60, color: Colors.grey))),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Ganti Gambar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Banner Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text('Start Date: ${_fmt(_startDate)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: false),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('End Date: ${_fmt(_endDate)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
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
