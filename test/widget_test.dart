import 'package:flutter_test/flutter_test.dart';
import 'package:arosoft/models/invoice.dart';

void main() {
  test('invoice, quotation and receipt document types are available', () {
    expect(DocumentType.values, containsAll([
      DocumentType.invoice,
      DocumentType.quotation,
      DocumentType.receipt,
    ]));
  });

  test('currency is preserved when documents are saved and read', () {
    final invoice = Invoice(
      id: 'currency-test',
      invoiceNumber: 'INV-2',
      issueDate: DateTime(2026, 10, 10),
      clientName: 'Global Customer',
      clientPhone: '',
      currency: 'EUR',
      items: [InvoiceItem(description: 'Consulting', quantity: 1, unitPrice: 50)],
    );
    expect(Invoice.fromJson(invoice.toJson()).currency, 'EUR');
  });

  test('document subtotal, discounts and tax are calculated', () {
    final invoice = Invoice(
      id: 'test-id',
      invoiceNumber: 'INV-TEST',
      issueDate: DateTime(2026, 10, 10),
      clientName: 'Example Client',
      clientPhone: '',
      items: [InvoiceItem(description: 'Service', quantity: 2, unitPrice: 100)],
      discount: 20,
      taxRate: 0.18,
    );
    expect(invoice.subtotal, 200);
    expect(invoice.taxAmount, closeTo(32.4, 0.001));
    expect(invoice.finalTotal, closeTo(212.4, 0.001));
    expect(Invoice.fromJson(invoice.toJson()).finalTotal, closeTo(212.4, 0.001));
  });
}
