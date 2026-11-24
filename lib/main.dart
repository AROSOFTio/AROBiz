import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'document_store.dart';
import 'business_document.dart';
import 'document_editor.dart';
import 'design_editor.dart';
import 'cloud_service.dart';

const brand = Color(0xFF2563EB);
const ink = Color(0xFF202020);
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
    theme:ThemeData(useMaterial3:true,colorScheme:const ColorScheme.light(primary:brand,onPrimary:Colors.white,secondary:Color(0xFF3F3ABF),surface:Colors.white,onSurface:ink),
      scaffoldBackgroundColor:Colors.white,
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),minimumSize:const Size(0,48))),
      outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),minimumSize:const Size(0,48))),
      cardTheme:const CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(side:BorderSide(color:Color(0xFFE5E7EB),width:1),borderRadius:BorderRadius.all(Radius.circular(10)))),
      navigationBarTheme:const NavigationBarThemeData(backgroundColor:Colors.white,indicatorColor:Color(0xFFE9F0FF),elevation:0,height:65,labelTextStyle:WidgetStatePropertyAll(TextStyle(fontSize:11,fontWeight:FontWeight.w600))),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,fillColor:const Color(0xFFFAFAFA),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:16),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:Color(0xFFDADADA))),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:Color(0xFFDADADA))),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:brand,width:1.5)),
        labelStyle:const TextStyle(fontSize:14,color:Color(0xFF4D4D4D)),
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
  DocKind templateKind=DocKind.invoice;
  Future<void> openEditor(DocKind kind,{BusinessDocument? document,DocTemplate? template}) async {
    if(opening)return;
    if(document==null&&widget.store.profile().name.trim().isEmpty){
      setState(()=>index=4);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Save your business details once, then create documents.')));
      return;
    }
    setState(()=>opening=true);
    try{
      final number=document?.number??await widget.store.reserveNumber(kind,DateTime.now());
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>DocumentEditor(store:widget.store,kind:kind,existing:document,assignedNumber:number,initialTemplate:template)));
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
    appBar:AppBar(titleSpacing:14,title:Row(children:[
      Container(width:38,height:38,decoration:BoxDecoration(color:brand,borderRadius:BorderRadius.circular(9)),child:const CustomPaint(painter:_CrownMark())),
      const SizedBox(width:8),
      const Flexible(child:Text(appName,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontWeight:FontWeight.w800,fontSize:16,letterSpacing:-.4))),
    ]),actions:[IconButton(tooltip:'Notifications',onPressed:()=>showModalBottomSheet<void>(context:context,builder:(c)=>const SafeArea(child:Padding(padding:EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.notifications_none,size:32,color:brand),SizedBox(height:12),Text('Notifications',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),SizedBox(height:8),Text('No notifications to display.')])))),icon:const Icon(Icons.notifications_none,size:24)),Padding(padding:const EdgeInsets.only(right:10),child:IconButton(tooltip:'Account & privacy',onPressed:account,icon:const Icon(Icons.account_circle,size:32,color:brand)))],
    bottom:const PreferredSize(preferredSize:Size.fromHeight(1),child:Divider())),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),
      child:switch(index){0=>home(),1=>saved(),2=>templates(),3=>reports(),_=>ProfileEditor(store:widget.store,onSaved:()=>setState((){}))},
    ))),
    bottomNavigationBar:SafeArea(top:false,child:Container(padding:const EdgeInsets.fromLTRB(8,8,8,8),decoration:const BoxDecoration(color:Colors.white,border:Border(top:BorderSide(color:Color(0xFFE5E7EB)))),child:Row(children:[
      navItem(0,'Home',Icons.home_outlined,Icons.home),
      navItem(1,'Docs',Icons.folder_outlined,Icons.folder),
      navItem(2,'Templates',Icons.layers_outlined,Icons.layers),
      navItem(3,'Reports',Icons.bar_chart_outlined,Icons.bar_chart),
      navItem(4,'More',Icons.grid_view_outlined,Icons.grid_view_rounded),
    ]))),
  );
  Widget navItem(int i,String label,IconData icon,IconData selected){
    final active=index==i;
    return Expanded(child:Semantics(button:true,selected:active,child:Material(color:active?brand:Colors.white,borderRadius:BorderRadius.circular(10),child:InkWell(borderRadius:BorderRadius.circular(10),onTap:()=>setState(()=>index=i),child:Padding(padding:const EdgeInsets.symmetric(vertical:8,horizontal:2),child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(active?selected:icon,size:24,color:active?Colors.white:ink),const SizedBox(height:4),
      Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:active?Colors.white:ink)),
    ]))))));
  }
  Future<void> chooseDocument() async {
    final selected=await showModalBottomSheet<DocKind>(context:context,isScrollControlled:true,
      backgroundColor:Colors.white,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(12))),
      builder:(c)=>SafeArea(child:FractionallySizedBox(heightFactor:.78,child:Column(children:[
        const Padding(padding:EdgeInsets.all(18),child:Text('Choose a document',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800))),
        Expanded(child:ListView(children:[for(final kind in DocKind.values) ListTile(leading:Icon(kindIcon(kind),color:kindColor(kind)),title:Text(kind.title),subtitle:Text(kind.description),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.pop(c,kind))])),
      ]))));
    if(selected!=null&&mounted)await openEditor(selected);
  }
  Future<void> account() async {
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CloudSettings(store:widget.store)));
    if(mounted)setState((){});
  }
  Widget home(){
    final records=widget.store.documents();
    final prefs=widget.store.preferences;
    return ListView(padding:const EdgeInsets.fromLTRB(14,12,14,20),children:[
      ClipRRect(borderRadius:BorderRadius.circular(12),child:Stack(children:[
        Positioned.fill(child:CustomPaint(painter:const _HeroArtwork())),
        Padding(padding:const EdgeInsets.fromLTRB(16,28,16,33),child:Row(children:[
          Expanded(flex:6,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Create\nBusiness Docs',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w800,height:1.12,letterSpacing:-.7)),
            const SizedBox(height:15),
            FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:brand,minimumSize:const Size(0,43),padding:const EdgeInsets.symmetric(horizontal:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),onPressed:chooseDocument,icon:const Icon(Icons.add,size:20),label:const Text('New document',style:TextStyle(fontSize:13,fontWeight:FontWeight.w700))),
          ])),
          const Expanded(flex:5,child:SizedBox(height:146,child:CustomPaint(painter:_DocumentArtwork()))),
        ])),
      ])),
      const SizedBox(height:14),
      LayoutBuilder(builder:(context,box)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
        crossAxisCount:box.maxWidth>=280&&MediaQuery.textScalerOf(context).scale(12)<=15?4:2,
        mainAxisExtent:MediaQuery.textScalerOf(context).scale(90).clamp(90,160).toDouble(),crossAxisSpacing:7,mainAxisSpacing:7,
        children:[
          metric('Generated',prefs.getInt('local_activity_generated')??0,Icons.description_outlined,brand),
          metric('Downloads',prefs.getInt('local_activity_downloaded')??0,Icons.download_outlined,const Color(0xFF3F3ABF)),
          metric('Share requests',prefs.getInt('local_activity_shared')??0,Icons.share_outlined,const Color(0xFF22723B)),
          metric('Saved',records.length,Icons.bookmark_border,const Color(0xFF202020)),
        ])),
      const SizedBox(height:17),
      LayoutBuilder(builder:(context,box)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
        crossAxisCount:box.maxWidth>=280&&MediaQuery.textScalerOf(context).scale(12)<=15?4:box.maxWidth>=240?3:2,
        mainAxisExtent:MediaQuery.textScalerOf(context).scale(88).clamp(88,165).toDouble(),crossAxisSpacing:7,mainAxisSpacing:7,
        children:[for(final kind in DocKind.values.take(8)) Material(
          color:Color.alphaBlend(kindColor(kind).withValues(alpha:.075),Colors.white),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9)),
          clipBehavior:Clip.antiAlias,
          child:InkWell(key:Key('create_${kind.name}'),onTap:()=>openEditor(kind),
            child:Stack(children:[
              Positioned(right:0,bottom:0,child:CustomPaint(size:const Size(26,12),painter:_TileCorner(kindColor(kind).withValues(alpha:.28)))),
              Center(child:Padding(padding:const EdgeInsets.all(5),child:Column(mainAxisSize:MainAxisSize.min,children:[
                Icon(kindIcon(kind),color:kindColor(kind),size:25),const SizedBox(height:6),
                Text(shortTitle(kind),textAlign:TextAlign.center,maxLines:2,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,height:1.13,color:ink)),
              ]))),
            ])),
        )])),
      Align(alignment:Alignment.centerRight,child:TextButton(onPressed:chooseDocument,child:const Text('View all documents'))),
      const SizedBox(height:4),
      Row(children:[Container(width:4,height:17,color:brand),const SizedBox(width:7),const Expanded(child:Text('Recent',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))),TextButton(onPressed:()=>setState(()=>index=1),child:const Text('View all'))]),
      if(records.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('No saved documents yet.',style:TextStyle(color:Color(0xFF4D4D4D))))
      else Container(decoration:BoxDecoration(border:Border.all(color:const Color(0xFFE5E7EB)),borderRadius:BorderRadius.circular(10)),child:Column(children:[
        for(final doc in records.take(2)) ...[
          ListTile(dense:true,contentPadding:const EdgeInsets.symmetric(horizontal:9,vertical:2),leading:Container(width:35,height:35,decoration:BoxDecoration(color:Color.alphaBlend(kindColor(doc.kind).withValues(alpha:.09),Colors.white),borderRadius:BorderRadius.circular(7)),child:Icon(kindIcon(doc.kind),color:kindColor(doc.kind),size:21)),
            title:Text(doc.number,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)),
            subtitle:Text(doc.party,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11)),
            trailing:doc.kind.hasPrices||doc.kind.isStatement?ConstrainedBox(constraints:const BoxConstraints(maxWidth:110),child:Text(money(doc.total,doc.currency),maxLines:2,textAlign:TextAlign.right,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))):const Icon(Icons.chevron_right,size:18),
            onTap:()=>openEditor(doc.kind,document:doc)),if(doc!=records.take(2).last)const Divider(),
        ],
      ])),
    ]);
  }
  String shortTitle(DocKind k)=>switch(k){
    DocKind.proforma=>'Proforma',
    DocKind.purchaseOrder=>'Purchase',
    DocKind.deliveryNote=>'Delivery',
    DocKind.creditNote=>'Credit',
    DocKind.debitNote=>'Debit',
    DocKind.paymentVoucher=>'Payment voucher',
    DocKind.statement=>'Statement',
    DocKind.letter=>'Letter',
    _=>k.title,
  };
  Color kindColor(DocKind k)=>switch(k){
    DocKind.invoice||DocKind.purchaseOrder||DocKind.debitNote=>brand,
    DocKind.receipt||DocKind.creditNote||DocKind.paymentVoucher=>const Color(0xFF22723B),
    _=>const Color(0xFF3F3ABF),
  };
  Widget metric(String label,int count,IconData icon,Color color)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:4,vertical:8),decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(9)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:Colors.white,size:21),
      const SizedBox(height:3),
      Flexible(child:TweenAnimationBuilder<double>(tween:Tween(begin:0,end:count.toDouble()),duration:MediaQuery.disableAnimationsOf(context)?Duration.zero:const Duration(milliseconds:320),builder:(_,v,_)=>FittedBox(fit:BoxFit.scaleDown,child:Text(v.round().toString(),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:Colors.white,letterSpacing:-.5))))),
      Text(label,textAlign:TextAlign.center,maxLines:2,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w600,height:1.12)),
    ]));
  Widget templates()=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Templates',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
    const SizedBox(height:12),
    DropdownButtonFormField<DocKind>(initialValue:templateKind,decoration:const InputDecoration(labelText:'Document type'),items:[for(final k in DocKind.values)DropdownMenuItem(value:k,child:Text(k.title))],onChanged:(v){if(v!=null)setState(()=>templateKind=v);}),
    const SizedBox(height:14),
    for(final t in templateKind.layouts) Padding(padding:const EdgeInsets.only(bottom:12),child:OutlinedButton(onPressed:()=>openEditor(templateKind,template:t),style:OutlinedButton.styleFrom(padding:const EdgeInsets.all(12)),child:Row(children:[
      SizedBox(width:75,height:94,child:TemplateThumbnail(template:t,style:widget.store.profile().style,kind:templateKind)),
      const SizedBox(width:14),Expanded(child:Text(templateKind.layoutTitle(t),style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700))),const Icon(Icons.chevron_right),
    ]))),
  ]);
  Widget reports(){
    final records=widget.store.documents();
    final prefs=widget.store.preferences;
    return ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Reports',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
      const Text('Activity on this device',style:TextStyle(color:Color(0xFF4D4D4D))),
      const SizedBox(height:14),
      for(final item in [('Generated',prefs.getInt('local_activity_generated')??0),('Downloads',prefs.getInt('local_activity_downloaded')??0),('Share requests',prefs.getInt('local_activity_shared')??0),('Saved documents',records.length)])
        ListTile(contentPadding:EdgeInsets.zero,title:Text(item.$1),trailing:Text(item.$2.toString(),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:brand))),
      const Divider(),const SizedBox(height:14),
      const Text('Saved by document type',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      for(final k in DocKind.values) ListTile(contentPadding:EdgeInsets.zero,leading:Icon(kindIcon(k),color:kindColor(k)),title:Text(k.title),trailing:Text(records.where((d)=>d.kind==k).length.toString())),
    ]);
  }
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

