// lib/src/features/orders/pages/order_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:html' as html; // web only
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls; // kasih alias biar ga bentrok Border
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'order_detail_page.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  String searchQuery = '';
  final Map<String, String> _emailCache = {};

  String _formatCurrency(num value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  Future<String> _getUserEmail(String userId) async {
    if (_emailCache.containsKey(userId)) return _emailCache[userId]!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final email = (snap.data()?['email'] ?? '-') as String;
      _emailCache[userId] = email;
      return email;
    } catch (_) {
      _emailCache[userId] = '-';
      return '-';
    }
  }

  // ===================== Export Excel =====================
  Future<void> _exportExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = xls.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    excel.rename(defaultSheet, 'Orders');
    final sheet = excel['Orders'];

    const headers = <String>[
      'Order ID',
      'Customer',
      'Email',
      'Items',
      'Status',
      'Jumlah',
      'Tanggal',
    ];

    // Header
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = xls.TextCellValue(headers[c]);
      cell.cellStyle = xls.CellStyle(
        bold: true,
        horizontalAlign: xls.HorizontalAlign.Center,
        backgroundColorHex: xls.ExcelColor.fromHexString('FFF2F2F2'),
      );
    }

    // Rows
    var r = 1;
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final userName = (data['userName'] ?? '-').toString();
      final userId = (data['userId'] ?? '').toString();
      final email = await _getUserEmail(userId);
      final items = List<Map<String, dynamic>>.from(data['items'] ?? const []);
      final status = (data['status'] ?? '-').toString();
      final gross = (data['grossAmount'] ?? 0) as num;

      DateTime? created;
      final ts = data['createdAt'];
      if (ts is Timestamp) created = ts.toDate();

      final values = <Object?>[
        d.id,
        userName,
        email,
        items.length,
        status,
        _formatCurrency(gross),
        created != null ? DateFormat('dd/MM/yyyy').format(created) : '-',
      ];

      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        final v = values[c];
        if (v is num) {
          cell.value = xls.DoubleCellValue(v.toDouble());
        } else {
          cell.value = xls.TextCellValue(v?.toString() ?? '');
        }
        cell.cellStyle = xls.CellStyle(
          horizontalAlign: c == 0 || c == 2
              ? xls.HorizontalAlign.Left
              : xls.HorizontalAlign.Left,
          verticalAlign: xls.VerticalAlign.Center,
        );
      }
      r++;
    }

    final bytes = excel.encode()!;
    final blob = html.Blob([bytes], 'application/vnd.ms-excel');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'orders_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      )
      ..click();
    a.remove();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File Excel berhasil diunduh')),
    );
    // Catatan: cuma ada 1 sheet "Orders" (sheet default sudah di-rename)
  }

  // ===================== Print (Web) =====================
  Future<void> _printOrders(List<QueryDocumentSnapshot> docs) async {
    final esc = (String v) => v
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final rows = StringBuffer();
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final userName = (data['userName'] ?? '-').toString();
      final userId = (data['userId'] ?? '').toString();
      final email = await _getUserEmail(userId);
      final items = List<Map<String, dynamic>>.from(data['items'] ?? const []);
      final status = (data['status'] ?? '-').toString();
      final gross = (data['grossAmount'] ?? 0) as num;

      DateTime? created;
      final ts = data['createdAt'];
      if (ts is Timestamp) created = ts.toDate();

      rows.writeln(
        '<tr>'
        '<td>${esc(d.id)}</td>'
        '<td>${esc(userName)}</td>'
        '<td>${esc(email)}</td>'
        '<td>${items.length}</td>'
        '<td>${esc(status)}</td>'
        '<td>${esc(_formatCurrency(gross))}</td>'
        '<td>${created != null ? DateFormat('dd/MM/yyyy').format(created) : '-'}</td>'
        '</tr>',
      );
    }

    final htmlContent =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Daftar Pesanan</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;margin:16px}
    h3{margin:0 0 12px 0}
    table{border-collapse:collapse;width:100%}
    th,td{border:1px solid #ddd;padding:8px;font-size:12px}
    th{background:#f2f2f2;text-align:left}
  </style>
</head>
<body onload="window.print();">
  <h3>Daftar Pesanan</h3>
  <table>
    <thead>
      <tr>
        <th>Order ID</th><th>Customer</th><th>Email</th>
        <th>Items</th><th>Status</th><th>Jumlah</th><th>Tanggal</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
</body>
</html>
''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank'); // tab baru isi HTML langsung, auto-print
    // optional: jangan revoke langsung, biar tabnya kebuka penuh
    // Future.delayed(const Duration(seconds: 3), () => html.Url.revokeObjectUrl(url));
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Icon(Icons.list_alt, size: 24, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Daftar Pesanan',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Unduh Excel',
                    icon: const Icon(Icons.download),
                    onPressed: () async {
                      final qs = await FirebaseFirestore.instance
                          .collection('orders')
                          .orderBy('createdAt', descending: true)
                          .get();
                      await _exportExcel(qs.docs);
                    },
                  ),
                  IconButton(
                    tooltip: 'Print',
                    icon: const Icon(Icons.print),
                    onPressed: () async {
                      final qs = await FirebaseFirestore.instance
                          .collection('orders')
                          .orderBy('createdAt', descending: true)
                          .get();
                      await _printOrders(qs.docs);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama / ID pesanan',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Terjadi kesalahan.'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['userName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final id = doc.id.toLowerCase();
                      return name.contains(searchQuery) ||
                          id.contains(searchQuery);
                    }).toList();

                    if (list.isEmpty) {
                      return const Center(child: Text('Tidak ada pesanan.'));
                    }

                    return LayoutBuilder(
                      builder: (context, cons) {
                        final isNarrow = cons.maxWidth < 900;

                        if (!isNarrow) {
                          // ====== TABLE MODE (desktop) ======
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: const [
                                    Expanded(flex: 2, child: Text('Order ID')),
                                    Expanded(flex: 3, child: Text('Customer')),
                                    Expanded(flex: 1, child: Text('Items')),
                                    Expanded(flex: 2, child: Text('Status')),
                                    Expanded(flex: 2, child: Text('Jumlah')),
                                    Expanded(flex: 2, child: Text('Tanggal')),
                                    Expanded(flex: 1, child: Text('Aksi')),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, i) {
                                    final doc = list[i];
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final items =
                                        List<Map<String, dynamic>>.from(
                                          data['items'] ?? const [],
                                        );
                                    final createdAt =
                                        (data['createdAt'] as Timestamp?)
                                            ?.toDate();
                                    final dateStr = createdAt != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(createdAt)
                                        : '-';

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              doc.id,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (data['userName'] ?? '-')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                FutureBuilder<String>(
                                                  future: _getUserEmail(
                                                    (data['userId'] ?? '')
                                                        .toString(),
                                                  ),
                                                  builder: (_, s) => Text(
                                                    s.data ?? '-',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${items.length}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              (data['status'] ?? '-')
                                                  .toString(),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _formatCurrency(
                                                (data['grossAmount'] ?? 0)
                                                    as num,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              dateStr,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  tooltip: 'Detail',
                                                  icon: const Icon(
                                                    Icons.search,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            OrderDetailPage(
                                                              orderId: doc.id,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                IconButton(
                                                  tooltip: 'Hapus',
                                                  icon: const Icon(
                                                    LucideIcons.trash2,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () async {
                                                    final ok =
                                                        await _confirmDelete();
                                                    if (ok) {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('orders')
                                                          .doc(doc.id)
                                                          .delete();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Pesanan berhasil dihapus',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }

                        // ====== CARD MODE (mobile/tablet) ======
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final doc = list[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final items = List<Map<String, dynamic>>.from(
                              data['items'] ?? const [],
                            );
                            final createdAt = (data['createdAt'] as Timestamp?)
                                ?.toDate();
                            final dateStr = createdAt != null
                                ? DateFormat('dd/MM/yyyy').format(createdAt)
                                : '-';

                            return Card(
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            doc.id,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          dateStr,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      (data['userName'] ?? '-').toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    FutureBuilder<String>(
                                      future: _getUserEmail(
                                        (data['userId'] ?? '').toString(),
                                      ),
                                      builder: (_, s) => Text(
                                        s.data ?? '-',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _kv(
                                            'Items',
                                            '${items.length}',
                                          ),
                                        ),
                                        Expanded(
                                          child: _kv(
                                            'Status',
                                            (data['status'] ?? '-').toString(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    _kv(
                                      'Jumlah',
                                      _formatCurrency(
                                        (data['grossAmount'] ?? 0) as num,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => OrderDetailPage(
                                                  orderId: doc.id,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.search,
                                            size: 18,
                                          ),
                                          label: const Text('Detail'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final ok = await _confirmDelete();
                                            if (ok) {
                                              await FirebaseFirestore.instance
                                                  .collection('orders')
                                                  .doc(doc.id)
                                                  .delete();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Pesanan berhasil dihapus',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            LucideIcons.trash2,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            'Hapus',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  Widget _kv(String k, String v) => Row(
    children: [
      Text(
        '$k: ',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      Flexible(child: Text(v, style: const TextStyle(fontSize: 13))),
    ],
  );

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Hapus Pesanan?'),
            content: const Text(
              'Tindakan ini tidak bisa dibatalkan. Lanjutkan?',
            ),
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
}
