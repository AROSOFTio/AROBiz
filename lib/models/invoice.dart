enum DocumentType { invoice, quotation, receipt }

extension DocumentTypeExtension on DocumentType {
  String get name {
    switch (this) {
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.quotation:
        return 'Quotation';
      case DocumentType.receipt:
        return 'Receipt';
    }
  }
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description'],
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final DateTime issueDate;
  final String clientName;
  final String clientPhone;
  final List<InvoiceItem> items;
  final double discount;
  final double taxRate;
  final String? notes;
  final String? paymentOption;
  final DocumentType type;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.clientName,
    required this.clientPhone,
    required this.items,
    this.discount = 0.0,
    this.taxRate = 0.0,
    this.notes,
    this.paymentOption,
    this.type = DocumentType.invoice,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get taxAmount => (subtotal - discount) * taxRate;
  double get finalTotal => (subtotal - discount) + taxAmount;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      invoiceNumber: json['invoiceNumber'],
      issueDate: DateTime.parse(json['issueDate']),
      clientName: json['clientName'],
      clientPhone: json['clientPhone'],
      items: (json['items'] as List)
          .map((i) => InvoiceItem.fromJson(i))
          .toList(),
      discount: (json['discount'] ?? 0).toDouble(),
      taxRate: (json['taxRate'] ?? 0).toDouble(),
      notes: json['notes'],
      paymentOption: json['paymentOption'],
      type: DocumentType.values.firstWhere(
        (e) => e.toString() == 'DocumentType.${json['type']}',
        orElse: () => DocumentType.invoice, // Default for older invoices
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'issueDate': issueDate.toIso8601String(),
      'clientName': clientName,
      'clientPhone': clientPhone,
      'items': items.map((i) => i.toJson()).toList(),
      'discount': discount,
      'taxRate': taxRate,
      'notes': notes,
      'paymentOption': paymentOption,
      'type': type.name.toLowerCase(),
    };
  }
}
