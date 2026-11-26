import 'package:flutter_test/flutter_test.dart';
import 'package:arosoft/services/country_currency.dart';
import 'package:arosoft/services/offline_sales_service.dart';
import 'package:arosoft/services/accounting_service.dart';

void main() {
  test('valid full, split and credit payments are accepted', () {
    expect(OfflineSalesService.validateSalePayments(100, [
      {'method':'Cash','amount':60}, {'method':'Mobile Money','amount':40}
    ]), 100);
    expect(OfflineSalesService.validateSalePayments(100, []), 0);
  });
  test('invalid and excessive payments are rejected', () {
    for (final value in [-1.0,double.nan,double.infinity,1.001]) {
      expect(()=>OfflineSalesService.validateSalePayments(100,[{'method':'Cash','amount':value}]),throwsArgumentError);
    }
    expect(()=>OfflineSalesService.validateSalePayments(100,[{'method':'Cash','amount':100.01}]),throwsStateError);
    expect(()=>OfflineSalesService.validateSalePayments(100,[{'method':'Unknown','amount':1}]),throwsArgumentError);
  });
  test('trial balance totals aggregate double-entry sale and inventory correctly', () {
    final totals=AccountingService.instance.trialBalance([
      {'account_code':'1000','debit':100,'credit':0},
      {'account_code':'4000','debit':0,'credit':100},
      {'account_code':'5000','debit':60,'credit':0},
      {'account_code':'1200','debit':0,'credit':60},
    ]);
    expect(totals['1000']?['debit'],100);
    expect(totals.values.fold<double>(0,(sum,v)=>sum+v['debit']!),160);
    expect(totals.values.fold<double>(0,(sum,v)=>sum+v['credit']!),160);
  });
  test('business country presets retain expected currency codes', () {
    expect(CountryCurrency.countries['UG'], 'Uganda');
    expect(CountryCurrency.byCountry['UG'], 'UGX');
    expect(CountryCurrency.byCountry['KE'], 'KES');
    expect(CountryCurrency.byCountry['US'], 'USD');
    expect(CountryCurrency.byCountry['GB'], 'GBP');
  });
}
