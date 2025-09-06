import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart'; // ⬅️ hilangin # di URL
import 'firebase_options.dart';

import 'features/auth/pages/login_page.dart';
import 'features/dashboard/pages/dashboard_page.dart';

import 'features/products/pages/product_list_page.dart';
import 'features/products/pages/product_form_page.dart';
import 'features/products/models/product_model.dart';
import 'features/products/pages/product_detail_page.dart';

import 'features/banners/pages/banner_page.dart';
import 'features/banners/pages/add_banner_page.dart';
import 'features/banners/pages/edit_banner_page.dart';

import 'features/notifications/pages/add_notification_page.dart';
import 'features/notifications/pages/notification_list_page.dart';

import 'features/catalogs/pages/catalog_list_page.dart';
import 'features/catalogs/pages/add_catalog_page.dart';

import 'src/features/orders/pages/order_page.dart';
import 'src/features/orders/pages/order_dispute_page.dart'; // ✅ BARU
import 'src/features/orders/pages/order_dispute_detail_page.dart'; // ✅ BARU

import 'package:google_fonts/google_fonts.dart';

import 'features/users/pages/user_list_page.dart';
import 'features/users/pages/user_form_page.dart';

import 'features/admins/pages/admin_list_page.dart';
import 'features/admins/pages/add_edit_admin_page.dart';
import 'features/admins/pages/admin_profile_page.dart';

// ⬇️ daftarin RouteObserver supaya bisa dipakai di halaman (RouteAware)
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    usePathUrlStrategy(); // ⬅️ hilangin tanda #
    await FirebaseAuth.instance.setPersistence(
      Persistence.LOCAL,
    ); // session login nempel
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel SIPKABEL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      navigatorObservers: [routeObserver], // ⬅️ aktifkan observer

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return const DashboardPage();
          return const LoginPage();
        },
      ),

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
          case '/dashboard':
            return MaterialPageRoute(
              builder: (_) => const DashboardPage(),
              settings: settings,
            );

          case '/profile':
            return MaterialPageRoute(
              builder: (_) => const AdminProfilePage(),
              settings: settings,
            );

          // PRODUCTS
          case '/products':
            return MaterialPageRoute(
              builder: (_) => const ProductListPage(),
              settings: settings,
            );
          case '/add-product':
            return MaterialPageRoute(
              builder: (_) => const ProductFormPage(isEdit: false),
              settings: settings,
            );
          case '/edit-product':
            final args = settings.arguments as ProductModel;
            return MaterialPageRoute(
              builder: (_) => ProductFormPage(isEdit: true, product: args),
              settings: settings,
            );
          case '/product-detail':
            final args = settings.arguments as ProductModel;
            return MaterialPageRoute(
              builder: (_) => ProductDetailPage(product: args),
              settings: settings,
            );

          // BANNERS
          case '/banners':
            return MaterialPageRoute(
              builder: (_) => const BannerPage(),
              settings: settings,
            );
          case '/add-banner':
            return MaterialPageRoute(
              builder: (_) => const AddBannerPage(),
              settings: settings,
            );
          case '/edit-banner':
            return MaterialPageRoute(
              builder: (_) => const EditBannerPage(),
              settings: settings,
            );

          // ORDERS
          case '/orders':
            return MaterialPageRoute(
              builder: (_) => const OrderPage(),
              settings: settings,
            );

          // ORDER DISPUTES (BARU)
          case '/order-disputes':
            return MaterialPageRoute(
              builder: (_) => const OrderDisputePage(),
              settings: settings,
            );
          case '/order-dispute-detail':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => OrderDisputeDetailPage(
                orderId: args['orderId'],
                orderData: args['orderData'],
              ),
              settings: settings,
            );

          // NOTIFICATIONS
          case '/add-notification':
            return MaterialPageRoute(
              builder: (_) => const AddNotificationPage(),
              settings: settings,
            );
          case '/admin-notifications':
            return MaterialPageRoute(
              builder: (_) => const NotificationListPage(),
              settings: settings,
            );

          // CATALOGS
          case '/admin-catalogs':
            return MaterialPageRoute(
              builder: (_) => const CatalogListPage(),
              settings: settings,
            );
          case '/add-catalog':
            return MaterialPageRoute(
              builder: (_) => const AddCatalogPage(),
              settings: settings,
            );

          // USERS
          case '/users':
            return MaterialPageRoute(
              builder: (_) => const UserListPage(),
              settings: settings,
            );
          case '/add-user':
            return MaterialPageRoute(
              builder: (_) => const UserFormPage(isEdit: false),
              settings: settings,
            );
          case '/edit-user':
            final userId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => _EditUserLoader(userId: userId),
              settings: settings,
            );

          // ADMIN MANAGEMENT
          case '/admins':
            return MaterialPageRoute(
              builder: (_) => const AdminListPage(),
              settings: settings,
            );
          case '/add-admin':
            return MaterialPageRoute(
              builder: (_) => const AddEditAdminPage(),
              settings: settings,
            );
          case '/edit-admin':
            return MaterialPageRoute(
              builder: (_) => const AddEditAdminPage(),
              settings: settings,
            );

          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginPage(),
              settings: settings,
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Halaman tidak ditemukan')),
              ),
              settings: settings,
            );
        }
      },
    );
  }
}

class _EditUserLoader extends StatelessWidget {
  final String userId;
  const _EditUserLoader({required this.userId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('users').doc(userId);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: ref.get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('User tidak ditemukan')),
          );
        }
        return UserFormPage(isEdit: true, doc: snap.data);
      },
    );
  }
}
