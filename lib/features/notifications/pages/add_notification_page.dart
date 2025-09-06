import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddNotificationPage extends StatefulWidget {
  const AddNotificationPage({super.key});

  @override
  State<AddNotificationPage> createState() => _AddNotificationPageState();
}

class _AddNotificationPageState extends State<AddNotificationPage> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();

  bool isSaving = false;
  bool isEdit = false;
  String? docId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Terima argumen dari list:
    // - bisa Map { isEdit, docId, data(Map) }
    // - atau langsung DocumentSnapshot
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic> && args['isEdit'] == true) {
      isEdit = true;
      docId = args['docId'] as String?;
      final data = args['data'] as Map<String, dynamic>? ?? {};
      titleController.text = (data['title'] ?? '').toString();
      // dukung 'message' / 'body'
      messageController.text = (data['message'] ?? data['body'] ?? '').toString();
    } else if (args is DocumentSnapshot) {
      // kalau ada yang mengirim snapshot langsung
      isEdit = true;
      docId = args.id;
      final data = args.data() as Map<String, dynamic>? ?? {};
      titleController.text = (data['title'] ?? '').toString();
      messageController.text = (data['message'] ?? data['body'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan pesan wajib diisi')),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final col = FirebaseFirestore.instance.collection('notifications');

      if (isEdit && docId != null) {
        // edit: jangan ubah createdAt & readBy biar data tetap konsisten
        await col.doc(docId).update({
          'title': titleController.text.trim(),
          'message': messageController.text.trim(),
        });
        if (!mounted) return;
        Navigator.pop(context, 'updated');
      } else {
        await col.add({
          'title': titleController.text.trim(),
          'message': messageController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': <String>[],
        });
        if (!mounted) return;
        Navigator.pop(context, 'created');
      }
    } catch (e) {
      if (!mounted) return;
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
        title: Text(isEdit ? 'Edit Notifikasi' : 'Tambah Notifikasi'),
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
                    const Text('Form Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Isi Pesan',
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
