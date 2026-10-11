import 'package:intl/intl.dart';

/// Country selection sets a default currency; choosing another display currency
/// does not convert amounts or change historical transaction currencies.
class CountryCurrency {
  static const countries=<String,String>{
    'AF':'Afghanistan','AL':'Albania','DZ':'Algeria','AO':'Angola','AR':'Argentina',
    'AM':'Armenia','AU':'Australia','AT':'Austria','AZ':'Azerbaijan','BH':'Bahrain',
    'BD':'Bangladesh','BE':'Belgium','BJ':'Benin','BW':'Botswana','BR':'Brazil',
    'BG':'Bulgaria','BF':'Burkina Faso','BI':'Burundi','KH':'Cambodia','CM':'Cameroon',
    'CA':'Canada','CF':'Central African Republic','TD':'Chad','CL':'Chile',
    'CN':'China','CO':'Colombia','CD':'DR Congo','CG':'Republic of Congo',
    'CR':'Costa Rica','CI':'Côte d’Ivoire','HR':'Croatia','CY':'Cyprus',
    'CZ':'Czechia','DK':'Denmark','DJ':'Djibouti','DO':'Dominican Republic',
    'EC':'Ecuador','EG':'Egypt','SV':'El Salvador','ER':'Eritrea','EE':'Estonia',
    'SZ':'Eswatini','ET':'Ethiopia','FJ':'Fiji','FI':'Finland','FR':'France',
    'GA':'Gabon','GM':'Gambia','GE':'Georgia','DE':'Germany','GH':'Ghana',
    'GR':'Greece','GT':'Guatemala','GN':'Guinea','GW':'Guinea-Bissau',
    'HT':'Haiti','HN':'Honduras','HK':'Hong Kong','HU':'Hungary','IS':'Iceland',
    'IN':'India','ID':'Indonesia','IR':'Iran','IQ':'Iraq','IE':'Ireland',
    'IL':'Israel','IT':'Italy','JM':'Jamaica','JP':'Japan','JO':'Jordan',
    'KZ':'Kazakhstan','KE':'Kenya','KW':'Kuwait','KG':'Kyrgyzstan',
    'LA':'Laos','LV':'Latvia','LB':'Lebanon','LS':'Lesotho','LR':'Liberia',
    'LY':'Libya','LT':'Lithuania','LU':'Luxembourg','MG':'Madagascar',
    'MW':'Malawi','MY':'Malaysia','MV':'Maldives','ML':'Mali','MT':'Malta',
    'MR':'Mauritania','MU':'Mauritius','MX':'Mexico','MD':'Moldova',
    'MN':'Mongolia','ME':'Montenegro','MA':'Morocco','MZ':'Mozambique',
    'MM':'Myanmar','NA':'Namibia','NP':'Nepal','NL':'Netherlands',
    'NZ':'New Zealand','NI':'Nicaragua','NE':'Niger','NG':'Nigeria',
    'NO':'Norway','OM':'Oman','PK':'Pakistan','PA':'Panama','PG':'Papua New Guinea',
    'PY':'Paraguay','PE':'Peru','PH':'Philippines','PL':'Poland',
    'PT':'Portugal','QA':'Qatar','RO':'Romania','RU':'Russia','RW':'Rwanda',
    'SA':'Saudi Arabia','SN':'Senegal','RS':'Serbia','SC':'Seychelles',
    'SL':'Sierra Leone','SG':'Singapore','SK':'Slovakia','SI':'Slovenia',
    'SO':'Somalia','ZA':'South Africa','SS':'South Sudan','ES':'Spain',
    'LK':'Sri Lanka','SD':'Sudan','SE':'Sweden','CH':'Switzerland',
    'SY':'Syria','TW':'Taiwan','TJ':'Tajikistan','TZ':'Tanzania','TH':'Thailand',
    'TL':'Timor-Leste','TG':'Togo','TT':'Trinidad and Tobago','TN':'Tunisia',
    'TR':'Türkiye','TM':'Turkmenistan','UG':'Uganda','UA':'Ukraine',
    'AE':'United Arab Emirates','GB':'United Kingdom','US':'United States',
    'UY':'Uruguay','UZ':'Uzbekistan','VE':'Venezuela','VN':'Vietnam',
    'YE':'Yemen','ZM':'Zambia','ZW':'Zimbabwe'
  };
  static const byCountry=<String,String>{
    'AF':'AFN','AL':'ALL','DZ':'DZD','AO':'AOA','AR':'ARS','AM':'AMD',
    'AU':'AUD','AT':'EUR','AZ':'AZN','BH':'BHD','BD':'BDT','BE':'EUR',
    'BJ':'XOF','BW':'BWP','BR':'BRL','BG':'BGN','BF':'XOF','BI':'BIF',
    'KH':'KHR','CM':'XAF','CA':'CAD','CF':'XAF','TD':'XAF','CL':'CLP',
    'CN':'CNY','CO':'COP','CD':'CDF','CG':'XAF','CR':'CRC','CI':'XOF',
    'HR':'EUR','CY':'EUR','CZ':'CZK','DK':'DKK','DJ':'DJF','DO':'DOP',
    'EC':'USD','EG':'EGP','SV':'USD','ER':'ERN','EE':'EUR','SZ':'SZL',
    'ET':'ETB','FJ':'FJD','FI':'EUR','FR':'EUR','GA':'XAF','GM':'GMD',
    'GE':'GEL','DE':'EUR','GH':'GHS','GR':'EUR','GT':'GTQ','GN':'GNF',
    'GW':'XOF','HT':'HTG','HN':'HNL','HK':'HKD','HU':'HUF','IS':'ISK',
    'IN':'INR','ID':'IDR','IR':'IRR','IQ':'IQD','IE':'EUR','IL':'ILS',
    'IT':'EUR','JM':'JMD','JP':'JPY','JO':'JOD','KZ':'KZT','KE':'KES',
    'KW':'KWD','KG':'KGS','LA':'LAK','LV':'EUR','LB':'LBP','LS':'LSL',
    'LR':'LRD','LY':'LYD','LT':'EUR','LU':'EUR','MG':'MGA','MW':'MWK',
    'MY':'MYR','MV':'MVR','ML':'XOF','MT':'EUR','MR':'MRU','MU':'MUR',
    'MX':'MXN','MD':'MDL','MN':'MNT','ME':'EUR','MA':'MAD','MZ':'MZN',
    'MM':'MMK','NA':'NAD','NP':'NPR','NL':'EUR','NZ':'NZD','NI':'NIO',
    'NE':'XOF','NG':'NGN','NO':'NOK','OM':'OMR','PK':'PKR','PA':'PAB',
    'PG':'PGK','PY':'PYG','PE':'PEN','PH':'PHP','PL':'PLN','PT':'EUR',
    'QA':'QAR','RO':'RON','RU':'RUB','RW':'RWF','SA':'SAR','SN':'XOF',
    'RS':'RSD','SC':'SCR','SL':'SLE','SG':'SGD','SK':'EUR','SI':'EUR',
    'SO':'SOS','ZA':'ZAR','SS':'SSP','ES':'EUR','LK':'LKR','SD':'SDG',
    'SE':'SEK','CH':'CHF','SY':'SYP','TW':'TWD','TJ':'TJS','TZ':'TZS',
    'TH':'THB','TL':'USD','TG':'XOF','TT':'TTD','TN':'TND','TR':'TRY',
    'TM':'TMT','UG':'UGX','UA':'UAH','AE':'AED','GB':'GBP','US':'USD',
    'UY':'UYU','UZ':'UZS','VE':'VES','VN':'VND','YE':'YER','ZM':'ZMW','ZW':'ZWG'
  };
  static String currency(String? country)=>byCountry[country]??'USD';
  static List<String> get currencies=>(byCountry.values.toSet().toList()..sort());
  static String money(num value,String? currencyCode){
    final code=currencyCode??'USD';
    final digits=NumberFormat.decimalPattern().format(value);
    return '$code $digits';
  }
}
