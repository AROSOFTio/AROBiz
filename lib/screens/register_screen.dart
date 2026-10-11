import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _emailPhoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String? _selectedCategory;
  bool _isLoading = false;
  bool _isEmail = true;

  final List<String> _businessCategories = [
    'Retail Shop',
    'Wholesale',
    'Restaurant & Food',
    'Hotel & Accommodation',
    'Salon & Beauty',
    'Pharmacy & Health',
    'Electronics & Gadgets',
    'Clothing & Fashion',
    'Hardware & Construction',
    'Transport & Logistics',
    'Agriculture & Farming',
    'Education & Training',
    'Technology & IT Services',
    'Printing & Stationery',
    'Events & Entertainment',
    'Real Estate',
    'Consultancy & Professional Services',
    'General Merchandise',
    'Other',
  ];

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await DataService().register(
        identifier: _emailPhoneCtrl.text.trim(),
        isEmail: _isEmail,
        password: _passwordCtrl.text,
        businessName: _businessNameCtrl.text.trim(),
        category: _selectedCategory ?? 'General Merchandise',
        location: _locationCtrl.text.trim(),
      );
      if (mounted) {
        // Go straight to AppShell and clear history
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        if (message.startsWith('Account created.')) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.mark_email_read_outlined, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(child: Text('Registration successful')),
                ],
              ),
              content: Text(
                _isEmail
                    ? 'Your ARODesk account has been created. We sent a confirmation link to ${_emailPhoneCtrl.text.trim()}. Open your email and confirm your address before signing in. Also check Spam or Junk.'
                    : 'Your ARODesk account has been created. Complete phone verification before signing in.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          );
          if (mounted) Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register on ARODesk'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Your Profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              const Text('Set up your business on ARODesk.'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Email'),
                      value: true,
                      groupValue: _isEmail,
                      onChanged: (val) => setState(() => _isEmail = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Phone'),
                      value: false,
                      groupValue: _isEmail,
                      onChanged: (val) => setState(() => _isEmail = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailPhoneCtrl,
                decoration: InputDecoration(
                  labelText: _isEmail ? 'Email Address' : 'Phone Number',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(_isEmail ? Icons.email_outlined : Icons.phone_outlined),
                ),
                validator: (val) {
                  final value = val?.trim() ?? '';
                  if (value.isEmpty) return 'Required field';
                  if (_isEmail && !RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) => val == null || val.length < 4 ? 'Password must be at least 4 characters' : null,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Business Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                hint: const Text('Select your business type'),
                isExpanded: true,
                items: _businessCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (val) => val == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location / Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
).hasMatch(value)) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) => val == null || val.length < 4 ? 'Password must be at least 4 characters' : null,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Business Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                hint: const Text('Select your business type'),
                isExpanded: true,
                items: _businessCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (val) => val == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location / Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
