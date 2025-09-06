import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderDisputeDetailPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDisputeDetailPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  Future<void> _handleDisputeDecision(
    BuildContext context,
    bool approveCancel,
  ) async {
    final newStatus = approveCancel ? 'Dibatalkan' : orderData['status'];

    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {
          'status': newStatus,
          'dispute': false,
          'disputeNote':
              FieldValue.delete(), // ✅ Hapus catatan pembatalan kalau ada
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approveCancel
                  ? '✅ Pesanan berhasil dibatalkan.'
                  : '❌ Pembatalan ditolak.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memproses tindakan')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = orderData['items'] as List<dynamic>? ?? [];
    final createdAt = orderData['createdAt'];
    final timestamp = createdAt is Timestamp ? createdAt.toDate() : null;
    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy – HH:mm').format(timestamp)
        : 'Tanggal tidak tersedia';

    final disputeNote = orderData['disputeNote']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Permintaan Pembatalan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🆔 Order ID: $orderId', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('📅 Tanggal Order: $formattedDate'),
            const SizedBox(height: 8),
            Text('📦 Status Saat Ini: ${orderData['status']}'),
            if (disputeNote != null && disputeNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('📄 Alasan Pembatalan:', style: theme.textTheme.titleSmall),
              Text(disputeNote),
            ],
            const Divider(height: 32),
            Text('🛒 Daftar Produk:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('Tidak ada item dalam pesanan ini.')
            else
              ...items.map((item) {
                final name = item['name'] ?? 'Produk';
                final qty = item['qty'] ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text('Jumlah: $qty'),
                );
              }).toList(),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleDisputeDecision(context, true),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Setujui Pembatalan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleDisputeDecision(context, false),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Tolak Pembatalan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
