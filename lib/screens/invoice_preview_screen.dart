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
      ),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                const Icon(Icons.print_outlined, size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text('Paper size',
                    style: Theme.of(context).textTheme.labelLarge)),
                DropdownButton<InvoiceSize>(
                  value: _selectedSize,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: InvoiceSize.a4, child: Text('A4')),
                    DropdownMenuItem(value: InvoiceSize.a5, child: Text('A5')),
                    DropdownMenuItem(value: InvoiceSize.thermal, child: Text('80 mm receipt')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedSize = value);
                  },
                ),
              ]),
            ),
          ),
          Expanded(child: PdfPreview(

        key: ValueKey(_selectedSize),
        build: (format) => PdfInvoiceApi.generate(widget.invoice, _selectedSize),
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: _selectedSize == InvoiceSize.a4
            ? PdfPageFormat.a4
            : _selectedSize == InvoiceSize.a5
                ? PdfPageFormat.a5
                : PdfPageFormat.roll80,
      )),
      ]),
    );
  }
}
