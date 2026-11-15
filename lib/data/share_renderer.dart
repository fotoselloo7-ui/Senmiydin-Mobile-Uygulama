import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../widgets/share_card.dart';

/// Draws a widget off-screen into a PNG without ever putting it on the screen (no route, no overlay), so the person
/// sees nothing flash and the result does not depend on the current page. The PNG carries no metadata at all.
Future<Uint8List> renderWidgetToPng(
  Widget widget, {
  required Size logicalSize,
  required double pixelRatio,
}) async {
  final boundary = RenderRepaintBoundary();
  final view = ui.PlatformDispatcher.instance.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(logicalSize),
      devicePixelRatio: 1,
    ),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          devicePixelRatio: 1,
          textScaler: TextScaler.noScaling,
        ),
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'NunitoSans'),
          child: widget,
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  buildOwner
    ..buildScope(root)
    ..finalizeTree();
  pipeline
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('The card could not be encoded.');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
    buildOwner.finalizeTree();
  }
}

Future<Uint8List> renderShareCard(ShareCardData data, ShareCardFormat format) =>
    renderWidgetToPng(
      ShareCardView(data: data, format: format),
      logicalSize: format.logicalSize,
      pixelRatio: ShareCardFormat.pixelRatio,
    );
