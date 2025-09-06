// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddCatalogPage extends StatefulWidget {
  const AddCatalogPage({super.key});

  @override
  State<AddCatalogPage> createState() => _AddCatalogPageState();
}

class _AddCatalogPageState extends State<AddCatalogPage> {
  final titleController = TextEditingController();
  final urlController = TextEditingController();

  bool isSaving = false;
  bool isEdit = false;
  String? docId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dukung dua pola argumen:
    // - Map { isEdit, docId, data }
    // - DocumentSnapshot (kalau suatu saat dipakai)
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic> && args['isEdit'] == true) {
      isEdit = true;
      docId = args['docId'] as String?;
      final data = args['data'] as Map<String, dynamic>? ?? {};
      titleController.text = (data['title'] ?? '').toString();
      urlController.text = (data['url'] ?? '').toString();
    } else if (args is DocumentSnapshot) {
      isEdit = true;
      docId = args.id;
      final data = args.data() as Map<String, dynamic>? ?? {};
      titleController.text = (data['title'] ?? '').toString();
      urlController.text = (data['url'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String v) {
    final s = v.trim().toLowerCase();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  Future<void> _save() async {
    final title = titleController.text.trim();
    final url = urlController.text.trim();

    if (title.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan URL wajib diisi')),
      );
      return;
    }
    if (!_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL harus diawali http:// atau https://')),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final col = FirebaseFirestore.instance.collection('catalogs');

      if (isEdit && docId != null) {
        await col.doc(docId).update({
          'title': title,
          'url': url,
        });
        Navigator.pop(context, 'updated');
      } else {
        await col.add({
          'title': title,
          'url': url,
          'createdAt': FieldValue.serverTimestamp(),
        });
        Navigator.pop(context, 'created');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Katalog' : 'Tambah Katalog'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Form Katalog',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Katalog',
                        hintText: 'Mis. Katalog Kabel Edisi Agustus',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: 'Link URL Katalog',
                        hintText: 'https://…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _save,
                        icon: isSaving
                            ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.save),
                        label: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
