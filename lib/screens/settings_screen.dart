import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/business_profile.dart';
import '../services/data_service.dart';
import '../services/country_currency.dart';
import '../services/inventory_service.dart';
import 'password_security_screen.dart';
import 'team_screen.dart';

class SettingsScreen extends StatefulWidget{
  const SettingsScreen({super.key,this.onSaved});
  final VoidCallback? onSaved;
  @override State<SettingsScreen> createState()=>_SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen>{
  late final TextEditingController _name,_location,_phone,_email,_payment;
  String _category='Other',_currency='USD';
  String? _country,_logo;
  bool _saving=false;
  int _section=0;
  static const categories=[
    'Retail Shop','Wholesale','Manufacturing','Restaurant & Food',
    'Hotel & Accommodation','Salon & Beauty','Pharmacy & Health',
    'Electronics & Gadgets','Clothing & Fashion','Hardware & Construction',
    'Transport & Logistics','Agriculture & Farming','Education & Training',
    'Technology & IT Services','Printing & Stationery','Events & Entertainment',
    'Real Estate','Consultancy & Professional Services',
    'General Merchandise','Other',
  ];
  @override void initState(){
    super.initState();
    final p=DataService().currentProfile;
    _name=TextEditingController(text:p?.name??'');
    _location=TextEditingController(text:p?.location??'');
    _phone=TextEditingController(text:p?.phone??'');
    _email=TextEditingController(text:p?.email??'');
    _payment=TextEditingController(text:p?.localPaymentDetails??'');
    _category=categories.contains(p?.category)?p!.category!:'Other';
    _country=p?.countryCode;
    _currency=p?.currencyCode??CountryCurrency.currency(_country);
    _logo=p?.logoPath;
  }
  @override void dispose(){
    _name.dispose();_location.dispose();_phone.dispose();_email.dispose();_payment.dispose();
    super.dispose();
  }
  Future<void> _chooseLogo()async{
    final result=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:85);
    if(result!=null&&mounted)setState(()=>_logo=result.path);
  }
  Future<void> _save()async{
    if(_saving)return;
    if(_name.text.trim().length<2){
      setState(()=>_section=0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a valid business name.')));
      return;
    }
    setState(()=>_saving=true);
    try{
      await InventoryService.instance.updateBusinessSettings(
        countryCode:_country,currencyCode:_currency);
      final p=DataService().currentProfile;
      await DataService().saveProfile(BusinessProfile(
        name:_name.text.trim(),category:_category,location:_location.text.trim(),
        phone:_phone.text.trim(),email:_email.text.trim(),
        localPaymentDetails:_payment.text.trim(),
        logoPath:_logo,countryCode:_country,currencyCode:_currency,
        servicesOffered:p?.servicesOffered??[],
      ));
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Business settings saved successfully.')));
      widget.onSaved?.call();
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Unable to save business settings. Check permissions and internet.')));
    }finally{if(mounted)setState(()=>_saving=false);}
  }
  Widget _field(TextEditingController c,String label,{TextInputType? type,int lines=1})=>
    Padding(padding:const EdgeInsets.only(bottom:14),
      child:TextField(controller:c,keyboardType:type,maxLines:lines,
        decoration:InputDecoration(labelText:label,
          border:const OutlineInputBorder())));
  Widget _business()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Center(child:Column(children:[
      InkWell(onTap:_chooseLogo,borderRadius:BorderRadius.circular(56),
        child:CircleAvatar(radius:48,
          backgroundImage:_logo==null?null:FileImage(File(_logo!)),
          child:_logo==null?const Icon(Icons.add_a_photo_outlined,size:34):null)),
      const SizedBox(height:8),
      const Text('Business logo · Tap to change'),
    ])),
    const SizedBox(height:22),
    _field(_name,'Business name *'),
    DropdownButtonFormField<String>(
      value:_category,isExpanded:true,
      decoration:const InputDecoration(labelText:'Industry',border:OutlineInputBorder()),
      items:categories.map((x)=>DropdownMenuItem(value:x,
        child:Text(x,overflow:TextOverflow.ellipsis))).toList(),
      onChanged:(v)=>setState(()=>_category=v??'Other')),
    const SizedBox(height:14),
    _field(_location,'Business address'),
    _field(_phone,'Business phone',type:TextInputType.phone),
    _field(_email,'Business contact email',type:TextInputType.emailAddress),
    DropdownButtonFormField<String>(
      value:CountryCurrency.countries.containsKey(_country)?_country:null,
      isExpanded:true,
      decoration:const InputDecoration(labelText:'Country',border:OutlineInputBorder()),
      items:(CountryCurrency.countries.entries.toList()
        ..sort((a,b)=>a.value.compareTo(b.value)))
        .map((e)=>DropdownMenuItem(value:e.key,
          child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),
      onChanged:(v)=>setState((){
        _country=v;
        _currency=CountryCurrency.currency(v);
      })),
    const SizedBox(height:14),
    DropdownButtonFormField<String>(
      value:CountryCurrency.currencies.contains(_currency)?_currency:'USD',
      decoration:const InputDecoration(labelText:'Preferred currency',border:OutlineInputBorder()),
      items:CountryCurrency.currencies.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
      onChanged:(v)=>setState(()=>_currency=v??'USD')),
    const SizedBox(height:8),
    const Text('Changing currency preference does not convert historical transactions or product prices.'),
  ]);
  Widget _payments()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text('Payment information',style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:8),
    const Text('These details can appear on standalone documents. POS payments are entered in Sales & POS.'),
    const SizedBox(height:20),
    _field(_payment,'Payment instructions / Mobile Money / bank details',lines:4),
  ]);
  Widget _security()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text('Account & access',style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:12),
    Card(child:ListTile(
      leading:const Icon(Icons.lock_outline),
      title:const Text('Change password'),
      subtitle:const Text('Verify your current password and set a new one'),
      trailing:const Icon(Icons.chevron_right),
      onTap:()=>Navigator.push(context,MaterialPageRoute(
        builder:(_)=>const PasswordSecurityScreen())),
    )),
    Card(child:ListTile(
      leading:const Icon(Icons.manage_accounts_outlined),
      title:const Text('Team & permissions'),
      subtitle:const Text('Business owner, administrators, staff, and viewers'),
      trailing:const Icon(Icons.chevron_right),
      onTap:()=>Navigator.push(context,MaterialPageRoute(
        builder:(_)=>const TeamScreen())),
    )),
    const SizedBox(height:14),
    const Text('Products and services are managed in Products & Inventory, not in Settings.'),
  ]);
  @override Widget build(BuildContext context)=>Scaffold(
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:650),
      child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,16,16,10),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Settings',style:Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height:6),
            const Text('Business identity, payments, and security'),
            const SizedBox(height:14),
            SegmentedButton<int>(
              segments:const [
                ButtonSegment(value:0,label:Text('Business'),icon:Icon(Icons.store_outlined)),
                ButtonSegment(value:1,label:Text('Payments'),icon:Icon(Icons.payments_outlined)),
                ButtonSegment(value:2,label:Text('Security'),icon:Icon(Icons.security_outlined)),
              ],selected:{_section},onSelectionChanged:(v)=>setState(()=>_section=v.first)),
          ])),
        Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,16),children:[
          if(_section==0)_business(),
          if(_section==1)_payments(),
          if(_section==2)_security(),
        ])),
        if(_section!=2)Padding(padding:const EdgeInsets.all(16),
          child:SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:_saving?null:_save,
            icon:const Icon(Icons.save_outlined),
            label:Text(_saving?'Saving...':'Save settings')))),
      ]),
    ))),
  );
}
