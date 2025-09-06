import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  DocumentSnapshot? orderDoc;
  String? selectedStatus;
  String? pendingStatus;

  final statusList = [
    'Menunggu Pembayaran',
    'Diproses',
    'Dikirim',
    'Selesai',
    'Dibatalkan',
  ];

  @override
  void initState() {
    super.initState();
    fetchOrder();
  }

  Future<void> fetchOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();

    final data = doc.data() as Map<String, dynamic>;
    final currentStatus = data['status'];

    if (!statusList.contains(currentStatus)) {
      statusList.insert(0, currentStatus);
    }

    setState(() {
      orderDoc = doc;
      selectedStatus = currentStatus;
      pendingStatus = currentStatus;
    });
  }

  Future<void> updateStatus(String newStatus) async {
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId);

    await orderRef.update({'status': newStatus});

    // Kirim notifikasi kalau status "Dikirim"
    if (newStatus == 'Dikirim') {
      final orderData = orderDoc!.data() as Map<String, dynamic>;
      final userId = orderData['userId'] ?? '';
      final userName = orderData['userName'] ?? '';

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Pesanan Dikirim',
        'message': 'Pesanan kamu sedang dikirim. Mohon ditunggu ya!',
        'type': 'shipping',
        'userId': userId,
        'userName': userName,
        'orderId': widget.orderId, // ✅ ditambahkan orderId
        'createdAt': Timestamp.now(),
        'readBy': [],
      });
    }

    setState(() {
      selectedStatus = newStatus;
      pendingStatus = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Status pesanan berhasil diperbarui')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (orderDoc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = orderDoc!.data() as Map<String, dynamic>;
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final orderItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final totalPrice = orderItems.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse(item['totalPrice'].toString()) ?? 0),
    );

    final int subtotal = data['subtotal'] ?? totalPrice;
    final int shippingCost = data['shippingCost'] ?? 0;
    final int grossAmount = data['grossAmount'] ?? subtotal + shippingCost;

    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Order [#${widget.orderId}] Details',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT COLUMN
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _whiteBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.info, 'Order Information'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _infoItem('Date:', createdAt.toString()),
                            _infoItem('Items:', '${orderItems.length} Item(s)'),
                            _infoItem('Total:', 'Rp$grossAmount'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _whiteBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.list_alt, 'Order Items'),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: Text('Items')),
                            SizedBox(width: 8),
                            Expanded(child: Text('Price/Meter')),
                            SizedBox(width: 8),
                            Expanded(child: Text('Qty')),
                            SizedBox(width: 8),
                            Expanded(child: Text('Total')),
                          ],
                        ),
                        const Divider(),
                        ...orderItems.map((item) {
                          final int qty = item['quantity'] ?? 0;
                          final int length = item['length'] ?? 0;
                          final int pricePerMeter = item['pricePerMeter'] ?? 0;
                          final int total =
                              item['totalPrice'] ??
                              pricePerMeter * length * qty;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Image.network(
                                        item['imageUrl'],
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item['name'] ?? ''),
                                            Text(
                                              'Qty: $qty • Panjang: $length m',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Rp$pricePerMeter')),
                                const SizedBox(width: 8),
                                Expanded(child: Text('$qty')),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (pricePerMeter * length != 0)
                                        Text('Rp${pricePerMeter * length}'),
                                      Text(
                                        'Total: Rp$total',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Subtotal: Rp$subtotal'),
                              Text('Shipping: Rp$shippingCost'),
                              const SizedBox(height: 4),
                              Text(
                                'Total: Rp$grossAmount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // RIGHT COLUMN
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _whiteBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.sync, 'Update Status'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: pendingStatus,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          items: statusList.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                pendingStatus = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: pendingStatus == selectedStatus
                                ? null
                                : () => updateStatus(pendingStatus!),
                            child: const Text("Update"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _whiteBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.person, 'Customer'),
                        const SizedBox(height: 8),
                        Text(
                          data['userName'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(data['userEmail'] ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _whiteBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.location_on, 'Shipping Address'),
                        const SizedBox(height: 8),
                        Text(
                          data['userName'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(data['userAddress'] ?? '-'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whiteBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: [
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Flexible(child: Text(value, style: GoogleFonts.inter())),
          ],
        ),
      ),
    );
  }
}
