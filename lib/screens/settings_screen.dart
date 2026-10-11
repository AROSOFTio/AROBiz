import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/business_profile.dart';
import '../services/data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onSaved});
  final VoidCallback? onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _paymentController;
  final TextEditingController _newServiceController = TextEditingController();

  String _selectedCategory = 'Other';
  String? _logoPath;
  List<String> _services = [];

  final List<String> _categories = [
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

  @override
  void initState() {
    super.initState();
    final profile = DataService().currentProfile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _locationController = TextEditingController(text: profile?.location ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _paymentController = TextEditingController(text: profile?.localPaymentDetails ?? '');
    _logoPath = profile?.logoPath;
    _services = List<String>.from(profile?.servicesOffered ?? []);

    if (profile?.category != null && _categories.contains(profile!.category)) {
      _selectedCategory = profile.category!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _paymentController.dispose();
    _newServiceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _logoPath = pickedFile.path;
        });
      }
    }
  }

  void _addService() {
    final text = _newServiceController.text.trim();
    if (text.isNotEmpty && !_services.contains(text)) {
      setState(() {
        _services.add(text);
        _newServiceController.clear();
      });
    }
  }

  void _removeService(String service) {
    setState(() {
      _services.remove(service);
    });
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isNotEmpty) {
      final profile = BusinessProfile(
        name: _nameController.text,
        location: _locationController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        servicesOffered: _services,
        category: _selectedCategory,
        localPaymentDetails: _paymentController.text,
        logoPath: _logoPath,
      );

      await DataService().saveProfile(profile);

      if (mounted) {
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Business Profile Saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the business name before saving.')),
      );
      setState(() => _step = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
        key: _formKey,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Step ${_step + 1} of 3', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_step + 1) / 3),
              const SizedBox(height: 12),
              Text(['Business details', 'Services & items', 'Payment details'][_step],
                   style: Theme.of(context).textTheme.titleLarge),
            ]),
          ),
          Expanded(child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_step == 0) ...[
            // Logo
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      backgroundImage: _logoPath != null ? FileImage(File(_logoPath!)) : null,
                      child: _logoPath == null
                          ? Icon(Icons.add_a_photo, size: 40, color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('Tap to update Business Logo', style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 24),

            // Business Details
            const Text('Business Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter business name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Business Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              isExpanded: true,
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) setState(() => _selectedCategory = newValue);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location / Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),

            ],
            if (_step == 1) ...[
            // Services Section
            Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: Colors.blueGrey),
                const SizedBox(width: 8),
                const Text('My Services / Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'These appear as quick-select options when creating documents.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Chips for existing services
            if (_services.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _services.map((service) {
                  return Chip(
                    label: Text(service),
                    onDeleted: () => _removeService(service),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

            // Add new service row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newServiceController,
                    decoration: InputDecoration(
                      hintText: 'Type a service/item to add...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _addService(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ],
            if (_step == 2) ...[
            // Payment Details
            const Text('Payment Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paymentController,
              decoration: const InputDecoration(
                labelText: 'Local Payment Details',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
                helperText: 'e.g., MTN Mobile Money: 0771234567, Airtel Money: 0701234567',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            ],
            if (_step == 2) ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              if (_step > 0) ...[
                OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 12),
              ],
              if (_step < 2) Expanded(child: FilledButton(
                onPressed: () {
                  if (_step == 0 && !_formKey.currentState!.validate()) return;
                  FocusScope.of(context).unfocus();
                  setState(() => _step++);
                },
                child: const Text('Next'),
              )),
            ]),
          ),
        ]),
      ),
      ))),
    );
  }
}
