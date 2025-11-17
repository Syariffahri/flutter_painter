import 'dart:ui';

import 'package:flutter/material.dart';

import 'path_drawable.dart';

/// Free-style Drawable (hand scribble).
class FreeStyleDrawable extends PathDrawable {
  /// The color the path will be drawn with.
  final Color color;

  /// Whether the drawable is currently being edited.
  ///
  /// If `true`, the drawable will be drawn with lower quality for performance.
  /// If `false`, the drawable will be drawn with higher quality.
  final bool isEditing;

  /// Creates a [FreeStyleDrawable] to draw [path].
  ///
  /// The path will be drawn with the passed [color] and [strokeWidth] if provided.
  FreeStyleDrawable({
    required List<Offset> path,
    double strokeWidth = 1,
    this.color = Colors.black,
    bool hidden = false,
    // --- PERBAIKAN: Tambahkan 'isEditing' ke konstruktor ---
    this.isEditing = false,
    // --- AKHIR PERBAIKAN ---
  })  :
        // An empty path cannot be drawn, so it is an invalid argument.
        assert(path.isNotEmpty, 'The path cannot be an empty list'),

        // The line cannot have a non-positive stroke width.
        assert(strokeWidth > 0,
            'The stroke width cannot be less than or equal to 0'),
        super(path: path, strokeWidth: strokeWidth, hidden: hidden);

  /// Creates a copy of this but with the given fields replaced with the new values.
  @override
  FreeStyleDrawable copyWith({
    bool? hidden,
    List<Offset>? path,
    Color? color,
    double? strokeWidth,
    // --- BARU: Tambahkan 'isEditing' ke copyWith ---
    bool? isEditing,
    // --- AKHIR PENAMBAHAN ---
  }) {
    return FreeStyleDrawable(
      // --- UBAH: Salin path dengan benar ---
      path: path ?? List.from(this.path),
      // --- AKHIR PERUBAHAN ---
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      hidden: hidden ?? this.hidden,
      // --- BARU: Salin 'isEditing' ---
      isEditing: isEditing ?? this.isEditing,
      // --- AKHIR PENAMBAHAN ---
    );
  }

  @protected
  @override
  Paint get paint => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color
    ..strokeWidth = strokeWidth
    // --- UBAH: Kualitas render dinamis berdasarkan 'isEditing' ---
    ..isAntiAlias = !isEditing // Non-aktifkan anti-alias saat mengedit
    ..filterQuality = isEditing ? FilterQuality.low : FilterQuality.high;
  // --- AKHIR PERUBAHAN ---

  /// Compares two [FreeStyleDrawable]s for equality.
  // @override
  // bool operator ==(Object other) {
  //   return other is FreeStyleDrawable &&
  //       super == other &&
  //       other.color == color &&
  //       other.strokeWidth == strokeWidth &&
  //       ListEquality().equals(other.path, path);
  // }
  //
  // @override
  // int get hashCode => hashValues(hidden, hashList(path), color, strokeWidth);
}
