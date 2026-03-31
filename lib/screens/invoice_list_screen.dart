import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';

import 'invoice_preview_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(name: 'UGX');

  @override
  Widget build(BuildContext context) {
    final invoices = DataService().invoices;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: invoices.isEmpty
          ? const Center(child: Text('No invoices found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.picture_as_pdf,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      '${invoice.invoiceNumber} - ${invoice.clientName}',
                    ),
                    subtitle: Text(
                      DateFormat.yMMMd().format(invoice.issueDate),
                    ),
                    trailing: Text(
                      _currencyFormat.format(invoice.finalTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InvoicePreviewScreen(invoice: invoice),
                        ),
                      );
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Invoice?'),
                          content: Text(
                            'Are you sure you want to delete ${invoice.invoiceNumber}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await DataService().deleteInvoice(invoice.id);
                                Navigator.pop(ctx);
                                setState(() {});
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
