// ignore_for_file: use_build_context_synchronously
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../products/models/product_model.dart';

class ProductFormPage extends StatefulWidget {
  final bool isEdit;
  final ProductModel? product;

  const ProductFormPage({super.key, required this.isEdit, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _pricePerMeterController = TextEditingController();
  final _weightPerMeterController = TextEditingController(); // NEW
  final _minLengthController = TextEditingController(text: '100');
  bool _allowCustomLength = false;
  final _descriptionController = TextEditingController();
  final _colorsController = TextEditingController();
  final _lengthsController = TextEditingController();
  final List<String> _categories = ['Tegangan Rendah', 'Audio Video', 'CCTV'];
  String? _selectedCategory;

  String? _imageUrl;
  Uint8List? _webImageBytes;

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.product != null) {
      final p = widget.product!;
      _idController.text = p.id;
      _nameController.text = p.name;
      _selectedCategory = p.category;
      _pricePerMeterController.text = (p.toMap()['pricePerMeter'] ?? '0')
          .toString();
      _weightPerMeterController.text = (p.toMap()['weightPerMeter'] ?? '')
          .toString(); // NEW (prefill)
      _minLengthController.text = (p.toMap()['minLength'] ?? '100').toString();
      _allowCustomLength = p.toMap()['allowCustomLength'] ?? false;
      _imageUrl = p.imageUrl;
      _descriptionController.text = p.description;
      _colorsController.text = p.availableColors.join(', ');
      _lengthsController.text = p.availableLengths.join(', ');
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _pricePerMeterController.dispose();
    _weightPerMeterController.dispose(); // NEW
    _minLengthController.dispose();
    _descriptionController.dispose();
    _colorsController.dispose();
    _lengthsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result != null && result.files.first.bytes != null) {
      final fileBytes = result.files.first.bytes!;
      final fileName = result.files.first.name;
      setState(() => _webImageBytes = fileBytes);
      final ref = _storage.ref().child('products/$fileName');
      await ref.putData(fileBytes);
      final url = await ref.getDownloadURL();
      setState(() => _imageUrl = url);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _idController.text.trim();

    // parse desimal aman (ganti koma jadi titik kalau user pakai koma)
    double _parseDouble(String s) =>
        double.tryParse(s.trim().replaceAll(',', '.')) ?? 0.0;

    final Map<String, dynamic> productMap = {
      'id': id,
      'name': _nameController.text.trim(),
      'category': _selectedCategory!,
      'imageUrl': _imageUrl ?? '',
      'description': _descriptionController.text.trim(),
      'availableColors': _colorsController.text
          .split(',')
          .map((e) => e.trim())
          .toList(),
      'availableLengths': _lengthsController.text
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null)
          .map((e) => e!)
          .toList(),
      'pricePerMeter': int.tryParse(_pricePerMeterController.text.trim()) ?? 0,
      'weightPerMeter': _parseDouble(_weightPerMeterController.text), // NEW
      'minLength': int.tryParse(_minLengthController.text.trim()) ?? 100,
      'allowCustomLength': _allowCustomLength,
    };

    final docRef = _firestore.collection('products').doc(id);

    try {
      if (widget.isEdit) {
        final oldData = (await docRef.get()).data() ?? {};
        await docRef.set({...oldData, ...productMap}, SetOptions(merge: true));
        Navigator.pop(context, 'updated');
      } else {
        final doc = await docRef.get();
        if (doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID produk sudah digunakan')),
          );
          return;
        }
        await docRef.set({
          ...productMap,
          'createdAt': FieldValue.serverTimestamp(),
        });
        Navigator.pop(context, 'saved');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  // ---------- UI Helpers (styling only, logic tetap) ----------
  InputDecoration _outlinedDeco(
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.6,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator ?? (v) => v!.isEmpty ? 'Wajib diisi' : null,
      decoration: _outlinedDeco(context, label: label, hint: hint),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...children.map(
          (w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themed = Theme.of(context).copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      appBarTheme: Theme.of(context).appBarTheme.copyWith(elevation: 0),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Edit Produk' : 'Tambah Produk'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 980),
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KIRI (Informasi & Konfigurasi)
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildSection("Informasi Produk", [
                                if (!widget.isEdit)
                                  _buildTextField(_idController, 'ID Produk'),
                                _buildTextField(_nameController, 'Nama Produk'),
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: _outlinedDeco(
                                    context,
                                    label: 'Kategori',
                                  ),
                                  items: _categories
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedCategory = val),
                                  validator: (val) =>
                                      val == null ? 'Pilih kategori' : null,
                                ),
                                _buildTextField(
                                  _descriptionController,
                                  'Deskripsi Produk',
                                  maxLines: 3,
                                ),
                              ]),
                              const SizedBox(height: 16),
                              _buildSection("Konfigurasi & Manajemen", [
                                _buildTextField(
                                  _pricePerMeterController,
                                  'Harga per Meter',
                                  keyboardType: TextInputType.number,
                                ),
                                // NEW: weight per meter
                                _buildTextField(
                                  _weightPerMeterController,
                                  'Berat per Meter (kg)',
                                  hint: 'Contoh: 0.1216',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Wajib diisi';
                                    }
                                    final v = double.tryParse(
                                      val.trim().replaceAll(',', '.'),
                                    );
                                    if (v == null || v < 0) {
                                      return 'Masukkan angka yang valid';
                                    }
                                    return null;
                                  },
                                ),
                                _buildTextField(
                                  _minLengthController,
                                  'Panjang Minimum (meter)',
                                  keyboardType: TextInputType.number,
                                ),
                                // switch custom length
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text("Boleh Custom Panjang"),
                                  value: _allowCustomLength,
                                  onChanged: (val) => setState(
                                    () => _allowCustomLength = val ?? false,
                                  ),
                                  activeColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  activeTrackColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                ),
                                _buildTextField(
                                  _colorsController,
                                  'Warna Tersedia (pisahkan dengan koma)',
                                  hint: 'Merah, Biru, Hitam',
                                ),
                                _buildTextField(
                                  _lengthsController,
                                  'Panjang Tersedia (pisahkan dengan koma)',
                                  hint: '100, 200, 300',
                                  validator: (value) {
                                    final list = value!
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList();
                                    final allValid = list.every(
                                      (e) => int.tryParse(e) != null,
                                    );
                                    return allValid
                                        ? null
                                        : 'Hanya angka, pisahkan dengan koma';
                                  },
                                ),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // KANAN (Thumbnail)
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildSection("Thumbnail Produk", [
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withOpacity(0.4),
                                    ),
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.04)
                                        : Colors.grey[100],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _imageUrl != null
                                      ? Image.network(
                                          _imageUrl!,
                                          fit: BoxFit.contain,
                                        )
                                      : (_webImageBytes != null
                                            ? Image.memory(
                                                _webImageBytes!,
                                                fit: BoxFit.contain,
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  size: 48,
                                                ),
                                              )),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton(
                                    onPressed: _pickImage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Pilih File'),
                                  ),
                                ),
                                if (_imageUrl != null || _webImageBytes != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _imageUrl != null
                                          ? 'File terpilih: ${Uri.decodeFull(_imageUrl!.split('/').last)}'
                                          : 'File terpilih',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                              ]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Batal'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _saveProduct,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        widget.isEdit
                                            ? 'Simpan Perubahan'
                                            : 'Simpan',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
