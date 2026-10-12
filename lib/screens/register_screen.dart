import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/data_service.dart';
import '../services/country_currency.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
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
  String? _country;
  int _step = 0;
  bool _busy = false;
  bool _showPassword = false;
  String? _noticeText;
  bool _registrationComplete = false;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
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
      return 'Use at least 6 characters with uppercase, lowercase and a special character.';
    }
    return 'Registration was not completed. If you previously registered this email, sign in instead; otherwise try again.';
  }

  Future<void> _notice(String title, String message, bool success) async {
    if (!mounted) return;
    setState(() {
      _noticeText = message;
      _registrationComplete = success;
    });
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() { _busy = true; _noticeText = null; });
    try {
      await DataService().register(
        identifier: _email.text.trim(),
        isEmail: true,
        password: _password.text,
        businessName: _business.text.trim(),
        category: _category ?? 'Other',
        location: _location.text.trim(),
        countryCode: _country,
        firstName:_firstName.text.trim(),
        middleName:_middleName.text.trim(),
        lastName:_lastName.text.trim(),
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
        controller:_firstName,textCapitalization:TextCapitalization.words,
        decoration:_decoration('First name *',Icons.person_outline),
        validator:(v)=>(v?.trim().isEmpty??true)?'Enter your first name':null,
      ),
      const SizedBox(height:14),
      TextFormField(
        controller:_middleName,textCapitalization:TextCapitalization.words,
        decoration:_decoration('Middle name (optional)',Icons.person_outline),
      ),
      const SizedBox(height:14),
      TextFormField(
        controller:_lastName,textCapitalization:TextCapitalization.words,
        decoration:_decoration('Last name *',Icons.person_outline),
        validator:(v)=>(v?.trim().isEmpty??true)?'Enter your last name':null,
      ),
      const SizedBox(height:18),
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
        validator:(v){
          final value=v??'';
          if(value.length<6||!RegExp(r'[A-Z]').hasMatch(value)||
              !RegExp(r'[a-z]').hasMatch(value)||
              !RegExp(r'[^a-zA-Z0-9]').hasMatch(value)){
            return '6+ characters, uppercase, lowercase and a special character';
          }
          return null;
        },
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
      DropdownButtonFormField<String>(
        value: _country, isExpanded: true,
        decoration: _decoration('Country of residence *', Icons.public),
        hint: const Text('Select country'),
        items: (CountryCurrency.countries.entries.toList()
          ..sort((a,b)=>a.value.compareTo(b.value)))
          .map((e)=>DropdownMenuItem<String>(
            value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v)=>setState(()=>_country=v),
        validator:(v)=>v==null?'Choose your country':null,
      ),
      const SizedBox(height:18),
      if (_country != null) Align(
        alignment:Alignment.centerLeft,
        child:Text('Default currency: '+CountryCurrency.currency(_country)),
      ),
      const SizedBox(height:18),
      TextFormField(
        controller: _location,
        decoration: _decoration('Location (optional)', Icons.location_on_outlined),
      ),
    ]),
  );

  Widget _review() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _item('Name',[_firstName.text,_middleName.text,_lastName.text]
      .where((v)=>v.trim().isNotEmpty).join(' ')),
    _item('Email', _email.text.trim()),
    _item('Role','Business Owner'),
    _item('Business', _business.text.trim()),
    _item('Industry', _category ?? 'Other'),
    _item('Country', CountryCurrency.countries[_country]??'Not selected'),
    _item('Currency', CountryCurrency.currency(_country)),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Image.asset('assets/logo.png',width:74,height:74,fit:BoxFit.contain)),
                const SizedBox(height:8),
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
            if (_noticeText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Card(
                  color: _registrationComplete
                      ? Colors.green.shade50
                      : Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Icon(_registrationComplete ? Icons.check_circle_outline : Icons.info_outline),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_registrationComplete
                            ? 'Registration successful' : 'Registration notice',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 8),
                      Text(_noticeText!),
                      if (_registrationComplete) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go to Login'),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            Expanded(child: SingleChildScrollView(
              keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
              padding:EdgeInsets.fromLTRB(20,14,20,
                MediaQuery.viewInsetsOf(context).bottom>0?90:24),
              child: _registrationComplete
                  ? const Center(child: Icon(Icons.mark_email_read_outlined, size: 72, color: Colors.green))
                  : (_step == 0 ? _account() : _step == 1 ? _businessDetails() : _review()),
            )),
            Padding(
              padding: EdgeInsets.fromLTRB(20,12,20,
                MediaQuery.viewPaddingOf(context).bottom+28),
              child: _registrationComplete ? const SizedBox.shrink() : Row(children: [
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
