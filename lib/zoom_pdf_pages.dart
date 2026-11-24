import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Displays one full page at a time, with independent pan/zoom controls.
class ZoomPdfPages extends StatefulWidget {
  const ZoomPdfPages({super.key,required this.pages});
  final List<PdfPreviewPageData> pages;
  @override
  State<ZoomPdfPages> createState()=>_ZoomPdfPagesState();
}
class _ZoomPdfPagesState extends State<ZoomPdfPages>{
  final transform=TransformationController();
  int page=0;
  double get scale=>transform.value.getMaxScaleOnAxis();
  @override
  void dispose(){transform.dispose();super.dispose();}
  void fit()=>transform.value=Matrix4.identity();
  void zoom(double multiplier){
    final next=(scale*multiplier).clamp(1.0,5.0).toDouble();
    if(next==1){fit();return;}
    transform.value=Matrix4.diagonal3Values(next,next,1);
  }
  void changePage(int index){
    if(index<0||index>=widget.pages.length)return;
    fit();setState(()=>page=index);
  }
  @override
  Widget build(BuildContext context){
    final data=widget.pages[page.clamp(0,widget.pages.length-1).toInt()];
    return Column(children:[
      Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:4),child:Wrap(alignment:WrapAlignment.center,crossAxisAlignment:WrapCrossAlignment.center,children:[
        IconButton(tooltip:'Previous page',onPressed:page>0?()=>changePage(page-1):null,icon:const Icon(Icons.chevron_left)),
        Text('${page+1} / ${widget.pages.length}',style:const TextStyle(fontWeight:FontWeight.w700)),
        IconButton(tooltip:'Next page',onPressed:page+1<widget.pages.length?()=>changePage(page+1):null,icon:const Icon(Icons.chevron_right)),
        IconButton(tooltip:'Zoom out',onPressed:()=>zoom(1/1.25),icon:const Icon(Icons.remove)),
        ValueListenableBuilder<Matrix4>(valueListenable:transform,builder:(_,_,_)=>Text('${(scale*100).round()}%',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
        IconButton(tooltip:'Zoom in',onPressed:()=>zoom(1.25),icon:const Icon(Icons.add)),
        IconButton(tooltip:'Fit page',onPressed:fit,icon:const Icon(Icons.fit_screen_outlined)),
      ])),
      const Divider(),
      Expanded(child:ColoredBox(color:const Color(0xFFF1EFF5),child:LayoutBuilder(builder:(context,box){
        final availableWidth=(box.maxWidth-16).clamp(1.0,double.infinity).toDouble();
        final availableHeight=(box.maxHeight-16).clamp(1.0,double.infinity).toDouble();
        final width=availableWidth<availableHeight*data.aspectRatio?availableWidth:availableHeight*data.aspectRatio;
        return GestureDetector(onDoubleTap:()=>scale>1.01?fit():zoom(2),child:InteractiveViewer(
          key:const Key('pdf_zoom_viewer'),transformationController:transform,minScale:1,maxScale:5,
          child:Center(child:Container(width:width,height:width/data.aspectRatio,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFD9D6E1))),child:Image(image:data.image,fit:BoxFit.contain,filterQuality:FilterQuality.high))),
        ));
      }))),
      const Padding(padding:EdgeInsets.symmetric(vertical:7),child:Text('Pinch to zoom · Drag to move',style:TextStyle(fontSize:11,color:Colors.black54))),
    ]);
  }
}

