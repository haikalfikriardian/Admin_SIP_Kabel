import 'package:flutter/material.dart';
import '../models/order_model.dart';

class OrderTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onProcess;

  const OrderTile({super.key, required this.order, this.onProcess});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(order.userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alamat: ${order.address}'),
            Text('Status: ${order.status}'),
            Text('Tanggal: ${order.createdAt}'),
          ],
        ),
        trailing: order.status == 'Menunggu pembayaran'
            ? ElevatedButton(
                onPressed: onProcess,
                child: const Text('Proses'),
              )
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
