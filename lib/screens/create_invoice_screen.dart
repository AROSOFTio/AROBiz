import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../services/data_service.dart';
import 'invoice_preview_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final List<String> _paymentOptions = [
    'Cash',
    'Mobile Money',
    'Bank Transfer',
    'Cheque',
    'To Be Agreed'
  ];
  String _selectedPaymentOption = 'Cash';

  DocumentType _selectedType = DocumentType.invoice;

  final String _documentNumberBase =
      DateTime.now().microsecondsSinceEpoch.toString().substring(8);

  String get _documentNumber {
    switch (_selectedType) {
      case DocumentType.invoice:
        return 'INV-$_documentNumberBase';
      case DocumentType.quotation:
        return 'QUO-$_documentNumberBase';
      case DocumentType.receipt:
        return 'REC-$_documentNumberBase';
    }
  }

  final List<InvoiceItem> _items = [];

  // For item entry
  String? _selectedServiceName;
  final _itemCustomDescController = TextEditingController();
  final _itemQtyController = TextEditingController(text: '1');
  final _itemPriceController = TextEditingController();

  List<String> get _savedServices =>
      DataService().currentProfile?.servicesOffered ?? [];

  void _addItem() {
    final description = _selectedServiceName ?? _itemCustomDescController.text.trim();
    if (description.isEmpty || _itemPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item description and price.')),
      );
      return;
    }

    final qty = int.tryParse(_itemQtyController.text) ?? 1;
    final price = double.tryParse(_itemPriceController.text) ?? 0.0;

    setState(() {
      _items.add(InvoiceItem(
        description: description,
        quantity: qty,
        unitPrice: price,
      ));
      _selectedServiceName = null;
      _itemCustomDescController.clear();
      _itemQtyController.text = '1';
      _itemPriceController.clear();
    });
  }

  Future<void> _promptAddNewService() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Service'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Deep Cleaning, Logo Design...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Save to profile
      final profile = DataService().currentProfile;
      if (profile != null) {
        final updated = profile.copyWith(
          servicesOffered: [...profile.servicesOffered, result],
        );
        await DataService().saveProfile(updated);
      }
      setState(() {
        _selectedServiceName = result;
      });
    }
  }

  void _generateInvoice() {
    if (_formKey.currentState!.validate() && _items.isNotEmpty) {
      final discount = double.tryParse(_discountController.text) ?? 0.0;

      final invoice = Invoice(
        id: const Uuid().v4(),
        invoiceNumber: _documentNumber,
        issueDate: DateTime.now(),
        clientName: _clientNameController.text,
        clientPhone: _clientPhoneController.text,
        items: _items,
        discount: discount,
        taxRate: 0.0,
        notes: _notesController.text,
        paymentOption: _selectedPaymentOption,
        type: _selectedType,
      );

      DataService().saveInvoice(invoice);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedType.name} saved! Proceeding to preview...')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => InvoicePreviewScreen(invoice: invoice)),
      );
    } else if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(title: Text('Create New ${_selectedType.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Document Type Selector
            Center(
              child: SegmentedButton<DocumentType>(
                segments: const [
                  ButtonSegment(value: DocumentType.invoice, label: Text('Invoice'), icon: Icon(Icons.receipt_long)),
                  ButtonSegment(value: DocumentType.quotation, label: Text('Quote'), icon: Icon(Icons.request_quote)),
                  ButtonSegment(value: DocumentType.receipt, label: Text('Receipt'), icon: Icon(Icons.check_circle_outline)),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<DocumentType> newSelection) {
                  setState(() => _selectedType = newSelection.first);
                },
              ),
            ),
            const SizedBox(height: 24),

            // Client Details
            const Text('1. Client Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                labelText: 'Client / Company Name *',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientPhoneController,
              decoration: const InputDecoration(
                labelText: 'Client Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // Items
            const Text('2. Services & Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // List of added items
            if (_items.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    child: ListTile(
                      title: Text(item.description),
                      subtitle: Text('${item.quantity} x UGX ${item.unitPrice.toStringAsFixed(0)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'UGX ${item.total.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => _items.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Add Item form card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service dropdown or custom text
                    if (_savedServices.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedServiceName,
                        decoration: const InputDecoration(
                          labelText: 'Select Service / Item',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.list_alt),
                        ),
                        isExpanded: true,
                        hint: const Text('Pick from your services...'),
                        items: [
                          ..._savedServices.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                          const DropdownMenuItem(
                            value: '__custom__',
                            child: Row(
                              children: [
                                Icon(Icons.add, color: Colors.blue, size: 18),
                                SizedBox(width: 6),
                                Text('+ Add new service...', style: TextStyle(color: Colors.blue)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == '__custom__') {
                            await _promptAddNewService();
                          } else {
                            setState(() => _selectedServiceName = val);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      const Center(child: Text('— or type manually —', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      controller: _itemCustomDescController,
                      decoration: InputDecoration(
                        labelText: _savedServices.isNotEmpty ? 'Custom Description (optional)' : 'Item Description',
                        border: const UnderlineInputBorder(),
                        hintText: _selectedServiceName != null ? 'Using: $_selectedServiceName' : null,
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          setState(() => _selectedServiceName = null);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _itemQtyController,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _itemPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Unit Price',
                              prefixText: 'UGX ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, size: 40),
                          color: theme.colorScheme.primary,
                          onPressed: _addItem,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Additional Details
            const Text('3. Additional Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedPaymentOption,
              decoration: const InputDecoration(
                labelText: 'Payment Option',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: _paymentOptions.map((String option) {
                return DropdownMenuItem<String>(value: option, child: Text(option));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) setState(() => _selectedPaymentOption = newValue);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'Discount Amount',
                border: OutlineInputBorder(),
                prefixText: 'UGX ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Terms (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _generateInvoice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Generate ${_selectedType.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
