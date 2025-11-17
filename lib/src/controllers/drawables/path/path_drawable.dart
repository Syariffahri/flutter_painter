import 'package:flutter/material.dart';

import '../drawable.dart';

/// Free-style Drawable (hand scribble).
abstract class PathDrawable extends Drawable {
  /// List of points representing the path to draw.
  // --- UBAH: Hapus 'final' agar path bisa di-mutasi ---
  List<Offset> path;
  // --- AKHIR PERUBAHAN ---

  /// The stroke width the path will be drawn with.
  final double strokeWidth;

  /// Creates a [PathDrawable] to draw [path].
  ///
  /// The path will be drawn with the passed [strokeWidth] if provided.
  PathDrawable({
    required this.path,
    this.strokeWidth = 1,
    bool hidden = false,
  })  :
        // An empty path cannot be drawn, so it is an invalid argument.
        assert(path.isNotEmpty, 'The path cannot be an empty list'),

        // The line cannot have a non-positive stroke width.
        assert(strokeWidth > 0,
            'The stroke width cannot be less than or equal to 0'),
        super(hidden: hidden);

  /// Creates a copy of this but with the given fields replaced with the new values.
  PathDrawable copyWith({
    bool? hidden,
    List<Offset>? path,
    double? strokeWidth,
  });

  @protected
  Paint get paint;

  /// Draws the free-style [path] on the provided [canvas] of size [size].
  @override
  void draw(Canvas canvas, Size size) {
    // --- PERUBAHAN UTAMA: IMPLEMENTASI SMOOTHING ---

    // 1. Dapatkan cat (paint) dari sub-kelas (FreeStyle atau Erase)
    final paint = this.paint;

    // 2. Buat objek Path baru
    final uiPath = Path();

    // 3. Handle kasus-kasus khusus (1 atau 2 titik)
    if (path.isEmpty) {
      return; // Tidak ada yang digambar
    } else if (path.length == 1) {
      // Jika hanya 1 titik, gambar lingkaran kecil (untuk dot)
      uiPath.addOval(Rect.fromCircle(center: path[0], radius: strokeWidth / 2));
    } else if (path.length == 2) {
      // Jika 2 titik, gambar garis lurus
      uiPath.moveTo(path[0].dx, path[0].dy);
      uiPath.lineTo(path[1].dx, path[1].dy);
    } else {
      // 4. Implementasi Smoothing (Interpolasi)
      // Ini adalah algoritma smoothing Catmull-Rom yang disederhanakan (menggunakan midpoint)
      // untuk menghasilkan kurva yang mulus.

      uiPath.moveTo(path[0].dx, path[0].dy); // Pindah ke titik pertama

      // Iterasi melalui sisa titik untuk membuat kurva
      for (int i = 1; i < path.length - 1; i++) {
        final p1 = path[i];
        final p2 = path[i + 1];

        // Hitung titik tengah antara p1 dan p2 sebagai titik akhir segmen kurva
        final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

        // Gambar kurva Bezier
        // p1 adalah *titik kontrol* (yang membuat kurva melengkung)
        // midPoint adalah *titik akhir* dari kurva
        uiPath.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.dy);
      }

      // Gambar segmen terakhir (garis lurus) ke titik paling akhir
      // untuk memastikan goresan selesai di tempat stylus diangkat.
      uiPath.lineTo(path.last.dx, path.last.dy);
    }

    // 5. Gambar Path yang sudah di-smooth ke canvas
    canvas.drawPath(uiPath, paint);
    // --- AKHIR PERUBAHAN UTAMA ---
  }
}
