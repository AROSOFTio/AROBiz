import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'document_store.dart';
import 'business_document.dart';
import 'document_editor.dart';
import 'design_editor.dart';
import 'cloud_service.dart';

const brand = Color(0xFF171717);
const ink = Color(0xFF171717);
const appName = 'Crown Business Docs';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  cloud=CloudService(prefs);
  recordUsage('app_open');
  runApp(CrownDocsApp(store:DocumentStore(prefs)));
}

class CrownDocsApp extends StatelessWidget {
  const CrownDocsApp({super.key,required this.store});
  final DocumentStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:appName,debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:const ColorScheme.light(primary:Colors.black,onPrimary:Colors.white,secondary:Color(0xFF404040),surface:Colors.white,onSurface:Colors.black),
      scaffoldBackgroundColor:Colors.white,
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),minimumSize:const Size(0,48))),
      outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),minimumSize:const Size(0,48))),
      cardTheme:const CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(side:BorderSide(color:Color(0xFFE5E7EB),width:1),borderRadius:BorderRadius.all(Radius.circular(10)))),
      navigationBarTheme:const NavigationBarThemeData(backgroundColor:Colors.white,indicatorColor:Colors.transparent,elevation:0,height:65,labelTextStyle:WidgetStatePropertyAll(TextStyle(fontSize:11,fontWeight:FontWeight.w600))),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,fillColor:const Color(0xFFFAFAFA),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:16),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:Color(0xFFDADADA))),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:Color(0xFFDADADA))),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:Colors.black,width:1.5)),
        labelStyle:const TextStyle(fontSize:14,color:Color(0xFF555555)),
      ),
      dividerTheme:const DividerThemeData(color:Color(0xFFEAEAEA),thickness:1,space:1),
      appBarTheme:const AppBarTheme(backgroundColor:Colors.white,surfaceTintColor:Colors.transparent,foregroundColor:ink,elevation:0,scrolledUnderElevation:0,centerTitle:false,systemOverlayStyle:SystemUiOverlayStyle.dark),
      splashFactory:InkRipple.splashFactory,
      textTheme:const TextTheme(bodyMedium:TextStyle(height:1.45,fontSize:14),bodySmall:TextStyle(height:1.4,fontSize:12)),

    ),
    home:HomeScreen(store:store),
  );
}

