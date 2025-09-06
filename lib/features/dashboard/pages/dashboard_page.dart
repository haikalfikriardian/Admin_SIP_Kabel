// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

/// Field tanggal yang dipakai untuk hitung sales
const String kDateFieldForSales = 'createdAt';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  // ====== MENU (SIDEBAR) ======
  final List<String> menuTitles = const [
    'Dashboard',
    'Produk',
    'Banner',
    'Pesanan',
    'Pembatalan',
    'Notifikasi',
    'Pengguna', // ⬅️ baru
    'Admin', // ⬅️ baru
    'Katalog',
  ];
  final List<IconData> menuIcons = const [
    Icons.dashboard,
    Icons.inventory,
    Icons.image,
    Icons.shopping_cart,
    Icons.cancel,
    Icons.notifications,
    Icons.group, // ⬅️ Pengguna
    Icons.verified_user, // ⬅️ Admin
    Icons.picture_as_pdf,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser == null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    });
  }

  // ===================== UTIL =====================
  double _calcOrderTotal(Map<String, dynamic> data) {
    final gross = data['grossAmount'];
    if (gross is num) return gross.toDouble();

    final subtotal = data['subtotal'];
    final shipping = data['shippingCost'];
    if (subtotal is num && shipping is num) {
      return (subtotal + shipping).toDouble();
    }

    double sum = 0.0;
    final items = (data['items'] as List?) ?? [];
    for (final raw in items) {
      final item = (raw as Map?)?.cast<String, dynamic>() ?? {};
      final tp = item['totalPrice'];
      if (tp is num) {
        sum += tp.toDouble();
      } else {
        final pricePerMeter = item['pricePerMeter'];
        final qty = item['quantity'];
        if (pricePerMeter is num && qty is num) {
          sum += (pricePerMeter * qty).toDouble();
        }
      }
    }
    if (sum > 0) return sum;

    final top = data['totalPrice'];
    if (top is num) return top.toDouble();

    return 0.0;
  }

  Timestamp? _tsForSales(Map<String, dynamic> data) {
    final v = data[kDateFieldForSales] ?? data['createdAt'];
    return v is Timestamp ? v : null;
  }

  bool _isOmzet(Map<String, dynamic> d) {
    final st = (d['status'] ?? '').toString();
    return ['Selesai', 'Delivered', 'Paid', 'Diproses', 'Dikirim'].contains(st);
  }

  String _fmtCurrency(num n) {
    final s = n.toStringAsFixed(0);
    final rev = s.split('').reversed.toList();
    final parts = <String>[];
    for (int i = 0; i < rev.length; i += 3) {
      parts.add(rev.sublist(i, (i + 3).clamp(0, rev.length)).join());
    }
    final withDots = parts
        .map((e) => e.split('').reversed.join())
        .toList()
        .reversed
        .join('.');
    return 'Rp $withDots';
  }

  int _weeksInMonth(DateTime d) {
    final first = DateTime(d.year, d.month, 1);
    final next = d.month == 12
        ? DateTime(d.year + 1, 1, 1)
        : DateTime(d.year, d.month + 1, 1);
    final days = next.difference(first).inDays;
    return days > 28 ? 5 : 4;
  }

  String _monthName(int m) {
    const n = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return n[m];
  }

  // ===================== STREAM: METRICS =====================
  Stream<double> salesThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final next = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    return FirebaseFirestore.instance
        .collection('orders')
        .where(
          kDateFieldForSales,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(kDateFieldForSales, isLessThan: Timestamp.fromDate(next))
        .snapshots()
        .map((s) {
          double sum = 0;
          for (final d in s.docs) {
            final data = d.data() as Map<String, dynamic>;
            if (!_isOmzet(data)) continue;
            sum += _calcOrderTotal(data);
          }
          return sum;
        });
  }

  Stream<double> salesLast7Days() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    return FirebaseFirestore.instance
        .collection('orders')
        .where(
          kDateFieldForSales,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .snapshots()
        .map((s) {
          double sum = 0;
          for (final d in s.docs) {
            final data = d.data() as Map<String, dynamic>;
            if (!_isOmzet(data)) continue;
            sum += _calcOrderTotal(data);
          }
          return sum;
        });
  }

  Stream<double> salesAllTime() {
    return FirebaseFirestore.instance.collection('orders').snapshots().map((s) {
      double sum = 0;
      for (final d in s.docs) {
        final data = d.data() as Map<String, dynamic>;
        if (!_isOmzet(data)) continue;
        sum += _calcOrderTotal(data);
      }
      return sum;
    });
  }

  Stream<double> averageOrderValue() async* {
    await for (final snap
        in FirebaseFirestore.instance.collection('orders').snapshots()) {
      double sum = 0;
      int count = 0;
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        if (!_isOmzet(data)) continue;
        sum += _calcOrderTotal(data);
        count++;
      }
      yield count == 0 ? 0.0 : (sum / count);
    }
  }

  Stream<int> totalOrders() => FirebaseFirestore.instance
      .collection('orders')
      .snapshots()
      .map((s) => s.docs.length);

  Stream<int> visitors() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<double> pendingPaymentsTotal() {
    return FirebaseFirestore.instance.collection('orders').snapshots().map((s) {
      double sum = 0;
      for (final d in s.docs) {
        final data = d.data() as Map<String, dynamic>;
        final st = (data['status'] ?? '').toString();
        if (st != 'Menunggu Pembayaran') continue;
        sum += _calcOrderTotal(data);
      }
      return sum;
    });
  }

  // ===================== STREAM: CHARTS =====================
  Stream<Map<int, double>> weeklySalesThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final next = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    return FirebaseFirestore.instance
        .collection('orders')
        .where(
          kDateFieldForSales,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(kDateFieldForSales, isLessThan: Timestamp.fromDate(next))
        .snapshots()
        .map((snap) {
          final maxW = _weeksInMonth(now);
          final Map<int, double> m = {for (var i = 1; i <= maxW; i++) i: 0.0};
          for (final doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (!_isOmzet(data)) continue;
            final ts = _tsForSales(data);
            if (ts == null) continue;
            final day = ts.toDate().day;
            final week = ((day - 1) ~/ 7) + 1; // 1..5
            if (week >= 1 && week <= maxW) {
              m[week] = (m[week] ?? 0) + _calcOrderTotal(data);
            }
          }
          return m;
        });
  }

  Stream<Map<int, double>> dailySalesThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final next = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final days = next.difference(start).inDays;

    return FirebaseFirestore.instance
        .collection('orders')
        .where(
          kDateFieldForSales,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(kDateFieldForSales, isLessThan: Timestamp.fromDate(next))
        .snapshots()
        .map((snapshot) {
          final Map<int, double> m = {for (var d = 1; d <= days; d++) d: 0.0};
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (!_isOmzet(data)) continue;
            final ts = _tsForSales(data);
            if (ts == null) continue;
            final total = _calcOrderTotal(data);
            final day = ts.toDate().day;
            m[day] = (m[day] ?? 0) + total;
          }
          return m;
        });
  }

  Stream<List<_MonthPoint>> monthlySalesAllTime() {
    return FirebaseFirestore.instance.collection('orders').snapshots().map((
      snapshot,
    ) {
      final map = <String, double>{}; // 'YYYY-MM' -> total
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!_isOmzet(data)) continue;
        final ts = _tsForSales(data);
        if (ts == null) continue;
        final d = ts.toDate();
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        map[key] = (map[key] ?? 0) + _calcOrderTotal(data);
      }
      final keys = map.keys.toList()..sort();
      final picked = keys.length > 12 ? keys.sublist(keys.length - 12) : keys;
      return picked.map((k) {
        final parts = k.split('-');
        final y = int.parse(parts[0]), m = int.parse(parts[1]);
        return _MonthPoint(DateTime(y, m, 1), map[k] ?? 0);
      }).toList();
    });
  }

  // ===================== UI – SIDEBAR =====================
  Widget buildSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFFFF6B00),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Image.asset('assets/logo.png', height: 90),
          const SizedBox(height: 40),
          ...List.generate(menuTitles.length, (index) {
            return ListTile(
              leading: Icon(menuIcons[index], color: Colors.white),
              title: Text(
                menuTitles[index],
                style: const TextStyle(color: Colors.white),
              ),
              selected: _selectedIndex == index,
              selectedTileColor: Colors.white24,
              onTap: () {
                final m = menuTitles[index];
                if (m == 'Produk') {
                  Navigator.pushNamed(context, '/products');
                } else if (m == 'Banner') {
                  Navigator.pushNamed(context, '/banners');
                } else if (m == 'Pesanan') {
                  Navigator.pushNamed(context, '/orders');
                } else if (m == 'Notifikasi') {
                  Navigator.pushNamed(context, '/admin-notifications');
                } else if (m == 'Pengguna') {
                  // ⬅️ route users
                  Navigator.pushNamed(context, '/users');
                } else if (m == 'Admin') {
                  // ⬅️ route admins
                  Navigator.pushNamed(context, '/admins');
                } else if (m == 'Katalog') {
                  Navigator.pushNamed(context, '/admin-catalogs');
                } else if (m == 'Pembatalan') {
                  Navigator.pushNamed(context, '/order-disputes');
                } else {
                  setState(() => _selectedIndex = index);
                }
              },
            );
          }),
          const Spacer(),
          const Divider(color: Colors.white70),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  // ===================== HEADER =====================
  Widget buildHeader() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        color: Colors.white,
        child: const Row(
          children: [
            Icon(Icons.dashboard, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Spacer(),
          ],
        ),
      );
    }

    final ref = FirebaseFirestore.instance.collection('admins').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final email = FirebaseAuth.instance.currentUser?.email ?? '-';
        final data = snap.data?.data() ?? {};
        final name = (data['name'] ?? 'Admin').toString();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.dashboard, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),

              // Nama + Email (klik untuk ke halaman profil)
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    const CircleAvatar(child: Icon(Icons.person)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================== BUILDING BLOCKS =====================
  Widget _metricCard({
    required String title,
    required Widget value,
    Widget? sub,
    IconData? leadingIcon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcon != null)
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFF3F6FF),
              ),
              child: Icon(leadingIcon),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  child: value,
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                    child: sub,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required double height,
    required Widget child,
  }) {
    final r = BorderRadius.circular(16);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: r,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== CHART WIDGETS =====================
  Widget weeklySalesCard() {
    return _chartCard(
      title: 'Weekly Sales (This Month)',
      height: 320,
      child: StreamBuilder<Map<int, double>>(
        stream: weeklySalesThisMonth(),
        builder: (context, snapshot) {
          final map =
              snapshot.data ??
              {for (var i = 1; i <= _weeksInMonth(DateTime.now()); i++) i: 0.0};
          final weeks = map.keys.toList()..sort();
          final maxY =
              (map.values.isEmpty
                  ? 0.0
                  : map.values.reduce((a, b) => a > b ? a : b)) *
              1.25;

          return BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY == 0 ? 100 : maxY,
              barGroups: weeks
                  .map(
                    (w) => BarChartGroupData(
                      x: w,
                      barRods: [
                        BarChartRodData(
                          toY: map[w] ?? 0,
                          width: 22,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  )
                  .toList(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) =>
                    FlLine(strokeWidth: 1, dashArray: const [5, 5]),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'W${value.toInt()}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (v, _) {
                      if (v == 0) return const Text('0');
                      if (v >= 1000000) {
                        final jt = v / 1000000;
                        return Text(
                          jt % 1 == 0
                              ? '${jt.toStringAsFixed(0)} jt'
                              : '${jt.toStringAsFixed(1)} jt',
                        );
                      }
                      return Text(v.toStringAsFixed(0));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          );
        },
      ),
    );
  }

  Widget orderStatusPieCard() {
    return _chartCard(
      title: 'Orders Status',
      height: 360,
      child: StreamBuilder<Map<String, int>>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots().map(
          (s) {
            final Map<String, int> m = {};
            for (final d in s.docs) {
              final st = ((d.data() as Map<String, dynamic>)['status'] ?? '')
                  .toString();
              if (st.isEmpty) continue;
              m[st] = (m[st] ?? 0) + 1;
            }
            m.removeWhere((k, v) => v == 0);
            return m;
          },
        ),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          if (data.isEmpty) return const Center(child: Text('Belum ada data'));

          final total = data.values.fold<int>(0, (a, b) => a + b);
          final keys = data.keys.toList();

          final chart = PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: List.generate(keys.length, (i) {
                final key = keys[i];
                final value = data[key]!;
                final pct = total == 0 ? 0.0 : value / total;
                return PieChartSectionData(
                  value: value.toDouble(),
                  title: '${(pct * 100).toStringAsFixed(0)}%',
                  radius: 70,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  color: Colors.primaries[i % Colors.primaries.length],
                );
              }),
            ),
          );

          final legend = Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: List.generate(keys.length, (i) {
              final k = keys[i];
              final color = Colors.primaries[i % Colors.primaries.length];
              final count = data[k]!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(k, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }),
          );

          return Column(
            children: [
              Expanded(child: chart),
              const SizedBox(height: 8),
              legend,
            ],
          );
        },
      ),
    );
  }

  Widget monthlySalesCard() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final next = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final days = next.difference(start).inDays;

    return _chartCard(
      title: 'Daily Sales (${_monthName(now.month)})',
      height: 320,
      child: StreamBuilder<Map<int, double>>(
        stream: dailySalesThisMonth(),
        builder: (context, snapshot) {
          final data =
              snapshot.data ?? {for (var d = 1; d <= days; d++) d: 0.0};
          final maxY =
              (data.values.isEmpty
                  ? 0.0
                  : data.values.reduce((a, b) => a > b ? a : b)) *
              1.25;

          return BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY == 0 ? 100 : maxY,
              alignment: BarChartAlignment.spaceAround,
              barGroups: List.generate(days, (i) {
                final day = i + 1;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[day] ?? 0,
                      width: 10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) =>
                    FlLine(strokeWidth: 1, dashArray: const [5, 5]),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (days / 6).ceilToDouble(),
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${value.toInt() + 1}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (value, _) {
                      if (value == 0) return const Text('0');
                      if (value >= 1000000) {
                        final jt = value / 1000000;
                        return Text(
                          jt % 1 == 0
                              ? '${jt.toStringAsFixed(0)} jt'
                              : '${jt.toStringAsFixed(1)} jt',
                        );
                      }
                      return Text(value.toStringAsFixed(0));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          );
        },
      ),
    );
  }

  Widget allTimeMonthlySalesCard() {
    return _chartCard(
      title: 'Total Sales All-Time (By Month)',
      height: 320,
      child: StreamBuilder<List<_MonthPoint>>(
        stream: monthlySalesAllTime(),
        builder: (context, snapshot) {
          final points = snapshot.data ?? [];
          if (points.isEmpty)
            return const Center(child: Text('Belum ada data'));

          final maxY =
              (points.map((e) => e.total).reduce((a, b) => a > b ? a : b)) *
              1.25;

          return BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY == 0 ? 100 : maxY,
              barGroups: List.generate(points.length, (i) {
                final p = points[i];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: p.total,
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) =>
                    FlLine(strokeWidth: 1, dashArray: const [5, 5]),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final d = points[i].month;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_monthName(d.month)}\n${d.year % 100}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (value, _) {
                      if (value == 0) return const Text('0');
                      if (value >= 1000000) {
                        final jt = value / 1000000;
                        return Text(
                          jt % 1 == 0
                              ? '${jt.toStringAsFixed(0)} jt'
                              : '${jt.toStringAsFixed(1)} jt',
                        );
                      }
                      return Text(value.toStringAsFixed(0));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          );
        },
      ),
    );
  }

  // ===================== DASHBOARD CONTENT =====================
  Widget buildDashboardContent() {
    return Expanded(
      child: Column(
        children: [
          buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- METRICS ----
                  LayoutBuilder(
                    builder: (context, c) {
                      final maxW = c.maxWidth;
                      final cols = maxW >= 1380
                          ? 6
                          : maxW >= 1160
                          ? 5
                          : maxW >= 980
                          ? 4
                          : maxW >= 660
                          ? 2
                          : 1;
                      final cardW = (maxW - (16.0 * (cols - 1))) / cols;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardW,
                            child: StreamBuilder<double>(
                              stream: salesThisMonth(),
                              builder: (_, s) => _metricCard(
                                title: 'Sales This Month',
                                leadingIcon: Icons.payments_outlined,
                                value: Text(_fmtCurrency(s.data ?? 0)),
                                sub: const Text('Compared to last period'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardW,
                            child: StreamBuilder<double>(
                              stream: salesLast7Days(),
                              builder: (_, s) => _metricCard(
                                title: 'Sales Last 7 Days',
                                leadingIcon: Icons.trending_up,
                                value: Text(_fmtCurrency(s.data ?? 0)),
                                sub: const Text('Rolling 7 days'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardW,
                            child: StreamBuilder<double>(
                              stream: averageOrderValue(),
                              builder: (_, s) => _metricCard(
                                title: 'Average Order Value',
                                leadingIcon: Icons.attach_money,
                                value: Text(_fmtCurrency(s.data ?? 0)),
                                sub: const Text('Avg per completed order'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardW,
                            child: StreamBuilder<int>(
                              stream: totalOrders(),
                              builder: (_, s) => _metricCard(
                                title: 'Total Orders',
                                leadingIcon: Icons.shopping_bag_outlined,
                                value: Text('${s.data ?? 0}'),
                                sub: const Text('All statuses'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardW,
                            child: StreamBuilder<int>(
                              stream: visitors(),
                              builder: (_, s) => _metricCard(
                                title: 'Users',
                                leadingIcon: Icons.person_outline,
                                value: Text('${s.data ?? 0}'),
                                sub: const Text('Total unique users'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardW,
                            child: StreamBuilder<double>(
                              stream: salesAllTime(),
                              builder: (_, s) => _metricCard(
                                title: 'Total Sales All-Time',
                                leadingIcon: Icons.stacked_bar_chart,
                                value: Text(_fmtCurrency(s.data ?? 0)),
                                sub: const Text('Completed orders'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardW,
                            child: StreamBuilder<double>(
                              stream: pendingPaymentsTotal(),
                              builder: (_, s) => _metricCard(
                                title: 'Pending Payments',
                                leadingIcon: Icons.hourglass_bottom,
                                value: Text(_fmtCurrency(s.data ?? 0)),
                                sub: const Text('Menunggu Pembayaran'),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---- CHARTS ROW 1 ----
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth > 980;
                      if (wide) {
                        return SizedBox(
                          height: 340,
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: weeklySalesCard()),
                              const SizedBox(width: 16),
                              Expanded(child: orderStatusPieCard()),
                            ],
                          ),
                        );
                      } else {
                        return Column(
                          children: [
                            weeklySalesCard(),
                            const SizedBox(height: 16),
                            orderStatusPieCard(),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---- CHARTS ROW 2 ----
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth > 980;
                      if (wide) {
                        return SizedBox(
                          height: 340,
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: monthlySalesCard()),
                              const SizedBox(width: 16),
                              Expanded(child: allTimeMonthlySalesCard()),
                            ],
                          ),
                        );
                      } else {
                        return Column(
                          children: [
                            monthlySalesCard(),
                            const SizedBox(height: 16),
                            allTimeMonthlySalesCard(),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: Row(children: [buildSidebar(), buildDashboardContent()]),
    );
  }
}

class _MonthPoint {
  final DateTime month;
  final double total;
  _MonthPoint(this.month, this.total);
}
