import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String kRootEmail = 'admin@sipkabel.com';

  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String errorText = '';
  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Future.microtask(() => _ensureAdminAccess(user));
    }
  }

  Future<void> _bootstrapRootAdmin(User user) async {
    final ref = FirebaseFirestore.instance.collection('admins').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': 'Super Admin',
        'email': user.email,
        'phone': '',
        'role': 'super',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'role': 'super',
        'email': user.email,
        'isActive': true,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _ensureAdminAccess(User user) async {
    try {
      final email = (user.email ?? '').toLowerCase();

      if (email == kRootEmail) {
        await _bootstrapRootAdmin(user);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
        return;
      }

      final doc =
      await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();

      if (doc.exists && (doc.data()?['isActive'] == true)) {
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() => errorText = 'Akun ini tidak memiliki akses admin');
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      setState(() => errorText = 'Login gagal: $e');
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = cred.user;
      if (user != null) {
        await _ensureAdminAccess(user);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          errorText = 'Email tidak ditemukan';
        } else if (e.code == 'wrong-password') {
          errorText = 'Password salah';
        } else {
          errorText = 'Login gagal: ${e.message}';
        }
      });
    }
  }

  // —— POPUP LUPA PASSWORD
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        // biar nggak nempel pinggir & tetap rapi di desktop
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420), // ⬅️ kunci lebar maksimum
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset, color: Colors.orange, size: 32),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Lupa Password?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Untuk reset password, silakan hubungi Manager atau Super Admin. '
                      'Mereka dapat membantu melakukan reset melalui sistem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Mengerti'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      body: Row(
        children: [
          // LEFT SIDE
          Expanded(
            child: Container(
              color: Colors.orange,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo_white.png', width: 250),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // RIGHT SIDE
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/logo_orange.png', width: 80),
                      const SizedBox(height: 16),
                      const Text('Welcome Back!',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Masukkan username dan password untuk login.',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 24),

                      // Username
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline),
                          hintText: 'Username',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Password + eye
                      TextFormField(
                        controller: passwordController,
                        obscureText: !_showPass,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          hintText: 'Password',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          suffixIcon: IconButton(
                            icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _showPass = !_showPass),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 8),

                      // Forgot Password -> POPUP
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('Forget Password?'),
                        ),
                      ),

                      if (errorText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(errorText, style: const TextStyle(color: Colors.red)),
                        ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) _login();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Sign In'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
