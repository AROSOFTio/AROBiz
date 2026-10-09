
class BusinessProfile {
  final String? name;
  final String currency;
  final String? logoPath;
  final String? location;
  final String? phone;
  final String? email;
  final List<String> servicesOffered;
  final String? category;
  final String? localPaymentDetails;

  BusinessProfile({
    this.name,
    this.currency = 'USD',
    this.logoPath,
    this.location,
    this.phone,
    this.email,
    this.servicesOffered = const [],
    this.category,
    this.localPaymentDetails,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    // Handle both old comma-string format and new list format
    List<String> services = [];
    final raw = json['servicesOffered'];
    if (raw is List) {
      services = List<String>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      // backward compat: split old comma-separated string
      services = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    return BusinessProfile(
      name: json['name'],
      currency: (json['currency'] as String?) ?? 'USD',
      logoPath: json['logoPath'],
      location: json['location'],
      phone: json['phone'],
      email: json['email'],
      servicesOffered: services,
      category: json['category'],
      localPaymentDetails: json['localPaymentDetails'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'currency': currency,
      'logoPath': logoPath,
      'location': location,
      'phone': phone,
      'email': email,
      'servicesOffered': servicesOffered,
      'category': category,
      'localPaymentDetails': localPaymentDetails,
    };
  }

  BusinessProfile copyWith({
    String? name,
    String? currency,
    String? logoPath,
    String? location,
    String? phone,
    String? email,
    List<String>? servicesOffered,
    String? category,
    String? localPaymentDetails,
  }) {
    return BusinessProfile(
      name: name ?? this.name,
      currency: currency ?? this.currency,
      logoPath: logoPath ?? this.logoPath,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      servicesOffered: servicesOffered ?? this.servicesOffered,
      category: category ?? this.category,
      localPaymentDetails: localPaymentDetails ?? this.localPaymentDetails,
    );
  }
}
