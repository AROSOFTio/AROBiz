import 'package:flutter_test/flutter_test.dart';
import 'package:arosoft/services/country_currency.dart';

void main() {
  test('business country presets retain expected currency codes', () {
    expect(CountryCurrency.countries['UG'], 'Uganda');
    expect(CountryCurrency.byCountry['UG'], 'UGX');
    expect(CountryCurrency.byCountry['KE'], 'KES');
    expect(CountryCurrency.byCountry['US'], 'USD');
    expect(CountryCurrency.byCountry['GB'], 'GBP');
  });
}
