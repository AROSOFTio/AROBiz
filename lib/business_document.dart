import 'package:intl/intl.dart';

enum DocKind {
  invoice('Invoice', 'INV', 'Bill a customer'),
  receipt('Receipt', 'REC', 'Record payment received'),
  quotation('Quotation', 'QUO', 'Send a price estimate'),
  proforma('Proforma Invoice', 'PRO', 'Issue a preliminary invoice'),
  purchaseOrder('Purchase Order', 'PO', 'Order goods or services'),
  deliveryNote('Delivery Note', 'DN', 'Record goods delivered'),
  creditNote('Credit Note', 'CN', 'Record a credit or refund'),
  debitNote('Debit Note', 'DBN', 'Record a debit adjustment'),
  paymentVoucher('Payment Voucher', 'PV', 'Record an outgoing payment'),
  statement('Account Statement', 'ST', 'Summarize account transactions'),
  letter('Business Letter', 'LTR', 'Create professional correspondence');

  const DocKind(this.title, this.prefix, this.description);
  final String title, prefix, description;
  bool get isLetter => this == letter;
  bool get isStatement => this == statement;
  bool get hasPrices => this != deliveryNote && !isLetter && !isStatement;
  bool get hasTax => hasPrices && this != receipt && this != paymentVoucher;
  String get partyLabel => switch (this) {
    receipt => 'Received from',
    paymentVoucher => 'Paid to',
    purchaseOrder => 'Supplier',
    deliveryNote => 'Delivered to',
    quotation || proforma => 'Prepared for',
    letter => 'Recipient',
    _ => 'Customer / client',
  };
  String get totalLabel => switch (this) {
    receipt => 'Amount received',
    paymentVoucher => 'Amount paid',
    quotation || proforma => 'Estimated total',
    creditNote => 'Credit amount',
    debitNote => 'Debit amount',
    statement => 'Closing balance',
    purchaseOrder => 'Order total',
    _ => 'Total',
  };
}

const currencies = ['USD','EUR','GBP','UGX','KES','TZS','NGN','ZAR','INR','CAD','AUD','JPY','RWF','GHS','AED'];
int currencyDecimals(String currency) => ['UGX','JPY','RWF'].contains(currency) ? 0 : 2;
int minorFactor(String currency) => currencyDecimals(currency) == 0 ? 1 : 100;
int toMinor(double number, String currency) => (number * minorFactor(currency)).round();
String money(int minor, String currency) => NumberFormat.currency(
  name: currency, symbol: '$currency ', decimalDigits: currencyDecimals(currency),
).format(minor / minorFactor(currency));

class DocLine {
  const DocLine({required this.description, this.quantity = 1, this.price = 0, this.credit = 0});
  final String description;
  final double quantity, price, credit;
  int total(String currency) => toMinor(quantity * price, currency);
  Map<String,dynamic> toJson() => {'description': description,'quantity':quantity,'price':price,'credit':credit};
  factory DocLine.fromJson(Map<String,dynamic> json) => DocLine(
    description: json['description'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    price: (json['price'] as num).toDouble(),
    credit: (json['credit'] as num? ?? 0).toDouble(),
  );
}

class BusinessInfo {
  const BusinessInfo({this.name='',this.contact='',this.address='',this.taxId='',this.currency='USD'});
  final String name, contact, address, taxId, currency;
  Map<String,dynamic> toJson() => {'name':name,'contact':contact,'address':address,'taxId':taxId,'currency':currency};
  factory BusinessInfo.fromJson(Map<String,dynamic> json) => BusinessInfo(
    name: json['name'] as String? ?? '', contact: json['contact'] as String? ?? '',
    address: json['address'] as String? ?? '', taxId: json['taxId'] as String? ?? '',
    currency: currencies.contains(json['currency']) ? json['currency'] as String : 'USD',
  );
}

class BusinessDocument {
  const BusinessDocument({required this.id,required this.kind,required this.number,
    required this.date,required this.business,required this.party,required this.partyContact,
    required this.currency,required this.lines,this.tax=0,this.discount=0,this.opening=0,
    this.reference='',this.terms='',this.subject='',this.notes=''});
  final String id, number, party, partyContact, currency, reference, terms, subject, notes;
  final DocKind kind;
  final DateTime date;
  final BusinessInfo business;
  final List<DocLine> lines;
  final double tax, discount, opening;
  int get subtotal => lines.fold<int>(0, (sum,line)=>sum+line.total(currency));
  int get discountMinor => kind.hasTax ? toMinor(discount,currency) : 0;
  int get taxMinor => kind.hasTax ? ((subtotal-discountMinor)*tax/100).round() : 0;
  int get debitTotal => lines.fold<int>(0,(sum,line)=>sum+toMinor(line.price,currency));
  int get creditTotal => lines.fold<int>(0,(sum,line)=>sum+toMinor(line.credit,currency));
  int get total => kind.isStatement ? toMinor(opening,currency)+debitTotal-creditTotal :
    subtotal-discountMinor+taxMinor;
  Map<String,dynamic> toJson() => {
    'id':id,'kind':kind.name,'number':number,'date':date.toIso8601String(),
    'business':business.toJson(),'party':party,'partyContact':partyContact,
    'currency':currency,'lines':lines.map((line)=>line.toJson()).toList(),
    'tax':tax,'discount':discount,'opening':opening,'reference':reference,'terms':terms,
    'subject':subject,'notes':notes,
  };
  factory BusinessDocument.fromJson(Map<String,dynamic> json) => BusinessDocument(
    id:json['id'] as String,kind:DocKind.values.byName(json['kind'] as String),
    number:json['number'] as String,date:DateTime.parse(json['date'] as String),
    business:BusinessInfo.fromJson(Map<String,dynamic>.from(json['business'] as Map)),
    party:json['party'] as String,partyContact:json['partyContact'] as String,
    currency:json['currency'] as String,
    lines:(json['lines'] as List).map((line)=>DocLine.fromJson(Map<String,dynamic>.from(line as Map))).toList(),
    tax:(json['tax'] as num).toDouble(),discount:(json['discount'] as num).toDouble(),
    opening:(json['opening'] as num? ?? 0).toDouble(),
    reference:json['reference'] as String,terms:json['terms'] as String,
    subject:json['subject'] as String? ?? '',notes:json['notes'] as String,
  );
}
