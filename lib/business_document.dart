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
  List<DocTemplate> get layouts => switch(this) {
    invoice => [DocTemplate.modern,DocTemplate.executive,DocTemplate.minimal],
    receipt => [DocTemplate.compact,DocTemplate.elegant,DocTemplate.minimal],
    quotation => [DocTemplate.elegant,DocTemplate.modern,DocTemplate.executive],
    proforma => [DocTemplate.classic,DocTemplate.executive,DocTemplate.modern],
    purchaseOrder => [DocTemplate.classic,DocTemplate.compact,DocTemplate.executive],
    deliveryNote => [DocTemplate.minimal,DocTemplate.classic,DocTemplate.compact],
    creditNote => [DocTemplate.classic,DocTemplate.modern,DocTemplate.minimal],
    debitNote => [DocTemplate.executive,DocTemplate.classic,DocTemplate.modern],
    paymentVoucher => [DocTemplate.compact,DocTemplate.classic,DocTemplate.executive],
    statement => [DocTemplate.minimal,DocTemplate.modern,DocTemplate.classic],
    letter => [DocTemplate.elegant,DocTemplate.minimal,DocTemplate.classic],
  };
  String get contentTitle => switch(this){
    receipt||paymentVoucher=>'Payment details',letter=>'Letter content',
    statement=>'Transactions',deliveryNote=>'Goods delivered',purchaseOrder=>'Items to order',
    creditNote=>'Credit items',debitNote=>'Debit items',_=>'Items and services',
  };
  String get termsLabel => switch(this){
    invoice=>'Payment terms / due date',receipt||paymentVoucher=>'Payment method',
    quotation=>'Quotation validity',proforma=>'Payment and delivery terms',
    purchaseOrder=>'Requested delivery date / terms',deliveryNote=>'Delivery address / instructions',
    creditNote=>'Reason for credit',debitNote=>'Reason for debit',statement=>'Statement period',letter=>'',
  };
  bool get canLink => this==receipt||this==creditNote||this==debitNote||this==deliveryNote||this==paymentVoucher||this==invoice;
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

const currencies = ['USD','EUR','GBP','UGX','KES','TZS','NGN','ZAR','INR','CAD','AUD','JPY','RWF','GHS','AED','CNY','CHF','NZD','BRL','MXN','SAR','SGD','HKD','KRW','PHP','IDR','MYR','PKR','BDT','EGP','ETB','ZMW','SEK','NOK','DKK','PLN','TRY','QAR','KWD','BHD','OMR','JOD','VND','XOF','XAF','THB','ILS','COP','CLP','PEN','MAD'];
int currencyDecimals(String currency) => ['UGX','JPY','RWF','KRW','VND','XOF','XAF','CLP'].contains(currency) ? 0 : ['KWD','BHD','OMR','JOD'].contains(currency) ? 3 : 2;
int minorFactor(String currency) => switch(currencyDecimals(currency)){0=>1,3=>1000,_=>100};
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

enum DocTemplate {
  modern('Modern', 'Balanced header and accent rule'),
  classic('Classic', 'Traditional ruled business form'),
  executive('Executive', 'Full-width branded heading'),
  minimal('Minimal', 'Light, ink-saving layout'),
  elegant('Elegant', 'Centered letterhead and refined accents'),
  compact('Compact', 'Dense commercial document');

  const DocTemplate(this.title,this.description);
  final String title,description;
}
enum DocPaper { a4, letter, a5 }
enum DocDate {
  dayFirst('24/11/2026','dd/MM/yyyy'),
  monthFirst('11/24/2026','MM/dd/yyyy'),
  iso('2026-11-24','yyyy-MM-dd'),
  written('24 Nov 2026','dd MMM yyyy');
  const DocDate(this.example,this.pattern);
  final String example,pattern;
}
String validHex(Object? value,String fallback) {
  final s=value?.toString().replaceAll('#','').trim().toUpperCase()??'';
  return RegExp(r'^[0-9A-F]{6}$').hasMatch(s)?s:fallback;
}
class DocStyle {
  const DocStyle({this.template=DocTemplate.modern,this.paper=DocPaper.a4,
    this.dateFormat=DocDate.written,this.primary='196B74',this.secondary='152D45',
    this.logo='',this.footer='',this.taxLabel='Tax'});
  final DocTemplate template;
  final DocPaper paper;
  final DocDate dateFormat;
  final String primary,secondary,logo,footer,taxLabel;
  DocStyle copyWith({DocTemplate? template,DocPaper? paper,DocDate? dateFormat,
    String? primary,String? secondary,String? logo,String? footer,String? taxLabel})=>DocStyle(
      template:template??this.template,paper:paper??this.paper,dateFormat:dateFormat??this.dateFormat,
      primary:primary??this.primary,secondary:secondary??this.secondary,logo:logo??this.logo,
      footer:footer??this.footer,taxLabel:taxLabel??this.taxLabel);
  Map<String,dynamic> toJson()=>{'template':template.name,'paper':paper.name,'dateFormat':dateFormat.name,
    'primary':primary,'secondary':secondary,'logo':logo,'footer':footer,'taxLabel':taxLabel};
  factory DocStyle.fromJson(Map<String,dynamic> j)=>DocStyle(
    template:DocTemplate.values.firstWhere((v)=>v.name==j['template'],orElse:()=>DocTemplate.modern),
    paper:DocPaper.values.firstWhere((v)=>v.name==j['paper'],orElse:()=>DocPaper.a4),
    dateFormat:DocDate.values.firstWhere((v)=>v.name==j['dateFormat'],orElse:()=>DocDate.written),
    primary:validHex(j['primary'],'196B74'),secondary:validHex(j['secondary'],'152D45'),
    logo:j['logo'] as String? ?? '',footer:j['footer'] as String? ?? '',taxLabel:j['taxLabel'] as String? ?? 'Tax');
}

class BusinessInfo {
  const BusinessInfo({this.name='',this.contact='',this.address='',this.taxId='',this.currency='USD',this.style=const DocStyle()});
  final String name, contact, address, taxId, currency;
  final DocStyle style;
  Map<String,dynamic> toJson() => {'name':name,'contact':contact,'address':address,'taxId':taxId,'currency':currency,'style':style.toJson()};
  factory BusinessInfo.fromJson(Map<String,dynamic> json) => BusinessInfo(
    name: json['name'] as String? ?? '', contact: json['contact'] as String? ?? '',
    address: json['address'] as String? ?? '', taxId: json['taxId'] as String? ?? '',
    currency: currencies.contains(json['currency']) ? json['currency'] as String : 'USD',
    style:DocStyle.fromJson(Map<String,dynamic>.from(json['style'] as Map? ?? {})),
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