IconData kindIcon(DocKind kind) => switch(kind) {
  DocKind.invoice=>Icons.request_quote_outlined,
  DocKind.receipt=>Icons.receipt_long_outlined,
  DocKind.quotation=>Icons.price_check_outlined,
  DocKind.proforma=>Icons.description_outlined,
  DocKind.purchaseOrder=>Icons.shopping_cart_outlined,
  DocKind.deliveryNote=>Icons.local_shipping_outlined,
  DocKind.creditNote=>Icons.credit_score_outlined,
  DocKind.debitNote=>Icons.note_alt_outlined,
  DocKind.paymentVoucher=>Icons.payments_outlined,
  DocKind.statement=>Icons.summarize_outlined,
  DocKind.letter=>Icons.mail_outline,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key,required this.store});
  final DocumentStore store;
  @override
  State<HomeScreen> createState()=>_HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index=0;
  String query='';
  bool opening=false;
  Future<void> openEditor(DocKind kind,{BusinessDocument? document}) async {
    if(opening)return;
    if(document==null&&widget.store.profile().name.trim().isEmpty){
      setState(()=>index=2);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Save your business details once, then create documents.')));
      return;
    }
    setState(()=>opening=true);
    try{
      final number=document?.number??await widget.store.reserveNumber(kind,DateTime.now());
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>DocumentEditor(store:widget.store,kind:kind,existing:document,assignedNumber:number)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>opening=false);}
    if(mounted) setState((){});
  }
  Future<void> remove(BusinessDocument doc) async {
    final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Delete saved document?'),content:Text(doc.number),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Delete'))]));
    if(yes!=true || !mounted)return;
    try { await widget.store.delete(doc.id); if(mounted)setState((){}); }
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:Row(children:[
      Container(width:34,height:34,decoration:BoxDecoration(color:Colors.black,borderRadius:BorderRadius.circular(8)),child:const Icon(Icons.description_outlined,color:Colors.white,size:21)),
      const SizedBox(width:10),
      const Flexible(child:Text(appName,style:TextStyle(fontWeight:FontWeight.w800,fontSize:18,letterSpacing:-.5))),
    ]),actions:[IconButton(tooltip:'Account & privacy',onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CloudSettings(store:widget.store))),icon:const Icon(Icons.account_circle_outlined,size:27)),const SizedBox(width:6)],
    bottom:const PreferredSize(preferredSize:Size.fromHeight(1),child:Divider())),

    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),
      child:switch(index){0=>home(),1=>saved(),_=>ProfileEditor(store:widget.store,onSaved:()=>setState((){}))},
    ))),
    bottomNavigationBar:DecoratedBox(decoration:const BoxDecoration(border:Border(top:BorderSide(color:Color(0xFFEAEAEA)))),child:NavigationBar(selectedIndex:index,onDestinationSelected:(value)=>setState(()=>index=value),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.folder_outlined),selectedIcon:Icon(Icons.folder),label:'My documents'),
        NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'Settings'),
      ])),
  );
  Widget home(){
    final records=widget.store.documents();
    final profile=widget.store.profile();
    final today=DateTime.now();
    final month=records.where((d)=>d.date.year==today.year&&d.date.month==today.month).length;
    return ListView(padding:const EdgeInsets.fromLTRB(20,22,20,28),children:[
      const Text('WORKSPACE',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,letterSpacing:1.5,color:Colors.black54)),
      const SizedBox(height:7),
      Text(profile.name.isEmpty?'Your business':profile.name,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w800,letterSpacing:-.8)),
      const SizedBox(height:4),
      const Text('Create, save and share your documents.',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:18),
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFFAFAFA),border:Border.all(color:const Color(0xFFE6E6E6)),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Expanded(child:Text('Document activity',style:TextStyle(fontWeight:FontWeight.w700,fontSize:15))),TextButton(onPressed:()=>setState(()=>index=1),child:const Text('View all'))]),
        const SizedBox(height:6),
        Row(children:[
          Expanded(child:metric('Saved documents',records.length,Icons.folder_outlined,const Color(0xFF157347))),
          Container(height:68,width:1,color:const Color(0xFFE0E0E0),margin:const EdgeInsets.symmetric(horizontal:14)),
          Expanded(child:metric('This month',month,Icons.calendar_today_outlined,const Color(0xFF6D28D9))),
        ]),
      ])),
      if(profile.name.isEmpty)...[
        const SizedBox(height:12),
        OutlinedButton.icon(onPressed:()=>setState(()=>index=2),icon:const Icon(Icons.business_outlined),label:const Text('Set up your business details')),
      ],
      const SizedBox(height:27),
      Row(children:[const Expanded(child:Text('Create a document',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,letterSpacing:-.5))),const Icon(Icons.offline_bolt_outlined,color:Color(0xFF157347),size:16),const SizedBox(width:4),const Text('Offline ready',style:TextStyle(color:Color(0xFF157347),fontSize:11,fontWeight:FontWeight.w600))]),
      const SizedBox(height:15),
      toolGroup('Sales & payments',[DocKind.invoice,DocKind.receipt,DocKind.quotation,DocKind.proforma]),
      const SizedBox(height:22),
      toolGroup('Purchasing & adjustments',[DocKind.purchaseOrder,DocKind.deliveryNote,DocKind.creditNote,DocKind.debitNote,DocKind.paymentVoucher]),
      const SizedBox(height:22),
      toolGroup('Records & correspondence',[DocKind.statement,DocKind.letter]),
      if(records.isNotEmpty)...[
        const SizedBox(height:25),
        const Text('Recently saved',style:TextStyle(fontSize:19,fontWeight:FontWeight.w700)),
        const SizedBox(height:10),
        for(final doc in records.take(3)) ListTile(contentPadding:EdgeInsets.zero,leading:Icon(kindIcon(doc.kind),color:kindColor(doc.kind)),title:Text(doc.number,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text(doc.party,maxLines:1,overflow:TextOverflow.ellipsis),trailing:const Icon(Icons.chevron_right),onTap:()=>openEditor(doc.kind,document:doc)),
      ],
    ]);
  }
  Widget toolGroup(String label,List<DocKind> kinds)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:Colors.black54)),
    const SizedBox(height:9),
    LayoutBuilder(builder:(context,box)=>GridView.count(
      shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
      crossAxisCount:box.maxWidth>700?4:box.maxWidth>470?3:2,
      crossAxisSpacing:10,mainAxisSpacing:10,
      mainAxisExtent:MediaQuery.textScalerOf(context).scale(145).clamp(136,240).toDouble(),
      children:kinds.map((kind)=>Material(
        color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9),side:const BorderSide(color:Color(0xFFE2E2E2))),
        child:InkWell(borderRadius:BorderRadius.circular(9),onTap:()=>openEditor(kind),key:Key('create_${kind.name}'),
          child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Icon(kindIcon(kind),color:kindColor(kind),size:26),const Spacer(),const Icon(Icons.arrow_outward,size:16,color:Colors.black38)]),
            const Spacer(),
            Text(kind.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,color:ink,fontSize:14)),
            const SizedBox(height:4),Text(kind.description,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Colors.black54)),
          ])),
        ),
      )).toList(),
    )),
  ]);
  Color kindColor(DocKind k)=>switch(k){
    DocKind.receipt||DocKind.creditNote=>const Color(0xFF157347),
    DocKind.debitNote||DocKind.paymentVoucher=>const Color(0xFFB42318),
    DocKind.quotation||DocKind.proforma=>const Color(0xFF6D28D9),
    _=>Colors.black87,
  };
  Widget metric(String label,int count,IconData icon,Color color)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,color:color,size:17),const SizedBox(width:6),Flexible(child:Text(label,style:const TextStyle(fontSize:11,color:Colors.black54,fontWeight:FontWeight.w500)))]),
      const SizedBox(height:7),
      TweenAnimationBuilder<double>(tween:Tween(begin:0,end:count.toDouble()),duration:MediaQuery.disableAnimationsOf(context)?Duration.zero:const Duration(milliseconds:380),builder:(_,v,_)=>Text(v.round().toString(),style:const TextStyle(fontSize:32,fontWeight:FontWeight.w800,letterSpacing:-1))),
    ]);
  Widget saved(){
    final docs=widget.store.documents().where((doc)=>'${doc.kind.title} ${doc.number} ${doc.party}'.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(padding:const EdgeInsets.all(18),children:[
      const Text('My documents',style:TextStyle(fontSize:25,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      TextField(onChanged:(value)=>setState(()=>query=value),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search documents')),
      const SizedBox(height:14),
      if(docs.isEmpty) const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('No matching documents.'))),
      for(final doc in docs) Card(child:ListTile(
        leading:Icon(kindIcon(doc.kind),color:brand),
        title:Text('${doc.kind.title} · ${doc.number}'),
        subtitle:Text(doc.party),
        onTap:()=>openEditor(doc.kind,document:doc),
        trailing:IconButton(tooltip:'Delete document',icon:const Icon(Icons.delete_outline),onPressed:()=>remove(doc)),
      )),
    ]);
  }
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key,required this.store,required this.onSaved});
  final DocumentStore store;
  final VoidCallback onSaved;
  @override
  State<ProfileEditor> createState()=>_ProfileEditorState();
}
class _ProfileEditorState extends State<ProfileEditor> {
  late final TextEditingController name,contact,address,taxId;
  late String currency;
  late DocStyle design;
  @override
  void initState(){super.initState();final p=widget.store.profile();name=TextEditingController(text:p.name);
    contact=TextEditingController(text:p.contact);address=TextEditingController(text:p.address);
    taxId=TextEditingController(text:p.taxId);currency=p.currency;design=p.style;}
  @override
  void dispose(){for(final c in [name,contact,address,taxId]){c.dispose();}super.dispose();}
  Future<void> save() async {
    if(name.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter your business name.')));return;}
    try{
      await widget.store.saveProfile(BusinessInfo(name:name.text.trim(),contact:contact.text.trim(),address:address.text.trim(),taxId:taxId.text.trim(),currency:currency,style:design));
      if(!mounted)return;widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Business defaults saved on this device.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  @override
  Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('Business details',style:TextStyle(fontSize:25,fontWeight:FontWeight.bold)),
    const SizedBox(height:6),const Text('Saved once and reused automatically on every new document.'),const SizedBox(height:18),
    for(final field in [(name,'Business name'),(contact,'Phone / email'),(address,'Business address'),(taxId,'Tax ID (optional)')])
      Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:field.$1,maxLength:150,decoration:InputDecoration(labelText:field.$2,counterText:''))),
    DropdownButtonFormField<String>(initialValue:currency,decoration:const InputDecoration(labelText:'Default currency'),
      items:currencies.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v){if(v!=null)setState(()=>currency=v);}),
    const SizedBox(height:18),const Text('Default design',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:8),
    DesignSummary(style:design,onChanged:(value)=>setState(()=>design=value)),
    const SizedBox(height:16),FilledButton(onPressed:save,child:const Text('Save settings')),
    const SizedBox(height:16),OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>NumberingSettings(store:widget.store))),icon:const Icon(Icons.tag),label:const Text('Document numbering')),
    const SizedBox(height:24),
    OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CloudSettings(store:widget.store))),icon:const Icon(Icons.cloud_outlined),label:const Text('Account & privacy')),
    const SizedBox(height:20),
    const Text('Privacy & storage',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
    const SizedBox(height:8),const Text('Documents are stored locally as small editable records. No account or internet connection is required. PDFs are generated on demand. Share or print copies before uninstalling the app. An optional account can back up and restore your records.'),
  ]);
}

