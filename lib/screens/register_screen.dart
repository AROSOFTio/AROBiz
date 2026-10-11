import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/data_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _business = TextEditingController();
  final _location = TextEditingController();
  final _accountForm = GlobalKey<FormState>();
  final _businessForm = GlobalKey<FormState>();
  static const _categories = <String>[
    'Retail Shop', 'Wholesale', 'Manufacturing', 'Restaurant & Food',
    'Hotel & Accommodation', 'Salon & Beauty', 'Pharmacy & Health',
    'Electronics & Gadgets', 'Clothing & Fashion', 'Hardware & Construction',
    'Transport & Logistics', 'Agriculture & Farming', 'Education & Training',
    'Technology & IT Services', 'Printing & Stationery', 'Events & Entertainment',
    'Real Estate', 'Consultancy & Professional Services', 'General Merchandise', 'Other',
  ];
  String? _category;
  int _step = 0;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _business.dispose();
    _location.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !(_accountForm.currentState?.validate() ?? false)) return;
    if (_step == 1 && !(_businessForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  String _errorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (error is SocketException || error is TimeoutException ||
        message.contains('socketexception') || message.contains('host lookup') ||
        message.contains('clientexception') || message.contains('network') ||
        message.contains('failed to fetch') || message.contains('connection')) {
      return 'ARODesk could not connect to the server. Please check Wi-Fi or mobile data, then try again.';
    }
    if (message.contains('already registered') || message.contains('already exists') ||
        message.contains('already have an account') || message.contains('user already registered') ||
        message.contains('email already in use') || message.contains('duplicate')) {
      return 'This email is already registered. Please log in instead.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many attempts. Please wait and try again.';
    }
    if (message.contains('weak_password') || message.contains('password should') ||
        message.contains('password must') || message.contains('password is too short')) {
      return 'Choose a stronger password with at least 8 characters.';
    }
    return 'Registration was not completed. If you previously registered this email, sign in instead; otherwise try again.';
  }

  Future<void> _notice(String title, String message, bool success) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context, barrierDismissible: !success,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [
          Icon(success ? Icons.check_circle_outline : Icons.info_outline,
            color: success ? Colors.green : Theme.of(dialogContext).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
        ]),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(success ? 'Go to Login' : 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await DataService().register(
        identifier: _email.text.trim(),
        isEmail: true,
        password: _password.text,
        businessName: _business.text.trim(),
        category: _category ?? 'Other',
        location: _location.text.trim(),
      ).timeout(const Duration(seconds: 35));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()), (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().replaceFirst('Exception: ', '');
      if (detail.startsWith('Account created.')) {
        await _notice('Registration successful',
          'Your account has been created. Check ' + _email.text.trim() +
          ' for the confirmation link (including Spam or Junk). Confirm the email before logging in.',
          true);
        if (mounted) Navigator.of(context).pop();
      } else {
        await _notice('Registration unsuccessful', _errorMessage(error), false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String text, IconData icon) =>
    InputDecoration(
      labelText: text, prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

  Widget _account() => Form(
    key: _accountForm,
    child: Column(children: [
      TextFormField(
        controller: _email, keyboardType: TextInputType.emailAddress,
        decoration: _decoration('Email address', Icons.email_outlined),
        validator: (v) {
          final text = (v ?? '').trim();
          if (text.isEmpty) return 'Enter your email address';
          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Enter a valid email';
          return null;
        },
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: _password, obscureText: !_showPassword,
        decoration: _decoration('Create password', Icons.lock_outline).copyWith(
          suffixIcon: IconButton(
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        validator: (v) => (v?.length ?? 0) < 8 ? 'Use at least 8 characters' : null,
      ),
      const SizedBox(height: 18),
      const Text('You will receive a confirmation email before your first login.'),
    ]),
  );

  Widget _businessDetails() => Form(
    key: _businessForm,
    child: Column(children: [
      TextFormField(
        controller: _business, decoration: _decoration('Business name', Icons.business_outlined),
        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter your business name' : null,
      ),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        value: _category,
        isExpanded: true,
        decoration: _decoration('Business category', Icons.category_outlined),
        items: _categories.map((category) => DropdownMenuItem<String>(
          value: category, child: Text(category, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) => setState(() => _category = v),
        validator: (v) => v == null ? 'Choose a category' : null,
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: _location,
        decoration: _decoration('Location (optional)', Icons.location_on_outlined),
      ),
    ]),
  );

  Widget _review() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _item('Email', _email.text.trim()),
    _item('Business', _business.text.trim()),
    _item('Industry', _category ?? 'Other'),
    _item('Location', _location.text.trim().isEmpty ? 'Not provided' : _location.text.trim()),
    const SizedBox(height: 16),
    const Text('After creating your account, check your email and confirm your address.'),
  ]);

  Widget _item(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 86, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
      Expanded(child: Text(value)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    const headings = ['Your login', 'Your business', 'Review details'];
    return Scaffold(
      appBar: AppBar(title: const Text('Register on ARODesk')),
      body: SafeArea(child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Step ' + (_step + 1).toString() + ' of 3',
                  style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (_step + 1) / 3, minHeight: 6),
                const SizedBox(height: 18),
                Text(headings[_step],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  )),
                const SizedBox(height: 8),
                Text(_step == 0 ? 'Create your secure account.' :
                  _step == 1 ? 'Tell us about your business.' : 'Confirm before registering.'),
              ]),
            ),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: _step == 0 ? _account() : _step == 1 ? _businessDetails() : _review(),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(children: [
                if (_step > 0) ...[
                  OutlinedButton(
                    onPressed: _busy ? null : () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: FilledButton(
                  onPressed: _busy ? null : (_step == 2 ? _register : _next),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _busy
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_step == 2 ? 'Create Account' : 'Next'),
                  ),
                )),
              ]),
            ),
          ]),
        ),
      )),
    );
  }
}