class _HeroArtwork extends CustomPainter {
  const _HeroArtwork();
  @override
  void paint(Canvas canvas,Size size){
    final p=Paint()..color=brand;
    canvas.drawPath(Path()..moveTo(0,size.height*.13)..quadraticBezierTo(size.width*.22,size.height*.06,size.width*.42,size.height*.11)..cubicTo(size.width*.62,size.height*.16,size.width*.73,-size.height*.07,size.width,0)..lineTo(size.width,size.height*.84)..cubicTo(size.width*.75,size.height*1.04,size.width*.54,size.height*.97,size.width*.33,size.height*.89)..quadraticBezierTo(size.width*.1,size.height*.82,0,size.height)..close(),p);
    p.color=const Color(0xFF1D4ED8);
    canvas.drawPath(Path()..moveTo(size.width*.38,size.height*.87)..cubicTo(size.width*.67,size.height*1.02,size.width*.88,size.height*.91,size.width,size.height*.72)..lineTo(size.width,size.height*.83)..cubicTo(size.width*.73,size.height*1.04,size.width*.53,size.height*.97,size.width*.38,size.height*.87)..close(),p);
  }
  @override
  bool shouldRepaint(covariant _HeroArtwork oldDelegate)=>false;
}
class _DocumentArtwork extends CustomPainter {
  const _DocumentArtwork();
  @override
  void paint(Canvas canvas,Size size){
    canvas.save();canvas.translate(size.width/2,size.height/2);
    final w=size.width*.65,h=size.height*.79;
    final p=Paint();
    canvas.save();canvas.translate(w*.24,4);canvas.rotate(.17);
    p.color=const Color(0xFFBFD4FF);canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset.zero,width:w,height:h),const Radius.circular(5)),p);canvas.restore();
    canvas.rotate(-.13);
    p.color=Colors.white;canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset.zero,width:w,height:h),const Radius.circular(5)),p);
    p.color=brand;canvas.drawRect(Rect.fromLTWH(-w*.36,-h*.35,w*.58,h*.075),p);
    p.color=const Color(0xFFCBD5E1);
    for(var i=0;i<3;i++){canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-w*.36,-h*.18+i*h*.09,w*(i==2 ? .48 : .72),h*.035),const Radius.circular(1)),p);}
    p.color=const Color(0xFFDFE9FF);canvas.drawRect(Rect.fromLTWH(-w*.36,h*.12,w*.72,h*.19),p);
    p.color=brand;canvas.drawRect(Rect.fromLTWH(-w*.36,h*.12,w*.72,h*.045),p);
    p.color=const Color(0xFF22723B);canvas.drawCircle(Offset(w*.28,h*.35),w*.16,p);
    p.color=Colors.white;p.style=PaintingStyle.stroke;p.strokeWidth=2;p.strokeCap=StrokeCap.round;
    canvas.drawPath(Path()..moveTo(w*.20,h*.35)..lineTo(w*.26,h*.40)..lineTo(w*.36,h*.29),p);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _DocumentArtwork oldDelegate)=>false;
}
class _TileCorner extends CustomPainter{
  const _TileCorner(this.color);
  final Color color;
  @override
  void paint(Canvas canvas,Size size)=>canvas.drawPath(Path()..moveTo(0,size.height)..quadraticBezierTo(size.width*.82,size.height*.65,size.width,0)..lineTo(size.width,size.height)..close(),Paint()..color=color);
  @override
  bool shouldRepaint(covariant _TileCorner oldDelegate)=>oldDelegate.color!=color;
}

class _CrownMark extends CustomPainter{
  const _CrownMark();
  @override
  void paint(Canvas canvas,Size size){
    canvas.save();canvas.scale(size.width/38,size.height/38);
    final p=Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.7..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    canvas.drawPath(Path()..moveTo(8,13)..lineTo(13,19)..lineTo(19,9)..lineTo(25,19)..lineTo(30,13)..lineTo(27,27)..lineTo(11,27)..close(),p);
    canvas.drawLine(const Offset(12,30),const Offset(26,30),p);
    p.style=PaintingStyle.fill;
    for(final q in [const Offset(8,13),const Offset(19,9),const Offset(30,13)]){canvas.drawCircle(q,1.9,p);}
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _CrownMark oldDelegate)=>false;
}
