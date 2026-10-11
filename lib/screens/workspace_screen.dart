import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

/// Standalone workspace onboarding; enabled after database migration passes.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _country = TextEditingController();
  final _currency = TextEditingController();
  String _industry = 'Retail Shop';
  bool _saving = false;
  late Future<List<Map<String, dynamic>>> _workspaces;

  static const industries = <String>[
    'Retail Shop', 'Wholesale', 'Manufacturing', 'Restaurant & Food',
    'Hotel & Accommodation', 'Services', 'Construction',
    'Agriculture', 'Education', 'Healthcare', 'Technology', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _workspaces = WorkspaceService.instance.listWorkspaces();
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _country.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await WorkspaceService.instance.createWorkspace(
        name: _name.text,
        industry: _industry,
        countryCode: _country.text.trim().toUpperCase(),
        currencyCode: _currency.text.trim().toUpperCase(),
        location: _location.text,
      );
      _name.clear();
      _location.clear();
      if (mounted) {
        setState(() => _workspaces = WorkspaceService.instance.listWorkspaces());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business workspace created.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create workspace: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business workspaces')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your businesses', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _workspaces,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Unable to load businesses: ${snapshot.error}');
              }
              final businesses = snapshot.data ?? [];
              if (businesses.isEmpty) return const Text('No business created yet.');
              return Column(children: [
                for (final business in businesses)
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: Text((business['name'] ?? '').toString()),
                    subtitle: Text(
                      '${business['industry'] ?? ''} · ${business['currency_code'] ?? ''}'),
                  ),
              ]);
            },
          ),
          const Divider(height: 32),
          Text('Create a business', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Business name', border: OutlineInputBorder()),
                validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter a business name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _industry,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Industry', border: OutlineInputBorder()),
                items: industries.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) { if (v != null) setState(() => _industry = v); },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _country,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(labelText: 'Country code (e.g. UG)', border: OutlineInputBorder()),
                validator: (v) => RegExp(r'^[A-Za-z]{2}$').hasMatch(v?.trim() ?? '') ? null : 'Enter two letters',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currency,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                decoration: const InputDecoration(labelText: 'Currency code (e.g. USD)', border: OutlineInputBorder()),
                validator: (v) => RegExp(r'^[A-Za-z]{3}$').hasMatch(v?.trim() ?? '') ? null : 'Enter three letters',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _create,
                  child: _saving ? const CircularProgressIndicator() : const Text('Create workspace'),
                ),
              )
            ]),
          ),
        ],
      ),
    );
  }
}
