import 'package:flutter_painter_v2/flutter_painter.dart';

abstract class NamedDrawable extends ObjectDrawable {
  final String name;
  final String warningId;

  const NamedDrawable({
    required this.name,
    required this.warningId,
    required super.position,
    required super.hidden,
  });
}
