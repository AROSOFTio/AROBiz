import 'dart:typed_data';
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
  final Map<InvoiceSize,Future<Uint8List>> _cachedPdf = {};
  final Map<InvoiceSize,Future<List<Uint8List>>> _cachedPages = {};
  final TransformationController _zoom = TransformationController();
  bool _busy = false;

  Future<Uint8List> _pdf(InvoiceSize size) =>
      _cachedPdf.putIfAbsent(size, () => PdfInvoiceApi.generate(widget.invoice, size));

  Future<List<Uint8List>> _pages(InvoiceSize size) =>
      _cachedPages.putIfAbsent(size, () async {
        final bytes = await _pdf(size);
        final pages = <Uint8List>[];
        await for (final page in Printing.raster(bytes, dpi: 150)) {
          pages.add(await page.toPng());
        }
        if (pages.isEmpty) throw StateError('Document has no pages.');
        return pages;
      });

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _changeSize(InvoiceSize? next) {
    if (next == null || next == _selectedSize) return;
    _zoom.value = Matrix4.identity();
    setState(() => _selectedSize = next);
  }

  Future<void> _print() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _pdf(_selectedSize);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _pdf(_selectedSize);
      final reference = widget.invoice.invoiceNumber.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await Printing.sharePdf(bytes: bytes, filename: '$reference.pdf');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _selectedSize;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.invoice.type.name} Preview'),
        actions: [
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: () => _zoom.value = Matrix4.identity(),
            icon: const Icon(Icons.fit_screen_outlined)),
          IconButton(
            tooltip: 'Print',
            onPressed: _busy ? null : _print,
            icon: const Icon(Icons.print_outlined)),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              const Icon(Icons.description_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('PDF', style: Theme.of(context).textTheme.labelLarge)),
              DropdownButton<InvoiceSize>(
                value: size,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: InvoiceSize.a4, child: Text('A4')),
                  DropdownMenuItem(value: InvoiceSize.a5, child: Text('A5')),
                  DropdownMenuItem(value: InvoiceSize.thermal, child: Text('80 mm receipt')),
                ],
                onChanged: _changeSize,
              ),
            ]),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: FutureBuilder<List<Uint8List>>(
              key: ValueKey(size),
              future: _pages(size),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Could not preview this PDF: ${snapshot.error}')));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pageImages = snapshot.data!;
                final pageWidth = MediaQuery.sizeOf(context).width - 24;
                // InteractiveViewer owns both pinch-to-zoom and panning gestures.
                // Rasterized pages are rendered locally; no network is required.
                return ColoredBox(
                  color: const Color(0xFFEDEFF2),
                  child: InteractiveViewer(
                    transformationController: _zoom,
                    minScale: 0.8,
                    maxScale: 5,
                    boundaryMargin: const EdgeInsets.all(80),
                    constrained: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final bytes in pageImages)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Image.memory(
                                bytes,
                                width: pageWidth,
                                fit: BoxFit.fitWidth,
                                gaplessPlayback: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
