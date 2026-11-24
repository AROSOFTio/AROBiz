import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'business_document.dart';

Color brandColor(String hex)=>Color(int.parse('FF${validHex(hex,'196B74')}',radix:16));
const palettes=[
  ('Teal','196B74','152D45'),('Navy','24538B','172C49'),('Forest','26704A','183C32'),
  ('Burgundy','87344B','442232'),('Gold','AD772A','40331F'),('Purple','7153A1','30254A'),
  ('Orange','C35820','442B24'),('Monochrome','424242','212121'),
];

class DesignSummary extends StatelessWidget {
  const DesignSummary({super.key,required this.style,required this.onChanged});
  final DocStyle style;
  final ValueChanged<DocStyle>? onChanged;
  @override
  Widget build(BuildContext context)=>Card(
    margin:const EdgeInsets.only(bottom:12),
    child:ListTile(
      leading:Icon(Icons.palette_outlined,color:brandColor(style.primary)),
      title:Text(style.template.title),
      subtitle:Text('${style.paper.name.toUpperCase()} · ${style.dateFormat.example} · ${style.logo.isEmpty?'No logo':'Custom logo'}'),
      trailing:const Icon(Icons.chevron_right),
      onTap:onChanged==null?null:()async{
        final chosen=await Navigator.push<DocStyle>(context,MaterialPageRoute(builder:(_)=>DesignEditor(style:style)));
        if(chosen!=null)onChanged!(chosen);
      },
    ),
  );
}

class DesignEditor extends StatefulWidget {
  const DesignEditor({super.key,required this.style});
  final DocStyle style;
  @override
  State<DesignEditor> createState()=>_DesignEditorState();
}
class _DesignEditorState extends State<DesignEditor>{
  late DocStyle style;
  late final TextEditingController primary,secondary,footer,taxLabel;
  bool picking=false;
  @override
  void initState(){
    super.initState();style=widget.style;
    primary=TextEditingController(text:style.primary);
    secondary=TextEditingController(text:style.secondary);
    footer=TextEditingController(text:style.footer);
    taxLabel=TextEditingController(text:style.taxLabel);
  }
  @override
  void dispose(){for(final c in [primary,secondary,footer,taxLabel]){c.dispose();}super.dispose();}
  void palette(String a,String b)=>setState((){
    primary.text=a;secondary.text=b;style=style.copyWith(primary:a,secondary:b);
  });
  Future<void> pickLogo() async {
    if(picking)return;
    setState(()=>picking=true);
    try{
      final file=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:600,maxHeight:600);
      if(file==null)return;
      final decoded=img.decodeImage(await file.readAsBytes());
      if(decoded==null)throw StateError('Unsupported image');
      final oriented=img.bakeOrientation(decoded);
      final resized=img.copyResize(oriented,width:oriented.width>=oriented.height?320:null,height:oriented.height>oriented.width?320:null);
      final png=img.encodePng(resized);
      List<int> bytes=png;
      if(png.length>48000){
        final background=img.Image(width:resized.width,height:resized.height);
        img.fill(background,color:img.ColorRgb8(255,255,255));
        img.compositeImage(background,resized);
        bytes=img.encodeJpg(background,quality:80);
      }
      if(bytes.length>96000)throw StateError('Logo is too large; select a smaller image.');
      if(mounted)setState(()=>style=style.copyWith(logo:base64Encode(bytes)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not load logo: $e')));}
    finally{if(mounted)setState(()=>picking=false);}
  }
  void apply(){
    if(!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(primary.text.trim().replaceFirst('#',''))||
       !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(secondary.text.trim().replaceFirst('#',''))){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter six hexadecimal digits for each color.')));return;
    }
    Navigator.pop(context,style.copyWith(primary:validHex(primary.text,style.primary),secondary:validHex(secondary.text,style.secondary),
      footer:footer.text.trim(),taxLabel:taxLabel.text.trim().isEmpty?'Tax':taxLabel.text.trim()));
  }
  Widget section(String title)=>Padding(padding:const EdgeInsets.only(top:20,bottom:10),child:Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)));
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Document design')),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:750),
      child:ListView(padding:const EdgeInsets.all(18),children:[
        const Text('Choose a layout',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
        const SizedBox(height:6),const Text('All layouts work with every document type.'),
        const SizedBox(height:14),
        LayoutBuilder(builder:(context,box)=>GridView.count(
          shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          crossAxisCount:box.maxWidth>550?3:2,childAspectRatio:.79,crossAxisSpacing:10,mainAxisSpacing:10,
          children:DocTemplate.values.map((t)=>Material(
            color:Colors.white,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:BorderSide(
              color:t==style.template?brandColor(style.primary):Colors.grey.shade300,width:t==style.template?2:1)),
            child:InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>setState(()=>style=style.copyWith(template:t)),
              child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Expanded(child:TemplateThumbnail(template:t,style:style)),
                const SizedBox(height:8),
                Row(children:[Expanded(child:Text(t.title,style:const TextStyle(fontWeight:FontWeight.bold))),if(t==style.template)Icon(Icons.check_circle,size:18,color:brandColor(style.primary))]),
                Text(t.description,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10)),
              ]))),
          )).toList(),
        )),
        section('Brand colors'),
        Wrap(spacing:8,runSpacing:8,children:palettes.map((p)=>ChoiceChip(
          avatar:CircleAvatar(backgroundColor:brandColor(p.$2)),label:Text(p.$1),
          selected:style.primary==p.$2&&style.secondary==p.$3,onSelected:(_)=>palette(p.$2,p.$3),
        )).toList()),
        const SizedBox(height:12),
        TextField(controller:primary,maxLength:7,decoration:const InputDecoration(labelText:'Primary HEX color',prefixText:'#',counterText:''),onChanged:(v)=>setState(()=>style=style.copyWith(primary:validHex(v,style.primary)))),
        const SizedBox(height:10),
        TextField(controller:secondary,maxLength:7,decoration:const InputDecoration(labelText:'Secondary HEX color',prefixText:'#',counterText:''),onChanged:(v)=>setState(()=>style=style.copyWith(secondary:validHex(v,style.secondary)))),
        section('Business logo'),
        Row(children:[
          Container(width:76,height:76,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:Colors.grey.shade300),borderRadius:BorderRadius.circular(10)),
            child:style.logo.isEmpty?const Icon(Icons.image_outlined,size:34,color:Colors.grey):Image.memory(base64Decode(style.logo),fit:BoxFit.contain,errorBuilder:(_,_,_)=>const Icon(Icons.broken_image_outlined))),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            OutlinedButton.icon(onPressed:picking?null:pickLogo,icon:const Icon(Icons.upload_file),label:const Text('Choose logo')),
            if(style.logo.isNotEmpty)TextButton(onPressed:()=>setState(()=>style=style.copyWith(logo:'')),child:const Text('Remove logo')),
            const Text('Stored locally; resized to keep files small.',style:TextStyle(fontSize:11)),
          ])),
        ]),
        section('Regional preferences'),
        DropdownButtonFormField<DocPaper>(initialValue:style.paper,decoration:const InputDecoration(labelText:'Paper size'),
          items:DocPaper.values.map((v)=>DropdownMenuItem(value:v,child:Text(switch(v){DocPaper.a4=>'A4 — international',DocPaper.letter=>'US Letter — North America',DocPaper.a5=>'A5 — compact'}))).toList(),
          onChanged:(v){if(v!=null)setState(()=>style=style.copyWith(paper:v));}),
        const SizedBox(height:12),
        DropdownButtonFormField<DocDate>(initialValue:style.dateFormat,decoration:const InputDecoration(labelText:'Date format'),
          items:DocDate.values.map((v)=>DropdownMenuItem(value:v,child:Text(v.example))).toList(),
          onChanged:(v){if(v!=null)setState(()=>style=style.copyWith(dateFormat:v));}),
        const SizedBox(height:12),
        TextField(controller:taxLabel,maxLength:16,decoration:const InputDecoration(labelText:'Tax label (VAT, GST, Sales tax...)',counterText:'')),
        section('Footer'),
        TextField(controller:footer,maxLength:180,maxLines:3,decoration:const InputDecoration(labelText:'Custom footer text',hintText:'Website, registration number or thank-you message')),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:picking?null:apply,icon:const Icon(Icons.check),label:const Text('Apply design')),
      ]),
    ))),
  );
}

