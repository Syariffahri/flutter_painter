// lib/src/controllers/settings/free_style_settings.dart

import 'package:flutter/material.dart';
import '../drawables/drawable.dart';

// [MODIFIKASI] Tambahkan parameter 'bool locked' di sini
typedef GroupCreator = Drawable Function({
  required List<Drawable> children,
  required Offset position,
  required Size size,
  bool locked, // Tambahkan ini
});

/// Represents settings used to create and draw free-style drawables.
@immutable
class FreeStyleSettings {
  /// Free-style painting mode.
  final FreeStyleMode mode;

  /// The color the path will be drawn with.
  final Color color;

  /// The stroke width the path will be drawn with.
  final double strokeWidth;

  // Callback opsional untuk membuat grup
  final GroupCreator? groupCreator;

  /// Creates a [FreeStyleSettings] with the given [color]
  /// and [strokeWidth] and [mode] values.
  const FreeStyleSettings({
    this.mode = FreeStyleMode.none,
    this.color = Colors.black,
    this.strokeWidth = 1,
    this.groupCreator,
  });

  /// Creates a copy of this but with the given fields replaced with the new values.
  FreeStyleSettings copyWith({
    FreeStyleMode? mode,
    Color? color,
    double? strokeWidth,
    GroupCreator? groupCreator,
  }) {
    return FreeStyleSettings(
      mode: mode ?? this.mode,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      groupCreator: groupCreator ?? this.groupCreator,
    );
  }
}

/// Enum representing different states that free-style painting can be.
enum FreeStyleMode {
  /// Free-style painting is disabled.
  none,

  /// Free-style painting is enabled in drawing mode; used to draw scribbles.
  draw,

  /// Free-style painting is enabled in erasing mode; used to erase drawings.
  erase,
}