class NumberingSettings extends StatefulWidget {
  const NumberingSettings({super.key,required this.store});
  final DocumentStore store;
  @override
  State<NumberingSettings> createState()=>_NumberingSettingsState();
}
class _NumberingSettingsState extends State<NumberingSettings> {
  late final Map<DocKind,TextEditingController> prefixes;
  late bool year;
  @override
  void initState(){super.initState();year=widget.store.includeYear;prefixes={for(final k in DocKind.values)k:TextEditingController(text:widget.store.prefix(k))};}
  @override
  void dispose(){for(final c in prefixes.values)c.dispose();super.dispose();}
  Future<void> save()async{
    try{await widget.store.setNumbering({for(final e in prefixes.entries)e.key:e.value.text},year);if(mounted)Navigator.pop(context);}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Document numbering')),body:ListView(padding:const EdgeInsets.all(18),children:[
    const Text('Set prefixes once. Numbers are generated automatically and never reused on this device.'),
    SwitchListTile(title:const Text('Include year'),subtitle:Text(year?'INV-2026-00001':'INV-00001'),value:year,onChanged:(v)=>setState(()=>year=v)),
    for(final k in DocKind.values)Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:prefixes[k],maxLength:12,decoration:InputDecoration(labelText:k.title+' prefix',counterText:''))),
    FilledButton(onPressed:save,child:const Text('Save numbering')),
  ]));
}
