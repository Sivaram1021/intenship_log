import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_service.dart';
import 'models.dart';
import 'student_dashboard.dart';
import 'mentor_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const InternshipTrackerApp());
}

class InternshipTrackerApp extends StatelessWidget {
  const InternshipTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InternSync Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0EA5E9),
        scaffoldBackgroundColor: const Color(0xFF0EA5E9),
      ),
      home: const AuthGateway(),
    );
  }
}

class AuthGateway extends StatelessWidget {
  const AuthGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
        }
        if (authSnapshot.hasData && authSnapshot.data != null) {
          return StreamBuilder<UserModel?>(
            stream: FirebaseService().streamUserProfile(authSnapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
              }
              
              if (roleSnapshot.hasData && roleSnapshot.data != null) {
                final user = roleSnapshot.data!;
                if (user.role == 'student' &&
                    (user.company == null || user.company!.isEmpty ||
                     user.location == null || user.location!.isEmpty ||
                     user.specialization == null || user.specialization!.isEmpty)) {
                  return FinalizeProfileScreen(user: user);
                }
                return user.role == 'mentor'
                    ? MentorDashboard(mentor: user)
                    : StudentDashboard(student: user);
              }
              
              return RoleSelectionScreen(firebaseUser: authSnapshot.data!);
            },
          );
        }
        return const LoginRegisterScreen();
      },
    );
  }
}

