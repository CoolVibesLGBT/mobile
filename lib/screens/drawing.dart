import '../l10n/l10n.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../components/components.dart';
import '../core/attachments.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});
  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final boundary = GlobalKey();
  final strokes = <_Stroke>[];
  Color color = Colors.black;
  double width = 4;
  bool saving = false;
  Future<void> save() async {
    if (saving || strokes.isEmpty) return;
    setState(() => saving = true);
    await perform(context, () async {
      final canvas =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await canvas.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final root = await AttachmentController.directory();
      final file = File(
        '${root.path}/drawing-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      if (mounted) Navigator.pop(context, file.path);
    });
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(
      title: Text(context.l10n.drawing),
      actions: [
        AppIconButton(
          tooltip: context.l10n.undo,
          icon: const Icon(Icons.undo),
          onPressed: strokes.isEmpty
              ? null
              : () => setState(() => strokes.removeLast()),
        ),
        AppButton.text(
          onPressed: saving ? null : save,
          child: Text(context.l10n.use),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: Colors.white,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (event) => setState(
                  () =>
                      strokes.add(_Stroke(color, width, [event.localPosition])),
                ),
                onPanUpdate: (event) => setState(() {
                  if (strokes.isNotEmpty) {
                    strokes.last.points.add(event.localPosition);
                  }
                }),
                child: CustomPaint(
                  painter: _DrawingPainter(strokes),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        AppSection(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in [
                    Colors.black,
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                  ])
                    AppIconButton(
                      tooltip: value.toARGB32().toRadixString(16),
                      icon: Icon(Icons.circle, color: value),
                      onPressed: () => setState(() => color = value),
                    ),
                ],
              ),
            ),
            Slider(
              value: width,
              min: 1,
              max: 18,
              label: '${width.round()}',
              onChanged: (value) => setState(() => width = value),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Stroke {
  final Color color;
  final double width;
  final List<Offset> points;
  _Stroke(this.color, this.width, this.points);
}

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _DrawingPainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (final point in stroke.points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => true;
}
