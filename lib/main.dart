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
  DocKind.invoice=>Icons.description_outlined,
  DocKind.receipt=>Icons.receipt_long_outlined,
  DocKind.quotation=>Icons.assignment_turned_in_outlined,
  DocKind.proforma=>Icons.description_outlined,
  DocKind.purchaseOrder=>Icons.shopping_cart,
  DocKind.deliveryNote=>Icons.local_shipping_outlined,
  DocKind.creditNote=>Icons.credit_card_outlined,
  DocKind.debitNote=>Icons.logout,
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
    appBar:AppBar(toolbarHeight:62,titleSpacing:14,title:Row(children:[
      SizedBox(width:41,height:41,child:Image.asset('assets/reference_icons/crown.png',fit:BoxFit.contain,excludeFromSemantics:true)),
      const SizedBox(width:8),
      const Flexible(child:Text(appName,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontWeight:FontWeight.w800,fontSize:18,letterSpacing:-.45))),
    ]),actions:[IconButton(padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:38,minHeight:48),tooltip:'Notifications',onPressed:()=>showModalBottomSheet<void>(context:context,builder:(c)=>const SafeArea(child:Padding(padding:EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.notifications_none,size:32,color:brand),SizedBox(height:12),Text('Notifications',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),SizedBox(height:8),Text('No notifications to display.')])))),icon:const Icon(Icons.notifications_none,size:24)),Padding(padding:const EdgeInsets.only(right:12),child:IconButton(padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:38,minHeight:48),tooltip:'Account & privacy',onPressed:account,icon:const Icon(Icons.account_circle,size:35,color:brand)))],
    bottom:index==0?null:const PreferredSize(preferredSize:Size.fromHeight(1),child:Divider())),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:BoxConstraints(maxWidth:index==0?560:900),
      child:switch(index){0=>home(),1=>saved(),2=>templates(),3=>reports(),_=>ProfileEditor(store:widget.store,onSaved:()=>setState((){}))},
    ))),
    bottomNavigationBar:SafeArea(top:false,child:Container(padding:const EdgeInsets.fromLTRB(13,8,13,8),decoration:const BoxDecoration(color:Colors.white,border:Border(top:BorderSide(color:Color(0xFFE5E7EB))),borderRadius:BorderRadius.vertical(top:Radius.circular(22))),child:Row(children:[
      navItem(0,'Home',Icons.home_outlined,Icons.home),
      navItem(1,'Docs',Icons.folder_outlined,Icons.folder),
      navItem(2,'Templates',Icons.layers_outlined,Icons.layers),
      navItem(3,'Reports',Icons.bar_chart_outlined,Icons.bar_chart),
      navItem(4,'More',Icons.grid_view_outlined,Icons.grid_view_rounded),
    ]))),
  );
  Widget navItem(int i,String label,IconData icon,IconData selected){
    final active=index==i;
    return Expanded(child:Semantics(button:true,selected:active,child:Material(color:active?brand:Colors.white,borderRadius:BorderRadius.circular(17),child:InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>setState(()=>index=i),child:Padding(padding:const EdgeInsets.symmetric(vertical:8,horizontal:2),child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(active?selected:icon,size:25,color:active?Colors.white:ink),const SizedBox(height:4),
      Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:active?Colors.white:ink)),
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
  int recipientCount(List<BusinessDocument> records)=>records.map((d)=>d.party.trim().toLowerCase()).where((n)=>n.isNotEmpty).toSet().length;
  Widget hero()=>LayoutBuilder(builder:(context,box){
    final w=box.maxWidth;
    final h=w*416/814;
    final large=MediaQuery.textScalerOf(context).scale(14)>17.5;
    final title=Text('Create\nBusiness Docs',style:TextStyle(color:Colors.white,fontSize:(w*.066).clamp(20,34).toDouble(),fontWeight:FontWeight.w800,height:1.06,letterSpacing:-.55));
    final button=FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:const Color(0xFF154BD7),minimumSize:const Size(0,40),padding:const EdgeInsets.symmetric(horizontal:11),shape:const StadiumBorder()),onPressed:chooseDocument,icon:const Icon(Icons.add,size:22),label:const FittedBox(fit:BoxFit.scaleDown,child:Text('New Document',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800))));
    if(large)return Container(color:brand,padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[title,const SizedBox(height:12),button]));
    return SizedBox(height:h,child:Stack(children:[
      Positioned.fill(child:Image.asset('assets/crown_approved_hero.webp',fit:BoxFit.fill,excludeFromSemantics:true)),
      Positioned(left:w*.065,top:h*.235,width:w*.445,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:title),
        SizedBox(height:h*.07),
        SizedBox(width:w*.42,height:40,child:button),
      ])),
    ]));
  });
  Widget home(){
    final records=widget.store.documents();
    final prefs=widget.store.preferences;
    return ListView(padding:const EdgeInsets.only(bottom:20),children:[
      hero(),
      Padding(padding:const EdgeInsets.symmetric(horizontal:13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const SizedBox(height:6),
        LayoutBuilder(builder:(context,box)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          crossAxisCount:box.maxWidth>=280&&MediaQuery.textScalerOf(context).scale(12)<=15?4:2,
          mainAxisExtent:MediaQuery.textScalerOf(context).scale((box.maxWidth*.18).clamp(60,84).toDouble()).clamp(60,125).toDouble(),crossAxisSpacing:7,mainAxisSpacing:7,
          children:[
            metric('Generated',prefs.getInt('local_activity_generated')??0,Icons.description_outlined,brand),
            metric('Downloads',prefs.getInt('local_activity_downloaded')??0,Icons.download_outlined,const Color(0xFF3F3ABF)),
            metric('Share requests',prefs.getInt('local_activity_shared')??0,Icons.share_outlined,const Color(0xFF22723B)),
            metric('Recipients',recipientCount(records),Icons.groups_rounded,const Color(0xFF202020)),
          ])),
        const SizedBox(height:6),
        LayoutBuilder(builder:(context,box)=>SizedBox(width:box.maxWidth/4,height:4,child:Center(child:Container(width:31,height:4,decoration:BoxDecoration(color:brand,borderRadius:BorderRadius.circular(2)))))),
        const SizedBox(height:16),
        LayoutBuilder(builder:(context,box)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          crossAxisCount:box.maxWidth>=280&&MediaQuery.textScalerOf(context).scale(12)<=15?4:box.maxWidth>=240?3:2,
          mainAxisExtent:MediaQuery.textScalerOf(context).scale((box.maxWidth*.217).clamp(83,115).toDouble()).clamp(83,175).toDouble(),crossAxisSpacing:7,mainAxisSpacing:10,
          children:[for(final kind in DocKind.values.take(8)) Material(
            color:tileColor(kind),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
            clipBehavior:Clip.antiAlias,
            child:InkWell(key:Key('create_${kind.name}'),onTap:()=>openEditor(kind),
              child:Stack(children:[
                Positioned(right:0,bottom:0,child:CustomPaint(size:Size(box.maxWidth*.12,22),painter:_TileCorner(kindColor(kind).withValues(alpha:kind==DocKind.invoice ? .95 : .53)))),
                Center(child:Padding(padding:const EdgeInsets.all(5),child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Image.asset('assets/reference_icons/'+kind.name+'.png',width:34,height:34,fit:BoxFit.contain,excludeFromSemantics:true),const SizedBox(height:5),
                  Text(shortTitle(kind),textAlign:TextAlign.center,maxLines:2,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800,height:1.12,color:ink)),
                ]))),
              ])),
          )])),
        const SizedBox(height:12),
        Row(children:[Container(width:4,height:18,decoration:BoxDecoration(color:brand,borderRadius:BorderRadius.circular(2))),const SizedBox(width:8),const Expanded(child:Text('Recent',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,letterSpacing:-.3))),
          OutlinedButton(onPressed:()=>setState(()=>index=1),style:OutlinedButton.styleFrom(backgroundColor:const Color(0xFFF5F6FA),foregroundColor:brand,minimumSize:const Size(0,32),tapTargetSize:MaterialTapTargetSize.shrinkWrap,padding:const EdgeInsets.symmetric(horizontal:10),side:const BorderSide(color:Color(0xFFDCE2F0)),shape:const StadiumBorder()),child:const Row(mainAxisSize:MainAxisSize.min,children:[Text('View All',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700)),SizedBox(width:4),Icon(Icons.chevron_right,size:17)]))]),
        const SizedBox(height:7),
        Container(decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE8ECF4)),borderRadius:BorderRadius.circular(15)),child:records.isEmpty
          ?const Padding(padding:EdgeInsets.all(20),child:Text('No saved documents yet.',style:TextStyle(color:Color(0xFF4D4D4D))))
          :Column(children:[
            for(final doc in records.take(2)) ...[
              InkWell(onTap:()=>openEditor(doc.kind,document:doc),borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.fromLTRB(10,5,3,5),child:Row(children:[
                Container(width:36,height:36,decoration:BoxDecoration(color:tileColor(doc.kind),borderRadius:BorderRadius.circular(8)),child:Icon(kindIcon(doc.kind),color:kindColor(doc.kind),size:23)),
                const SizedBox(width:8),
                Expanded(flex:6,child:Text(doc.number,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13,letterSpacing:-.25))),
                if(doc.kind.hasPrices||doc.kind.isStatement)Expanded(flex:5,child:Text(money(doc.total,doc.currency),maxLines:2,textAlign:TextAlign.right,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800))),
                SizedBox(width:32,height:37,child:PopupMenuButton<String>(tooltip:'Document actions',padding:EdgeInsets.zero,icon:const Icon(Icons.more_vert,size:20),onSelected:(v){if(v=='open'){openEditor(doc.kind,document:doc);}else if(v=='delete'){remove(doc);}},itemBuilder:(_)=>const [PopupMenuItem(value:'open',child:Text('Open')),PopupMenuItem(value:'delete',child:Text('Delete'))])),
              ]))),
              if(doc!=records.take(2).last)const Padding(padding:EdgeInsets.symmetric(horizontal:10),child:Divider()),
            ],
          ])),
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
    DocKind.invoice||DocKind.purchaseOrder=>const Color(0xFF174FCB),
    DocKind.debitNote=>const Color(0xFF133D9E),
    DocKind.receipt||DocKind.creditNote||DocKind.paymentVoucher=>const Color(0xFF22723B),
    DocKind.proforma=>const Color(0xFF3447AD),
    _=>const Color(0xFF3F3ABF),
  };
  Color tileColor(DocKind k)=>switch(k){
    DocKind.invoice=>const Color(0xFFDDEAFE),
    DocKind.receipt=>const Color(0xFFE9F4EF),
    DocKind.quotation=>const Color(0xFFEDEBFC),
    DocKind.proforma=>const Color(0xFFF0F0FD),
    DocKind.purchaseOrder=>const Color(0xFFE8EBFD),
    DocKind.deliveryNote=>const Color(0xFFEFEDFC),
    DocKind.creditNote=>const Color(0xFFE4F2EB),
    DocKind.debitNote=>const Color(0xFFE8F0FD),
    _=>const Color(0xFFF0F3FA),
  };
  Widget metric(String label,int count,IconData icon,Color color)=>Semantics(label:'$label: $count',button:true,child:Tooltip(message:'$label: $count',child:Material(color:color,borderRadius:BorderRadius.circular(11),child:InkWell(borderRadius:BorderRadius.circular(11),onTap:()=>setState(()=>index=3),child:Padding(
    padding:const EdgeInsets.symmetric(horizontal:3,vertical:4),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:Colors.white,size:23),
      const SizedBox(height:2),
      Flexible(child:TweenAnimationBuilder<double>(tween:Tween(begin:0,end:count.toDouble()),duration:MediaQuery.disableAnimationsOf(context)?Duration.zero:const Duration(milliseconds:320),builder:(_,v,_)=>FittedBox(fit:BoxFit.scaleDown,child:Text(v.round().toString(),style:const TextStyle(fontSize:26,height:1,fontWeight:FontWeight.w800,color:Colors.white,letterSpacing:-.5))))),
    ]))))));
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
      for(final item in [('Generated',prefs.getInt('local_activity_generated')??0),('Downloads',prefs.getInt('local_activity_downloaded')??0),('Share requests',prefs.getInt('local_activity_shared')??0),('Saved documents',records.length),('Recipients',recipientCount(records))])
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

class _TileCorner extends CustomPainter{
  const _TileCorner(this.color);
  final Color color;
  @override
  void paint(Canvas canvas,Size size)=>canvas.drawPath(Path()..moveTo(0,size.height)..quadraticBezierTo(size.width*.82,size.height*.65,size.width,0)..lineTo(size.width,size.height)..close(),Paint()..color=color);
  @override
  bool shouldRepaint(covariant _TileCorner oldDelegate)=>oldDelegate.color!=color;
}
