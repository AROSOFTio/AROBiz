import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/business_profile.dart';
import 'data_service.dart';
import '../screens/invoice_preview_screen.dart';

class PdfInvoiceApi {
  // ─── Per-type theme colors ───────────────────────────────────────────────
  static PdfColor _accentColor(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return PdfColors.blue900;
      case DocumentType.quotation:
        return PdfColors.orange800;
      case DocumentType.receipt:
        return PdfColors.green800;
    }
  }

  // ─── Per-type labels ─────────────────────────────────────────────────────
  static String _billedToLabel(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return 'Billed To:';
      case DocumentType.quotation:
        return 'Prepared For:';
      case DocumentType.receipt:
        return 'Received From:';
    }
  }

  static String _docRefLabel(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return 'Invoice #:';
      case DocumentType.quotation:
        return 'Quotation #:';
      case DocumentType.receipt:
        return 'Receipt #:';
    }
  }

  static String _footerMessage(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return 'Thank you for your business! Please make payment by the agreed date.';
      case DocumentType.quotation:
        return 'This quotation is valid for 14 days from the date above.\nWe look forward to working with you!';
      case DocumentType.receipt:
        return 'Payment received in full. Thank you for your trust in us!';
    }
  }

  static String _thermalFooter(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return 'Thank you for your business!';
      case DocumentType.quotation:
        return 'Valid 14 days. We look forward to serving you!';
      case DocumentType.receipt:
        return 'Payment received. Thank you!';
    }
  }

  static String _amountLabel(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return 'Amount Due:';
      case DocumentType.quotation:
        return 'Quoted Total:';
      case DocumentType.receipt:
        return 'Amount Paid:';
    }
  }

  // ─── Load logo bytes ─────────────────────────────────────────────────────
  static Future<pw.ImageProvider?> _loadLogo(BusinessProfile? profile) async {
    try {
      if (profile?.logoPath != null) {
        final file = File(profile!.logoPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.MemoryImage(bytes);
        }
      }
      // Fallback: try bundled assets/logo.png
      final data = await rootBundle.load('assets/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ─── Main entry ──────────────────────────────────────────────────────────
  static Future<Uint8List> generate(Invoice invoice, InvoiceSize size) async {
    final pdf = pw.Document();
    final profile = DataService().currentProfile;
    final currencyFormat = NumberFormat.currency(name: invoice.currencyCode ?? profile?.currencyCode ?? 'USD', symbol: (invoice.currencyCode ?? profile?.currencyCode ?? 'USD') + ' ');
    final logoImage = await _loadLogo(profile);

    PdfPageFormat pageFormat;
    pw.EdgeInsets margin;

    switch (size) {
      case InvoiceSize.a4:
        pageFormat = PdfPageFormat.a4;
        margin = const pw.EdgeInsets.all(32);
        break;
      case InvoiceSize.a5:
        pageFormat = PdfPageFormat.a5;
        margin = const pw.EdgeInsets.all(24);
        break;
      case InvoiceSize.thermal:
        pageFormat = PdfPageFormat.roll80;
        margin = const pw.EdgeInsets.all(12);
        break;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: margin,
        build: (context) {
          if (size == InvoiceSize.thermal) {
            return _buildThermalReceipt(invoice, profile, currencyFormat, logoImage);
          } else {
            return _buildStandardDocument(invoice, profile, currencyFormat, size, logoImage);
          }
        },
      ),
    );

    return pdf.save();
  }

  // ─── Standard A4 / A5 ────────────────────────────────────────────────────
  static List<pw.Widget> _buildStandardDocument(
    Invoice invoice,
    BusinessProfile? profile,
    NumberFormat format,
    InvoiceSize size,
    pw.ImageProvider? logo,
  ) {
    final double titleFontSize = size == InvoiceSize.a5 ? 20 : 24;
    final accent = _accentColor(invoice.type);

    return [
      _buildHeader(invoice, profile, titleFontSize, accent, logo),
      pw.SizedBox(height: 0.8 * PdfPageFormat.cm),
      _buildDocumentTitle(invoice, titleFontSize, accent),
      _buildDocumentInfo(invoice, accent),
      pw.SizedBox(height: 0.8 * PdfPageFormat.cm),
      _buildTable(invoice, format, size, accent),
      pw.SizedBox(height: 0.5 * PdfPageFormat.cm),
      _buildTotals(invoice, format, accent),
      pw.Divider(color: accent),
      _buildFooter(invoice, profile, accent),
    ];
  }

  // ─── Header with logo ────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
    Invoice invoice,
    BusinessProfile? profile,
    double fontSize,
    PdfColor accent,
    pw.ImageProvider? logo,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo or business name block
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.Container(
                height: 60,
                width: 60,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 10),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  profile?.name ?? 'My Business',
                  style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: accent),
                ),
                if (profile?.category != null)
                  pw.Text(profile!.category!, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                if (profile?.location != null)
                  pw.Text(profile!.location!, style: const pw.TextStyle(fontSize: 11)),
                if (profile?.phone != null)
                  pw.Text('Tel: ${profile!.phone}', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        // QR code
        pw.Container(
          height: 55,
          width: 55,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: invoice.invoiceNumber,
          ),
        ),
      ],
    );
  }

  // ─── Document title bar ──────────────────────────────────────────────────
  static pw.Widget _buildDocumentTitle(Invoice invoice, double fontSize, PdfColor accent) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(
        invoice.type.name.toUpperCase(),
        style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  // ─── Invoice info (billed to / ref) ─────────────────────────────────────
  static pw.Widget _buildDocumentInfo(Invoice invoice, PdfColor accent) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_billedToLabel(invoice.type),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accent)),
              pw.Text(invoice.clientName, style: const pw.TextStyle(fontSize: 12)),
              if (invoice.clientPhone.isNotEmpty)
                pw.Text(invoice.clientPhone, style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${_docRefLabel(invoice.type)} ${invoice.invoiceNumber}',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Date: ${DateFormat.yMd().format(invoice.issueDate)}',
                  style: const pw.TextStyle(fontSize: 12)),
              if (invoice.paymentOption != null)
                pw.Text('Payment: ${invoice.paymentOption}', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Items table ─────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
      Invoice invoice, NumberFormat format, InvoiceSize size, PdfColor accent) {
    final headers = ['Description', 'Qty', 'Unit Price', 'Total'];
    final data = invoice.items.map((item) => [
      item.description,
      '${item.quantity}',
      format.format(item.unitPrice),
      format.format(item.total),
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: accent),
      cellHeight: size == InvoiceSize.a5 ? 20 : 30,
      cellStyle: const pw.TextStyle(fontSize: 11),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
    );
  }

  // ─── Totals block ────────────────────────────────────────────────────────
  static pw.Widget _buildTotals(Invoice invoice, NumberFormat format, PdfColor accent) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Subtotal:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (invoice.discount > 0)
                pw.Text(invoice.returnAdjustment ? 'Returned items:' : 'Discount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(_amountLabel(invoice.type),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: accent)),
            ],
          ),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(format.format(invoice.subtotal)),
              if (invoice.discount > 0)
                pw.Text('-${format.format(invoice.discount)}',
                    style: const pw.TextStyle(color: PdfColors.red)),
              pw.SizedBox(height: 8),
              pw.Text(format.format(invoice.finalTotal),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: accent)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(Invoice invoice, BusinessProfile? profile, PdfColor accent) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (profile?.localPaymentDetails != null) ...[
          pw.Text('Payment Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accent)),
          pw.SizedBox(height: 4),
          pw.Text(profile!.localPaymentDetails!, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),
        ],
        if (profile != null) ...[
          pw.Text('Contact:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accent)),
          if (profile.phone != null) pw.Text('Phone: ${profile.phone}', style: const pw.TextStyle(fontSize: 11)),
          if (profile.email != null) pw.Text('Email: ${profile.email}', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),
        ],
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accent)),
          pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),
        ],
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('Powered by ARODesk', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
        pw.Center(
          child: pw.Text(
            _footerMessage(invoice.type),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 12, color: accent),
          ),
        ),
      ],
    );
  }

  // ─── Thermal Receipt ─────────────────────────────────────────────────────
  static List<pw.Widget> _buildThermalReceipt(
    Invoice invoice,
    BusinessProfile? profile,
    NumberFormat format,
    pw.ImageProvider? logo,
  ) {
    final accent = _accentColor(invoice.type);

    return [
      // Logo
      if (logo != null) ...[
        pw.Center(
          child: pw.Container(height: 45, width: 45, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        ),
        pw.SizedBox(height: 4),
      ],
      pw.Center(
        child: pw.Text(
          profile?.name ?? 'My Business',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent),
          textAlign: pw.TextAlign.center,
        ),
      ),
      pw.SizedBox(height: 2),
      if (profile?.location != null)
        pw.Center(child: pw.Text(profile!.location!, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
      if (profile?.phone != null)
        pw.Center(child: pw.Text('Tel: ${profile!.phone}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
      pw.Divider(borderStyle: pw.BorderStyle.dashed, color: accent),
      pw.Center(
        child: pw.Text(
          invoice.type.name.toUpperCase(),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent),
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(invoice.issueDate)}', style: const pw.TextStyle(fontSize: 9)),
      ]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(child: pw.Text('${_docRefLabel(invoice.type)} ${invoice.invoiceNumber}', softWrap: true, style: const pw.TextStyle(fontSize: 9))),
      ]),
      if (invoice.clientName.isNotEmpty)
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(child: pw.Text('${_billedToLabel(invoice.type)} ${invoice.clientName}', softWrap: true, style: const pw.TextStyle(fontSize: 9))),
        ]),
      pw.Divider(borderStyle: pw.BorderStyle.dashed, color: accent),
      // Items header
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(flex: 2, child: pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
      ]),
      pw.SizedBox(height: 3),
      ...invoice.items.map((item) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(flex: 2, child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(flex: 2, child: pw.Text(format.format(item.total), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      )),
      pw.Divider(borderStyle: pw.BorderStyle.dashed, color: accent),
      if (invoice.discount > 0) ...[
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(child: pw.Text(format.format(invoice.subtotal), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(invoice.returnAdjustment ? 'Returns' : 'Discount', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(child: pw.Text('-${format.format(invoice.discount)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9, color: PdfColors.red))),
        ]),
      ],
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(_amountLabel(invoice.type), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent)),
        pw.Expanded(child: pw.Text(format.format(invoice.finalTotal), textAlign: pw.TextAlign.right, softWrap: true, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent))),
      ]),
      if (invoice.paymentOption != null) ...[
        pw.SizedBox(height: 3),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Payment:', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(child: pw.Text(invoice.paymentOption!, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ]),
      ],
      pw.Divider(borderStyle: pw.BorderStyle.dashed, color: accent),
      pw.Center(child: pw.Text(_thermalFooter(invoice.type), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: accent))),
      pw.SizedBox(height: 8),
      pw.Center(child: pw.Text('Powered by ARODesk', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600))),
      pw.SizedBox(height: 12),
      pw.Center(
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: invoice.invoiceNumber,
          width: 100,
          height: 28,
        ),
      ),
    ];
  }
}