class RoleSelectionScreen extends StatefulWidget {
  final User firebaseUser;
  const RoleSelectionScreen({super.key, required this.firebaseUser});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final ds = FirebaseService();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF0369A1)],
          ),
        ),
        child: Stack(
          children: [
            CustomPaint(painter: BackgroundPainter(), size: Size.infinite),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.account_tree_outlined, size: 80, color: Colors.white),
                    const SizedBox(height: 24),
                    const Text('Select Your Workspace Identity', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 12),
                    const Text('To configure your dashboard, please specify your role.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const Spacer(),
                    if (_isLoading)
                      const CircularProgressIndicator(color: Colors.white)
                    else ...[
                      _roleCard(
                        context,
                        title: 'Student / Intern',
                        desc: 'Log daily activities and track hours.',
                        icon: Icons.school_rounded,
                        onTap: () async {
                          setState(() => _isLoading = true);
                          try {
                            await ds.updateProfile(widget.firebaseUser.uid, {
                              'name': widget.firebaseUser.displayName ?? widget.firebaseUser.email?.split('@').first ?? 'New Student',
                              'email': widget.firebaseUser.email,
                              'role': 'student',
                              'mentorIds': [],
                            });
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save role: $e')));
                              setState(() => _isLoading = false);
                            }
                          }
                        }
                      ),
                      const SizedBox(height: 20),
                      _roleCard(
                        context,
                        title: 'Mentor / Supervisor',
                        desc: 'Review intern logs and provide feedback.',
                        icon: Icons.admin_panel_settings_rounded,
                        onTap: () async {
                          setState(() => _isLoading = true);
                          try {
                            await ds.updateProfile(widget.firebaseUser.uid, {
                              'name': widget.firebaseUser.displayName ?? widget.firebaseUser.email?.split('@').first ?? 'New Mentor',
                              'email': widget.firebaseUser.email,
                              'role': 'mentor',
                              'mentorIds': [],
                            });
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save role: $e')));
                              setState(() => _isLoading = false);
                            }
                          }
                        }
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(BuildContext context, {required String title, required String desc, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: const Color(0xFF0EA5E9), size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});
  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _mentorIdController = TextEditingController();
  bool isLogin = true;
  bool savePassword = true;
  String selectedRole = 'student';
  final FirebaseService _authService = FirebaseService();

  void _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email first')));
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset Link Sent'),
          content: Text('Check your email: $email'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _handleGoogleSignIn() async {
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    try {
      if (isLogin) {
        await _authService.signIn(email, password);
      } else {
        await _authService.signUp(email, password, _nameController.text.trim(), selectedRole, mentorId: _mentorIdController.text.trim());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF0369A1)],
          ),
        ),
        child: Stack(
          children: [
            CustomPaint(painter: BackgroundPainter(), size: Size.infinite),
            Positioned(
              top: 50,
              left: 24,
              child: Row(
                children: const [
                  Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'intenship_log',
                    style: TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    const Text('Hello', style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                    const Text('Welcome Back!', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Text(isLogin ? 'Login Account' : 'Join Us', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black)),
                                const SizedBox(height: 8),
                                const Text('Enter your details below to securely access your workspace.', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (!isLogin) ...[
                            _label('Full Name'),
                            _textField(_nameController, 'Enter Name', Icons.person),
                            const SizedBox(height: 20),
                            _label('Workspace Role'),
                            DropdownButtonFormField<String>(
                              initialValue: selectedRole,
                              items: const [
                                DropdownMenuItem(value: 'student', child: Text('Student')),
                                DropdownMenuItem(value: 'mentor', child: Text('Mentor')),
                              ],
                              onChanged: (v) => setState(() => selectedRole = v!),
                              decoration: _inputDecoration('').copyWith(
                                suffixIcon: const Icon(Icons.admin_panel_settings, color: Colors.grey),
                              ),
                            ),
                            if (selectedRole == 'student') ...[
                              const SizedBox(height: 20),
                              _label('Supervisor Key'),
                              _textField(_mentorIdController, 'Enter Mentor ID', Icons.vpn_key),
                            ],
                            const SizedBox(height: 20),
                          ],
                          _label('Email Address'),
                          _textField(_emailController, 'Your Email Address', Icons.person),
                          const SizedBox(height: 20),
                          _label('Password'),
                          _textField(_passwordController, '••••••••••••', Icons.lock, obscure: true),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: savePassword,
                                      activeColor: Colors.green,
                                      shape: const CircleBorder(),
                                      onChanged: (v) => setState(() => savePassword = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Save Password', style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (isLogin)
                                GestureDetector(
                                  onTap: _handleForgotPassword,
                                  child: const Text('Forgot Password?', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDBA74),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                              ),
                              child: Text(isLogin ? 'Login Account' : 'Save & Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: () => setState(() => isLogin = !isLogin),
                              child: Text(isLogin ? 'Create New Account' : 'Back to Login', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (isLogin)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: OutlinedButton.icon(
                          onPressed: _handleGoogleSignIn,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Connect with Google'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide.none,
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }

  Widget _textField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: _inputDecoration(hint).copyWith(
        suffixIcon: Icon(icon, color: Colors.grey, size: 20),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
    );
  }
}

class FinalizeProfileScreen extends StatefulWidget {
  final UserModel user;
  const FinalizeProfileScreen({super.key, required this.user});
  @override
  State<FinalizeProfileScreen> createState() => _FinalizeProfileScreenState();
}

class _FinalizeProfileScreenState extends State<FinalizeProfileScreen> {
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _specController = TextEditingController();
  final _totalDaysController = TextEditingController(text: '30');
  final FirebaseService _db = FirebaseService();
  DateTime _startDate = DateTime.now();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF0369A1)],
          ),
        ),
        child: Stack(
          children: [
            CustomPaint(painter: BackgroundPainter(), size: Size.infinite),
            Center(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Finalize Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      const Text('Just a few more details to set up your workspace.', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey)),
                      const SizedBox(height: 32),
                      TextField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company / Organization')),
                      const SizedBox(height: 16),
                      TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Office Location')),
                      const SizedBox(height: 16),
                      TextField(controller: _specController, decoration: const InputDecoration(labelText: 'Domain / Specialization')),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Start Date: ${DateFormat('dd MMM yyyy').format(_startDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setState(() => _startDate = picked);
                            },
                            child: const Text('Pick Date'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _totalDaysController, 
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Internship Days (Duration)'),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () async {
                            if (_companyController.text.isEmpty || _locationController.text.isEmpty || _specController.text.isEmpty || _totalDaysController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields.')));
                              return;
                            }
                            setState(() => _isSaving = true);
                            try {
                              await _db.updateProfile(widget.user.uid, {
                                'company': _companyController.text, 
                                'location': _locationController.text, 
                                'specialization': _specController.text,
                                'startDate': Timestamp.fromDate(_startDate),
                                'totalInternshipDays': int.tryParse(_totalDaysController.text) ?? 30,
                              });
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDBA74), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                          child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text('Save & Enter Workspace', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = Colors.white.withAlpha(25);
    paint.strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    paint.shader = const LinearGradient(colors: [Colors.white24, Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 150, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.8), 250, paint);
    paint.shader = RadialGradient(colors: [Colors.white.withAlpha(40), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * 0.5, size.height * 0.1), radius: 200));
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.1), 200, paint);
    paint.shader = RadialGradient(colors: [Colors.white.withAlpha(30), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.4), radius: 180));
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.4), 180, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
