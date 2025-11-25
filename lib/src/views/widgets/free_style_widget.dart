part of 'flutter_painter.dart';

/// Flutter widget to detect user input and request drawing [FreeStyleDrawable]s.
class _FreeStyleWidget extends StatefulWidget {
  /// Child widget.
  final Widget child;

  /// Creates a [_FreeStyleWidget] with the given [controller], [child] widget.
  const _FreeStyleWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _FreeStyleWidgetState createState() => _FreeStyleWidgetState();
}

/// State class
class _FreeStyleWidgetState extends State<_FreeStyleWidget> {
  /// The current drawable being drawn.
  PathDrawable? drawable;

  @override
  Widget build(BuildContext context) {
    if (settings.mode == FreeStyleMode.none || shapeSettings.factory != null) {
      return widget.child;
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _DragGestureDetector:
            GestureRecognizerFactoryWithHandlers<_DragGestureDetector>(
          () => _DragGestureDetector(
            onHorizontalDragDown: _handleHorizontalDragDown,
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragUp: _handleHorizontalDragUp,
          ),
          (_) {},
        ),
      },
      child: widget.child,
    );
  }

  /// Getter for [FreeStyleSettings] from `widget.controller.value` to make code more readable.
  FreeStyleSettings get settings =>
      PainterController.of(context).value.settings.freeStyle;

  /// Getter for [ShapeSettings] from `widget.controller.value` to make code more readable.
  ShapeSettings get shapeSettings =>
      PainterController.of(context).value.settings.shape;

  /// Callback when the user holds their pointer(s) down onto the widget.
  void _handleHorizontalDragDown(Offset globalPosition) {
    // If the user is already drawing, don't create a new drawing
    if (this.drawable != null) return;

    // Create a new free-style drawable representing the current drawing
    final PathDrawable drawable;
    if (settings.mode == FreeStyleMode.draw) {
      drawable = FreeStyleDrawable(
        path: [_globalToLocal(globalPosition)],
        color: settings.color,
        strokeWidth: settings.strokeWidth,
        // --- Set 'isEditing' ke true untuk render cepat ---
        isEditing: true,
      );

      PainterController.of(context).addDrawables([drawable]);
    } else if (settings.mode == FreeStyleMode.erase) {
      drawable = EraseDrawable(
        path: [_globalToLocal(globalPosition)],
        strokeWidth: settings.strokeWidth,
      );
      // PainterController.of(context).groupDrawables();

      PainterController.of(context).addDrawables([drawable], newAction: false);
    } else {
      return;
    }

    // Set the drawable as the current drawable
    this.drawable = drawable;
  }

  /// Callback when the user moves, rotates or scales the pointer(s).
  void _handleHorizontalDragUpdate(Offset globalPosition) {
    final drawable = this.drawable;
    // If there is no current drawable, ignore user input
    if (drawable == null) return;

    // --- PERBAIKAN PERFORMA UTAMA ---

    // 1. Modifikasi path yang ada (SANGAT CEPAT)
    drawable.path.add(_globalToLocal(globalPosition));

    // 2. Buat salinan 'dangkal' (shallow copy) dari drawable.
    // Kita harus melakukan type check untuk memanggil copyWith yang benar.
    final PathDrawable newDrawable;
    if (drawable is FreeStyleDrawable) {
      // Panggil copyWith dari FreeStyleDrawable (yang memiliki 'isEditing')
      newDrawable = drawable.copyWith();
    } else if (drawable is EraseDrawable) {
      // Panggil copyWith dari EraseDrawable
      newDrawable = drawable.copyWith();
    } else {
      // Tipe path lain yang tidak diketahui, jangan lakukan apa-apa
      return;
    }

    // 3. Ganti drawable di controller.
    PainterController.of(context)
        .replaceDrawable(drawable, newDrawable, newAction: false);

    // 4. Update drawable saat ini ke referensi baru
    this.drawable = newDrawable;
    // --- AKHIR PERBAIKAN PERFORMA ---
  }

  /// Callback when the user removes all pointers from the widget.
  void _handleHorizontalDragUp() {
    final drawable = this.drawable;
    if (drawable == null) return;

    // --- PERBAIKAN ERROR DI SINI ---
    // Kita harus melakukan type check sebelum memanggil copyWith(isEditing: ...)

    Drawable newDrawable = drawable; // Mulai dengan drawable yang ada

    // Periksa apakah ini FreeStyleDrawable
    if (drawable is FreeStyleDrawable) {
      // Jika ya, cast dan panggil copyWith DENGAN isEditing
      newDrawable = drawable.copyWith(
        isEditing: false, // Set ke false untuk render kualitas tinggi
      );
      // Ganti drawable 'editing' dengan drawable 'final'
      PainterController.of(context)
          .replaceDrawable(drawable, newDrawable, newAction: false);
    }
    // Jika ini EraseDrawable, kita tidak perlu melakukan apa-apa
    // karena 'isEditing' tidak ada dan kualitasnya sudah diatur di konstruktornya.

    // --- AKHIR PERBAIKAN ERROR ---

    DrawableCreatedNotification(newDrawable).dispatch(context);

    /// Reset the current drawable for the user to draw a new one next time
    this.drawable = null;
  }

  Offset _globalToLocal(Offset globalPosition) {
    final getBox = context.findRenderObject() as RenderBox;

    return getBox.globalToLocal(globalPosition);
  }
}

/// A custom recognizer that recognize at most only one gesture sequence.
class _DragGestureDetector extends OneSequenceGestureRecognizer {
  _DragGestureDetector({
    required this.onHorizontalDragDown,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragUp,
  });

  final ValueSetter<Offset> onHorizontalDragDown;
  final ValueSetter<Offset> onHorizontalDragUpdate;
  final VoidCallback onHorizontalDragUp;

  bool _isTrackingGesture = false;

  @override
  void addPointer(PointerEvent event) {
    if (!_isTrackingGesture) {
      resolve(GestureDisposition.accepted);
      startTrackingPointer(event.pointer);
      _isTrackingGesture = true;
    } else {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      onHorizontalDragDown(event.position);
    } else if (event is PointerMoveEvent) {
      onHorizontalDragUpdate(event.position);
    } else if (event is PointerUpEvent) {
      onHorizontalDragUp();
      stopTrackingPointer(event.pointer);
      _isTrackingGesture = false;
    }
  }

  @override
  String get debugDescription => '_DragGestureDetector';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
