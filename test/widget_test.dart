import 'package:flutter_test/flutter_test.dart';
import 'package:arosoft/models/business_profile.dart';

void main() {
  group('ARODesk business profile model', () {
    test('stores business identity and services without losing fields', () {
      final profile = BusinessProfile(
        name: 'Example Manufacturing',
        category: 'Manufacturing',
        location: 'Kampala',
        email: 'owner@example.com',
        servicesOffered: const ['Production', 'Packaging'],
      );

      final restored = BusinessProfile.fromJson(profile.toJson());
      expect(restored.name, 'Example Manufacturing');
      expect(restored.category, 'Manufacturing');
      expect(restored.location, 'Kampala');
      expect(restored.email, 'owner@example.com');
      expect(restored.servicesOffered, ['Production', 'Packaging']);
    });

    test('maintains compatibility with legacy comma-separated services', () {
      final restored = BusinessProfile.fromJson({
        'name': 'Example Services',
        'servicesOffered': 'Consulting, Repairs, ',
      });
      expect(restored.servicesOffered, ['Consulting', 'Repairs']);
    });

    test('copies business profile while retaining existing values', () {
      final profile = BusinessProfile(name: 'Original', category: 'Retail Shop');
      final edited = profile.copyWith(name: 'Updated');
      expect(edited.name, 'Updated');
      expect(edited.category, 'Retail Shop');
    });
  });
}
