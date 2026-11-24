import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'document_store.dart';
import 'business_document.dart';
import 'document_editor.dart';
import 'design_editor.dart';

const brand = Color(0xFF171717);
const ink = Color(0xFF171717);
const appName = 'Crown Business Docs';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
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
      navigationBarTheme:const NavigationBarThemeData(backgroundColor:Colors.white,indicatorColor:Color(0xFFF0F0F0)),
      inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder(),filled:true,fillColor:Colors.white),
      appBarTheme:const AppBarTheme(backgroundColor:Colors.white,surfaceTintColor:Colors.transparent,foregroundColor:ink),
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
    appBar:AppBar(title:const Row(children:[
      Icon(Icons.description_rounded,color:brand,size:28),SizedBox(width:10),
      Flexible(child:Text(appName,style:TextStyle(fontWeight:FontWeight.w800,fontSize:19))),
    ])),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),
      child:switch(index){0=>home(),1=>saved(),_=>ProfileEditor(store:widget.store,onSaved:()=>setState((){}))},
    ))),
    bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(value)=>setState(()=>index=value),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.folder_outlined),selectedIcon:Icon(Icons.folder),label:'My documents'),
        NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Settings'),
      ]),
  );
  Widget home()=>ListView(padding:const EdgeInsets.fromLTRB(18,24,18,24),children:[
    const Text('Your workspace',style:TextStyle(fontSize:27,fontWeight:FontWeight.w800,color:ink)),
    const SizedBox(height:5),
    const Text('Create, save and share business documents.',style:TextStyle(color:Colors.black54)),
    const SizedBox(height:18),
    Row(children:[
      Expanded(child:metric('Saved documents',widget.store.documents().length,Icons.folder_outlined,const Color(0xFF157347))),
      const SizedBox(width:10),
      Expanded(child:metric('This month',widget.store.documents().where((d)=>d.date.year==DateTime.now().year&&d.date.month==DateTime.now().month).length,Icons.calendar_today_outlined,const Color(0xFF6D28D9))),
    ]),
    const SizedBox(height:24),
    const Text('Create a document',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
    const SizedBox(height:5),
    const Text('Choose a document type. Works offline.',style:TextStyle(color:Colors.black54)),
    const SizedBox(height:14),
    LayoutBuilder(builder:(context,box)=>GridView.count(
      shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
      crossAxisCount:box.maxWidth>700?4:box.maxWidth>470?3:2,
      crossAxisSpacing:12,mainAxisSpacing:12,mainAxisExtent:150,
      children:DocKind.values.map((kind)=>Material(
        color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10),side:const BorderSide(color:Color(0xFFE2E8ED))),
        child:InkWell(borderRadius:BorderRadius.circular(10),onTap:()=>openEditor(kind),key:Key('create_${kind.name}'),
          child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:kindColor(kind).withValues(alpha:.08),borderRadius:BorderRadius.circular(7)),child:Icon(kindIcon(kind),color:kindColor(kind),size:23)),const Spacer(),const Icon(Icons.arrow_outward,size:17,color:Colors.black38)]),const Spacer(),
            Text(kind.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:14)),
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
  Widget metric(String label,int count,IconData icon,Color color)=>Container(
    padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE5E7EB)),borderRadius:BorderRadius.circular(10)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:color,size:23),const SizedBox(height:8),
      TweenAnimationBuilder<double>(tween:Tween(begin:0,end:count.toDouble()),duration:const Duration(milliseconds:400),builder:(_,v,_)=>Text(v.round().toString(),style:const TextStyle(fontSize:29,fontWeight:FontWeight.w800))),
      Text(label,style:const TextStyle(fontSize:12,color:Colors.black54)),
    ]),
  );
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
    const Text('Privacy & storage',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
    const SizedBox(height:8),const Text('Documents are stored locally as small editable records. No account or internet connection is required. PDFs are generated on demand. Share or print copies before uninstalling the app. Device storage is not cloud backup.'),
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
