import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      title: 'InternSync Pro Matrix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4F46E5),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (authSnapshot.hasData && authSnapshot.data != null) {
          return StreamBuilder<UserModel?>(
            stream: FirebaseService().streamUserProfile(authSnapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (roleSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Account Error: ${roleSnapshot.error}'),
                        TextButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Return to Login'),
                        ),
                      ],
                    ),
                  ),
                );
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
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 80, color: Color(0xFF4F46E5)),
                        const SizedBox(height: 24),
                        const Text('Complete Your Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('We found your login, but your profile details are missing.', textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Go to Registration Screen'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
        return const LoginRegisterScreen();
      },
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
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFFEC4899)])),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isLogin ? 'Login' : 'Register', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    if (!isLogin) ...[
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'mentor', child: Text('Mentor')),
                        ],
                        onChanged: (v) => setState(() => selectedRole = v!),
                      ),
                      if (selectedRole == 'student') TextField(controller: _mentorIdController, decoration: const InputDecoration(labelText: 'Mentor ID')),
                    ],
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
                    TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                    if (isLogin) TextButton(onPressed: _handleForgotPassword, child: const Text('Forgot Password?')),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _handleSubmit, child: Text(isLogin ? 'Login' : 'Register')),
                    const Divider(height: 48),
                    ElevatedButton.icon(icon: const Icon(Icons.g_mobiledata), label: const Text('Google Sign In'), onPressed: _handleGoogleSignIn),
                    TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? 'Need account?' : 'Have account?')),
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
  final FirebaseService _db = FirebaseService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Finalize Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company')),
              TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
              TextField(controller: _specController, decoration: const InputDecoration(labelText: 'Domain')),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await _db.updateProfile(widget.user.uid, {
                    'company': _companyController.text,
                    'location': _locationController.text,
                    'specialization': _specController.text,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
