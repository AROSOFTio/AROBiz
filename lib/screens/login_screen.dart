import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String _friendlyAuthError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials') ||
        message.contains('invalid credentials')) {
      return 'Incorrect email or password. Please check your details and try again.';
    }
    if (message.contains('email not confirmed') || message.contains('email_not_confirmed')) {
      return 'Please confirm your email address first. Tap Resend confirmation email below.';
    }
    if (message.contains('too many') || message.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (message.contains('socketexception') || message.contains('host lookup') ||
        message.contains('clientexception') || message.contains('network') ||
        message.contains('connection') || message.contains('timed out')) {
      return 'Cannot connect to ARODesk. Check your internet and try again.';
    }
    return 'Unable to sign in right now. Please try again.';
  }

  Future<void> _login() async {
    if (_identifierCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await DataService().login(_identifierCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyAuthError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendConfirmation() async {
    if (_identifierCtrl.text.trim().isEmpty ||
        !_identifierCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address above first.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await DataService().resendEmailConfirmation(_identifierCtrl.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check your email'),
          content: const Text(
            'If this account is awaiting confirmation, a new ARODesk verification email has been requested. Check Inbox and Spam, then try logging in.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyAuthError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                      semanticLabel: 'ARODesk',
                    ),
                    const SizedBox(height: 4),
                    const Text('ARODesk',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800,
                        color: Color(0xFF142235)),),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Login to continue to ARODesk'),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _identifierCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email or Phone Number',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isLoading ? null : () => Navigator.push(
                        context,MaterialPageRoute(builder:(_)=>const ForgotPasswordScreen())),
                      icon: const Icon(Icons.lock_reset_outlined),
                      label: const Text('Forgot password?'),
                    ),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _resendConfirmation,
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      label: const Text('Resend confirmation email'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text('Don\'t have an account? Register here.'),
                    )
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
