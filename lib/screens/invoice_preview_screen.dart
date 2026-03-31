import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../models/invoice.dart';
import '../services/pdf_invoice_api.dart';

enum InvoiceSize { a4, a5, thermal }

class InvoicePreviewScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  InvoiceSize _selectedSize = InvoiceSize.a4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.invoice.type.name} Preview'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<InvoiceSize>(
              value: _selectedSize,
              dropdownColor: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              onChanged: (InvoiceSize? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedSize = newValue;
                  });
                }
              },
              items: const [
                DropdownMenuItem(
                  value: InvoiceSize.a4,
                  child: Text('A4 Size'),
                ),
                DropdownMenuItem(
                  value: InvoiceSize.a5,
                  child: Text('A5 Size'),
                ),
                DropdownMenuItem(
                  value: InvoiceSize.thermal,
                  child: Text('Thermal (80mm)'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => PdfInvoiceApi.generate(widget.invoice, _selectedSize),
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: _selectedSize == InvoiceSize.a4
            ? PdfPageFormat.a4
            : _selectedSize == InvoiceSize.a5
                ? PdfPageFormat.a5
                : PdfPageFormat.roll80,
      ),
    );
  }
}