class TemplateThumbnail extends StatelessWidget {
  const TemplateThumbnail({super.key,required this.template,required this.style});
  final DocTemplate template;
  final DocStyle style;
  @override
  Widget build(BuildContext context)=>Container(
    decoration:BoxDecoration(color:Colors.white,border:Border.all(color:Colors.grey.shade300)),
    padding:const EdgeInsets.all(7),
    child:CustomPaint(painter:_ThumbnailPainter(template,brandColor(style.primary),brandColor(style.secondary)),child:const SizedBox.expand()),
  );
}
class _ThumbnailPainter extends CustomPainter{
  const _ThumbnailPainter(this.template,this.primary,this.secondary);
  final DocTemplate template;final Color primary,secondary;
  @override
  void paint(Canvas canvas,Size size){
    final w=size.width,h=size.height;
    void rect(double x,double y,double a,double b,Color color)=>canvas.drawRect(Rect.fromLTWH(x*w,y*h,a*w,b*h),Paint()..color=color);
    final gray=Colors.grey.shade300;
    if(template==DocTemplate.executive){rect(0,0,1,.28,primary);rect(.05,.06,.16,.15,Colors.white);rect(.5,.09,.43,.035,Colors.white);rect(.5,.16,.29,.025,Colors.white);}
    else if(template==DocTemplate.elegant){rect(.42,.02,.16,.15,primary);rect(.25,.20,.5,.036,secondary);rect(.05,.27,.90,.014,primary);rect(.28,.32,.44,.04,primary);}
    else{
      if(template==DocTemplate.modern)rect(0,0,1,.025,primary);
      rect(.02,.055,.19,.14,primary);rect(.02,.22,.37,.03,secondary);rect(.54,.07,.43,.045,primary);rect(.67,.15,.30,.025,gray);
      if(template==DocTemplate.classic){final p=Paint()..color=secondary..style=PaintingStyle.stroke;canvas.drawRect(Rect.fromLTWH(0,0,w,h*.28),p);}
      if(template==DocTemplate.minimal||template==DocTemplate.compact)rect(0,.29,1,.01,secondary);
    }
    final start=template==DocTemplate.elegant ? 0.46 : 0.36;
    rect(0,start,.36,.025,secondary);
    rect(0,start+.05,.5,.018,gray);
    final table=start+.12;
    rect(0,table,1,.055,template==DocTemplate.minimal||template==DocTemplate.classic?gray:secondary);
    for(var i=0;i<(template==DocTemplate.compact?5:3);i++){final y=table+.07+i*.045;rect(.02,y,.55,.014,gray);rect(.76,y,.22,.014,gray);}
    rect(.56,.82,.44,.055,primary);rect(0,.93,1,.012,primary);rect(.02,.96,.38,.013,gray);
  }
  @override
  bool shouldRepaint(covariant _ThumbnailPainter old)=>old.template!=template||old.primary!=primary||old.secondary!=secondary;
}
