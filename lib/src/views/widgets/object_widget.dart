// lib/src/views/widgets/object_widget.dart

part of 'flutter_painter.dart';

/// Flutter widget to move, scale and rotate [ObjectDrawable]s.
class _ObjectWidget extends StatefulWidget {
  /// Child widget.
  final Widget child;

  /// Whether scaling is enabled or not.
  ///
  /// If `false`, objects won't be movable, scalable or rotatable.
  final bool interactionEnabled;

  /// Creates a [_ObjectWidget] with the given [controller], [child] widget.
  const _ObjectWidget({
    Key? key,
    required this.child,
    this.interactionEnabled = true,
  }) : super(key: key);

  @override
  _ObjectWidgetState createState() => _ObjectWidgetState();
}

class _ObjectWidgetState extends State<_ObjectWidget> {
  static Set<double> assistAngles = <double>{
    0,
    pi / 4,
    pi / 2,
    3 * pi / 4,
    pi,
    5 * pi / 4,
    3 * pi / 2,
    7 * pi / 4,
    2 * pi
  };

  /// The last controller value in the widget tree.
  /// Updated by [didChangeDependencies] and used in [dispose].
  PainterController? controller;

  /// Calculates the scale for the [InteractiveViewer] in the widget tree, and scales
  double transformationScale = 1;

  /// Getter for extra amount of padding added around each object to make it easier to interact with.
  double get objectPadding => 25 / transformationScale;

  /// Getter for the duration of fade-in and out animations for the object controls.
  static Duration get controlsTransitionDuration =>
      const Duration(milliseconds: 100);

  /// Getter for the size of the controls of the selected object.
  double get controlsSize =>
      (settings.enlargeControlsResolver() ? 20 : 10) / transformationScale;

  /// Getter for the blur radius of the selected object highlighting.
  double get selectedBlurRadius => 2 / transformationScale;

  /// Getter for the border width of the selected object highlighting.
  double get selectedBorderWidth => 1 / transformationScale;

  /// Keeps track of the initial local focal point when scaling starts.
  ///
  /// This is used to offset the movement of the drawable correctly.
  Map<int, Offset> drawableInitialLocalFocalPoints = {};

  /// Keeps track of the initial drawable when scaling starts.
  ///
  /// This is used to calculate the new rotation angle and
  /// degree relative to the initial drawable.
  Map<int, ObjectDrawable> initialScaleDrawables = {};

  /// Keeps track of widgets that have assist lines assigned to them.
  ///
  /// This is used to provide haptic feedback when the assist line appears.
  Map<ObjectDrawableAssist, Set<int>> assistDrawables = {
    for (var e in ObjectDrawableAssist.values) e: <int>{}
  };

  /// Keeps track of which controls are being used.
  ///
  /// Used to highlight the controls when they are in use.
  Map<int, bool> controlsAreActive = {
    for (var e in List.generate(12, (index) => index)) e: false,
  };

  /// Subscription to the events coming from the controller.
  StreamSubscription<PainterEvent>? controllerEventSubscription;

  /// Getter for the list of [ObjectDrawable]s in the controller
  /// to make code more readable.
  List<ObjectDrawable> get drawables => PainterController.of(context)
      .value
      .drawables
      .whereType<ObjectDrawable>()
      .toList();

  /// A flag on whether to cancel controls animation or not.
  /// This is used to cancel the animation after the selected object
  /// drawable is deleted.
  bool cancelControlsAnimation = false;

  // Menyimpan EraseDrawables yang terhubung
  List<EraseDrawable> _linkedEraseDrawables = [];

  @override
  void initState() {
    super.initState();

    // Listen to the stream of events from the paint controller
    WidgetsBinding.instance.addPostFrameCallback((timestamp) {
      controllerEventSubscription =
          PainterController.of(context).events.listen((event) {
        // When an [RemoveDrawableEvent] event is received and removed drawable is the selected object
        // cancel the animation.
        if (event is SelectedObjectDrawableRemovedEvent) {
          setState(() {
            cancelControlsAnimation = true;
          });
        }
      });

      // Listen to transformation changes of [InteractiveViewer].
      PainterController.of(context)
          .transformationController
          .addListener(onTransformUpdated);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = PainterController.of(context);
  }

  @override
  void dispose() {
    // Cancel subscription to events from painter controller
    controllerEventSubscription?.cancel();
    controller?.transformationController.removeListener(onTransformUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawables = this.drawables;
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: onBackgroundTapped, child: widget.child)),
          ...drawables.asMap().entries.map((entry) {
            final drawable = entry.value;
            final selected = drawable == controller?.selectedObjectDrawable;
            final size = drawable.getSize(maxWidth: constraints.maxWidth);
            final widget = Padding(
              padding: EdgeInsets.all(objectPadding),
              child: SizedBox(
                width: size.width,
                height: size.height,
              ),
            );
            return Positioned(
              top: drawable.position.dy - objectPadding - size.height / 2,
              left: drawable.position.dx - objectPadding - size.width / 2,
              child: Transform.rotate(
                angle: drawable.rotationAngle,
                transformHitTests: true,
                child: Container(
                  child: freeStyleSettings.mode == FreeStyleMode.draw
                      ? widget
                      : MouseRegion(
                          cursor: drawable.locked
                              ? MouseCursor.defer
                              : SystemMouseCursors.allScroll,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => tapDrawable(drawable),
                            onScaleStart: (details) =>
                                onDrawableScaleStart(entry, details),
                            onScaleUpdate: (details) =>
                                onDrawableScaleUpdate(entry, details),
                            onScaleEnd: (_) => onDrawableScaleEnd(entry),
                            child: AnimatedSwitcher(
                              duration: controlsTransitionDuration,
                              child: selected
                                  ? Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        widget,
                                        // BORDER HIGHLIGHT
                                        Positioned(
                                          top: objectPadding -
                                              (controlsSize / 2),
                                          bottom: objectPadding -
                                              (controlsSize / 2),
                                          left: objectPadding -
                                              (controlsSize / 2),
                                          right: objectPadding -
                                              (controlsSize / 2),
                                          child: Builder(
                                            builder: (context) {
                                              if (usingHtmlRenderer) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors.black,
                                                        width:
                                                            selectedBorderWidth),
                                                  ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width:
                                                              selectedBorderWidth),
                                                    ),
                                                  ),
                                                );
                                              }
                                              return Container(
                                                decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors.white,
                                                        width:
                                                            selectedBorderWidth),
                                                    boxShadow: [
                                                      BorderBoxShadow(
                                                        color: Colors.black,
                                                        blurRadius:
                                                            selectedBlurRadius,
                                                      )
                                                    ]),
                                              );
                                            },
                                          ),
                                        ),

                                        // --- ROTATION HANDLE (Index 2) - MUNCUL UNTUK SEMUA ---
                                        if (settings
                                            .showScaleRotationControlsResolver())
                                          Positioned(
                                            top: objectPadding - (controlsSize),
                                            right:
                                                objectPadding - (controlsSize),
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor: initialScaleDrawables
                                                      .containsKey(entry.key)
                                                  ? SystemMouseCursors.grabbing
                                                  : SystemMouseCursors.grab,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onRotationControlPanStart(
                                                        2, entry, details),
                                                onPanUpdate: (details) =>
                                                    onRotationControlPanUpdate(
                                                        entry, details, size),
                                                onPanEnd: (details) =>
                                                    onRotationControlPanEnd(
                                                        2, entry, details),
                                                child: _ObjectControlBox(
                                                  shape: BoxShape.circle,
                                                  active:
                                                      controlsAreActive[2] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),

                                        // --- HANDLES KHUSUS 2D (KOTAK/LINGKARAN) ---
                                        // Menampilkan: 4 Sudut (Corners) + Atas/Bawah (Top/Bottom)
                                        if (entry.value is Sized2DDrawable) ...[
                                          // TOP-LEFT CORNER (Index 8)
                                          Positioned(
                                            top: objectPadding - controlsSize,
                                            left: objectPadding - controlsSize,
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors
                                                  .resizeUpLeft,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        8, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeCornerPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        true, // isTop
                                                        true), // isLeft
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        8, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[8] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // TOP-RIGHT CORNER (Index 9)
                                          Positioned(
                                            top: objectPadding - controlsSize,
                                            right: objectPadding - controlsSize,
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors
                                                  .resizeUpRight,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        9, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeCornerPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        true, // isTop
                                                        false), // isLeft
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        9, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[9] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // BOTTOM-LEFT CORNER (Index 10)
                                          Positioned(
                                            bottom:
                                                objectPadding - controlsSize,
                                            left: objectPadding - controlsSize,
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors
                                                  .resizeDownLeft,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        10, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeCornerPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        false, // isTop
                                                        true), // isLeft
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        10, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[10] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // BOTTOM-RIGHT CORNER (Index 11)
                                          Positioned(
                                            bottom:
                                                objectPadding - controlsSize,
                                            right: objectPadding - controlsSize,
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors
                                                  .resizeDownRight,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        11, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeCornerPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        false, // isTop
                                                        false), // isLeft
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        11, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[11] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // TOP CENTER (Index 4)
                                          Positioned(
                                            top: objectPadding - controlsSize,
                                            left: (size.width / 2) +
                                                objectPadding -
                                                (controlsSize / 2),
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor:
                                                  SystemMouseCursors.resizeUp,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        4, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeControlPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        Axis.vertical,
                                                        true),
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        4, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[4] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // BOTTOM CENTER (Index 5)
                                          Positioned(
                                            bottom:
                                                objectPadding - controlsSize,
                                            left: (size.width / 2) +
                                                objectPadding -
                                                (controlsSize / 2),
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor:
                                                  SystemMouseCursors.resizeDown,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        5, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeControlPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        Axis.vertical,
                                                        false),
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        5, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[5] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],

                                        // --- HANDLES UNTUK 1D & 2D (KIRI & KANAN) ---
                                        // Ini muncul untuk Arrow/Line (resize panjang) dan Shape 2D (resize lebar)
                                        if (entry.value is Sized2DDrawable ||
                                            entry.value is Sized1DDrawable) ...[
                                          // LEFT CENTER (Index 6)
                                          Positioned(
                                            top: (size.height / 2) +
                                                objectPadding -
                                                (controlsSize / 2),
                                            left: objectPadding - controlsSize,
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor:
                                                  SystemMouseCursors.resizeLeft,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        6, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeControlPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        Axis.horizontal,
                                                        true),
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        6, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[6] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // RIGHT CENTER (Index 7)
                                          Positioned(
                                            top: (size.height / 2) +
                                                objectPadding -
                                                (controlsSize / 2),
                                            right: objectPadding - controlsSize,
                                            width: controlsSize,
                                            height: controlsSize,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors
                                                  .resizeRight,
                                              child: GestureDetector(
                                                onPanStart: (details) =>
                                                    onResizeControlPanStart(
                                                        7, entry, details),
                                                onPanUpdate: (details) =>
                                                    onResizeControlPanUpdate(
                                                        entry,
                                                        details,
                                                        constraints,
                                                        Axis.horizontal,
                                                        false),
                                                onPanEnd: (details) =>
                                                    onResizeControlPanEnd(
                                                        7, entry, details),
                                                child: _ObjectControlBox(
                                                  active:
                                                      controlsAreActive[7] ??
                                                          false,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : widget,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              layoutBuilder: (child, previousChildren) {
                                if (cancelControlsAnimation) {
                                  cancelControlsAnimation = false;
                                  return child ?? const SizedBox();
                                }
                                return AnimatedSwitcher.defaultLayoutBuilder(
                                    child, previousChildren);
                              },
                            ),
                          ),
                        ),
                ),
              ),
            );
          }),
        ],
      );
    });
  }

  /// Updates the corner resize of the drawable.
  void onResizeCornerPanUpdate(
    MapEntry<int, ObjectDrawable> entry,
    DragUpdateDetails details,
    BoxConstraints constraints,
    bool isTop,
    bool isLeft,
  ) {
    final index = entry.key;
    final drawable = entry.value;

    // PERBAIKAN: Izinkan Sized1DDrawable
    if (drawable is! Sized2DDrawable && drawable is! Sized1DDrawable) return;
    if (index < 0 || drawable.locked) return;

    final initial = initialScaleDrawables[index];
    if (initial == null) return;

    // Transform delta ke sistem koordinat lokal
    final localDelta = Matrix4.rotationZ(-drawable.rotationAngle)
        .transform3(Vector3(details.delta.dx, details.delta.dy, 0));
    final scaledDelta =
        Offset(localDelta.x, localDelta.y) / transformationScale;

    // Kalkulasi custom (jika ada di settings)
    Size? calculatedNewSize;
    final customHandler = settings.customResizeHandler;
    if (customHandler != null) {
      calculatedNewSize = customHandler(
        drawable: drawable,
        currentSize: drawable.getSize(),
        localDelta: scaledDelta,
        transformationScale: transformationScale,
        axis: null,
        isTop: isTop,
        isLeft: isLeft,
      );
    }

    // --- LOGIKA Sized1DDrawable (Arrow/Line) ---
    if (drawable is Sized1DDrawable) {
      double deltaLength = scaledDelta.dx;
      if (isLeft) deltaLength = -deltaLength;

      double newLength;
      if (calculatedNewSize != null) {
        newLength = calculatedNewSize.width;
      } else {
        newLength =
            (drawable.length + deltaLength).clamp(20.0, double.infinity);
      }

      final lengthDiff = newLength - drawable.length;
      double offsetX = lengthDiff / 2;
      if (isLeft) offsetX = -offsetX;

      final rotatedOffset = Matrix4.rotationZ(drawable.rotationAngle)
          .transform3(Vector3(offsetX, 0, 0));

      final newDrawable = drawable.copyWith(
        length: newLength,
        position: drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
      );
      updateDrawable(drawable, newDrawable);
    }
    // --- LOGIKA Sized2DDrawable (Kotak/Lingkaran) ---
    else if (drawable is Sized2DDrawable) {
      Size newSize;
      if (calculatedNewSize != null) {
        newSize = calculatedNewSize;
      } else {
        double deltaWidth = scaledDelta.dx;
        double deltaHeight = scaledDelta.dy;
        if (isLeft) deltaWidth = -deltaWidth;
        if (isTop) deltaHeight = -deltaHeight;

        newSize = Size(
          (drawable.size.width + deltaWidth).clamp(20.0, double.infinity),
          (drawable.size.height + deltaHeight).clamp(20.0, double.infinity),
        );
      }

      final widthDiff = newSize.width - drawable.size.width;
      final heightDiff = newSize.height - drawable.size.height;
      double offsetX = widthDiff / 2;
      double offsetY = heightDiff / 2;
      if (isLeft) offsetX = -offsetX;
      if (isTop) offsetY = -offsetY;

      final rotatedOffset = Matrix4.rotationZ(drawable.rotationAngle)
          .transform3(Vector3(offsetX, offsetY, 0));

      final newDrawable = drawable.copyWith(
        size: newSize,
        position: drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
      );
      updateDrawable(drawable, newDrawable);
    }
  }

  /// Updates the side resize (horizontal/vertical) of the drawable.
  void onResizeControlPanUpdate(MapEntry<int, ObjectDrawable> entry,
      DragUpdateDetails details, BoxConstraints constraints, Axis axis,
      [bool isReversed = true]) {
    final index = entry.key;
    final drawable = entry.value;

    // PERBAIKAN: Izinkan Sized1DDrawable
    if (drawable is! Sized2DDrawable && drawable is! Sized1DDrawable) return;
    if (index < 0 || drawable.locked) return;

    final initial = initialScaleDrawables[index];
    if (initial == null) return;

    final localDelta = Matrix4.rotationZ(-drawable.rotationAngle)
        .transform3(Vector3(details.delta.dx, details.delta.dy, 0));
    final scaledDelta =
        Offset(localDelta.x, localDelta.y) / transformationScale;

    Size? calculatedNewSize;
    final customHandler = settings.customResizeHandler;
    if (customHandler != null) {
      calculatedNewSize = customHandler(
        drawable: drawable,
        currentSize: drawable.getSize(),
        localDelta: scaledDelta,
        transformationScale: transformationScale,
        axis: axis,
        isTop: axis == Axis.vertical && isReversed,
        isLeft: axis == Axis.horizontal && isReversed,
      );
    }

    // --- LOGIKA Sized1DDrawable (Arrow/Line) ---
    if (drawable is Sized1DDrawable) {
      // Hanya proses jika axis Horizontal (Kiri/Kanan)
      if (axis == Axis.horizontal) {
        double newLength;
        if (calculatedNewSize != null) {
          newLength = calculatedNewSize.width;
        } else {
          double deltaLength = scaledDelta.dx;
          if (isReversed) deltaLength = -deltaLength;
          newLength =
              (drawable.length + deltaLength).clamp(20.0, double.infinity);
        }

        final lengthDiff = newLength - drawable.length;
        double offsetX = lengthDiff / 2;
        if (isReversed) offsetX = -offsetX;

        final rotatedOffset = Matrix4.rotationZ(drawable.rotationAngle)
            .transform3(Vector3(offsetX, 0, 0));

        final newDrawable = drawable.copyWith(
          length: newLength,
          position:
              drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
        );
        updateDrawable(drawable, newDrawable);
      }
    }
    // --- LOGIKA Sized2DDrawable (Kotak/Lingkaran) ---
    else if (drawable is Sized2DDrawable) {
      Size newSize;
      final vertical = axis == Axis.vertical;

      if (calculatedNewSize != null) {
        newSize = calculatedNewSize;
      } else {
        double deltaLength = vertical ? scaledDelta.dy : scaledDelta.dx;
        if (isReversed) deltaLength = -deltaLength;

        newSize = Size(
          vertical
              ? drawable.size.width
              : (drawable.size.width + deltaLength)
                  .clamp(20.0, double.infinity),
          vertical
              ? (drawable.size.height + deltaLength)
                  .clamp(20.0, double.infinity)
              : drawable.size.height,
        );
      }

      final widthDiff = newSize.width - drawable.size.width;
      final heightDiff = newSize.height - drawable.size.height;
      final offsetLength = (vertical ? heightDiff : widthDiff) / 2;

      double offsetX = vertical ? 0 : offsetLength;
      double offsetY = vertical ? offsetLength : 0;

      if (isReversed) {
        offsetX = -offsetX;
        offsetY = -offsetY;
      }

      final rotatedOffset = Matrix4.rotationZ(drawable.rotationAngle)
          .transform3(Vector3(offsetX, offsetY, 0));

      final newDrawable = drawable.copyWith(
        size: newSize,
        position: drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
      );
      updateDrawable(drawable, newDrawable);
    }
  }

  /// Getter for the [ObjectSettings] from the controller to make code more readable.
  ObjectSettings get settings =>
      PainterController.of(context).value.settings.object;

  /// Getter for the [FreeStyleSettings] from the controller to make code more readable.
  FreeStyleSettings get freeStyleSettings =>
      PainterController.of(context).value.settings.freeStyle;

  /// Triggers when the user taps an empty space.
  void onBackgroundTapped() {
    SelectedObjectDrawableUpdatedNotification(null).dispatch(context);
    setState(() {
      controller?.deselectObjectDrawable();
    });
  }

  /// Callback when an object is tapped.
  void tapDrawable(ObjectDrawable drawable) {
    if (drawable.locked) return;
    if (PainterController.of(context)
        .value
        .drawablesBeingErased
        .contains(drawable)) return;

    if (controller?.selectedObjectDrawable == drawable) {
      ObjectDrawableReselectedNotification(drawable).dispatch(context);
    } else {
      SelectedObjectDrawableUpdatedNotification(drawable).dispatch(context);
    }

    setState(() {
      controller?.selectObjectDrawable(drawable);
    });
  }

  /// Callback when the object drawable starts being moved, scaled and/or rotated.
  void onDrawableScaleStart(
      MapEntry<int, ObjectDrawable> entry, ScaleStartDetails details) {
    if (!widget.interactionEnabled) return;

    final index = entry.key;
    final drawable = entry.value;

    if (index < 0 || drawable.locked) return;
    if (PainterController.of(context)
        .value
        .drawablesBeingErased
        .contains(drawable)) return;

    _linkedEraseDrawables.clear();
    final currentController = PainterController.of(context);
    final objectBounds = getDrawableBounds(drawable);
    if (objectBounds != null) {
      for (final d in currentController.value.drawables) {
        if (d is EraseDrawable) {
          final eraseBounds = getDrawableBounds(d);
          if (eraseBounds != null && eraseBounds.overlaps(objectBounds)) {
            _linkedEraseDrawables.add(d);
          }
        }
      }
    }

    setState(() {
      currentController.selectObjectDrawable(entry.value);
    });

    initialScaleDrawables[index] = drawable;

    final rotateOffset = Matrix4.rotationZ(drawable.rotationAngle)
      ..translate(details.localFocalPoint.dx, details.localFocalPoint.dy)
      ..rotateZ(-drawable.rotationAngle);
    drawableInitialLocalFocalPoints[index] =
        Offset(rotateOffset[12], rotateOffset[13]);

    updateDrawable(drawable, drawable, newAction: true);
  }

  /// Callback when the object drawable finishes movement, scaling and rotation.
  void onDrawableScaleEnd(MapEntry<int, ObjectDrawable> entry) {
    if (!widget.interactionEnabled) return;

    final index = entry.key;
    final ObjectDrawable drawable;
    try {
      drawable = drawables[index];
    } catch (e) {
      drawableInitialLocalFocalPoints.remove(index);
      initialScaleDrawables.remove(index);
      _linkedEraseDrawables.clear();
      return;
    }

    drawableInitialLocalFocalPoints.remove(index);
    initialScaleDrawables.remove(index);
    for (final assistSet in assistDrawables.values) {
      assistSet.remove(index);
    }
    _linkedEraseDrawables.clear();

    final newDrawable = drawable.copyWith(assists: {});
    updateDrawable(drawable, newDrawable);
  }

  /// Callback when the object drawable is moved, scaled and/or rotated.
  void onDrawableScaleUpdate(
      MapEntry<int, ObjectDrawable> entry, ScaleUpdateDetails details) {
    if (!widget.interactionEnabled) return;

    final index = entry.key;
    final drawable = entry.value;
    if (index < 0) return;

    final initialDrawable = initialScaleDrawables[index];
    final initialLocalFocalPoint =
        drawableInitialLocalFocalPoints[index] ?? Offset.zero;

    if (initialDrawable == null) return;

    final initialPosition = initialDrawable.position - initialLocalFocalPoint;
    final initialRotation = initialDrawable.rotationAngle;

    final rotateOffset = Matrix4.identity()
      ..rotateZ(initialRotation)
      ..translate(details.localFocalPoint.dx, details.localFocalPoint.dy)
      ..rotateZ(-initialRotation);
    final position =
        initialPosition + Offset(rotateOffset[12], rotateOffset[13]);

    final scale = initialDrawable.scale * details.scale;

    var rotation = (initialRotation + details.rotation).remainder(pi * 2);
    if (rotation < 0) rotation += pi * 2;

    final center = this.center;
    final double? closestAssistAngle;
    if (settings.layoutAssist.enabled) {
      calculatePositionalAssists(
        settings.layoutAssist,
        index,
        position,
        center,
      );
      closestAssistAngle = calculateRotationalAssist(
        settings.layoutAssist,
        index,
        rotation,
      );
    } else {
      closestAssistAngle = null;
    }

    final assists = settings.layoutAssist.enabled
        ? assistDrawables.entries
            .where((element) => element.value.contains(index))
            .map((e) => e.key)
            .toSet()
        : <ObjectDrawableAssist>{};
    if (details.pointerCount < 2) assists.remove(ObjectDrawableAssist.rotation);

    final assistedPosition = Offset(
      assists.contains(ObjectDrawableAssist.vertical) ? center.dx : position.dx,
      assists.contains(ObjectDrawableAssist.horizontal)
          ? center.dy
          : position.dy,
    );
    final assistedRotation = assists.contains(ObjectDrawableAssist.rotation) &&
            closestAssistAngle != null
        ? closestAssistAngle.remainder(pi * 2)
        : rotation;

    final newDrawable = drawable.copyWith(
      position: assistedPosition,
      scale: scale,
      rotation: assistedRotation,
      assists: assists,
    );

    final delta = newDrawable.position - drawable.position;
    final currentController = PainterController.of(context);

    if (delta != Offset.zero && _linkedEraseDrawables.isNotEmpty) {
      final updatedEraseDrawables = <EraseDrawable>[];
      for (final eraseDrawable in _linkedEraseDrawables) {
        if (currentController.value.drawables.contains(eraseDrawable)) {
          final newPath = eraseDrawable.path.map((p) => p + delta).toList();
          final newEraseDrawable = eraseDrawable.copyWith(path: newPath);

          currentController.replaceDrawable(eraseDrawable, newEraseDrawable,
              newAction: false);
          updatedEraseDrawables.add(newEraseDrawable);
        }
      }
      _linkedEraseDrawables = updatedEraseDrawables;
    }

    updateDrawable(drawable, newDrawable);
  }

  void calculatePositionalAssists(ObjectLayoutAssistSettings settings,
      int index, Offset position, Offset center) {
    if ((position.dy - center.dy).abs() < settings.positionalEnterDistance &&
        !(assistDrawables[ObjectDrawableAssist.horizontal]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.horizontal]?.add(index);
      settings.hapticFeedback.impact();
    } else if ((position.dy - center.dy).abs() >
            settings.positionalExitDistance &&
        (assistDrawables[ObjectDrawableAssist.horizontal]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.horizontal]?.remove(index);
    }

    if ((position.dx - center.dx).abs() < settings.positionalEnterDistance &&
        !(assistDrawables[ObjectDrawableAssist.vertical]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.vertical]?.add(index);
      settings.hapticFeedback.impact();
    } else if ((position.dx - center.dx).abs() >
            settings.positionalExitDistance &&
        (assistDrawables[ObjectDrawableAssist.vertical]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.vertical]?.remove(index);
    }
  }

  double? calculateRotationalAssist(
      ObjectLayoutAssistSettings settings, int index, double rotation) {
    final closeAngles = assistAngles
        .where((angle) =>
            (rotation - angle).abs() < settings.rotationalExitAngle ||
            (rotation - angle).abs() > (2 * pi - settings.rotationalExitAngle))
        .toList();

    if (closeAngles.isNotEmpty) {
      double minDiff = double.infinity;
      double closestAngle = closeAngles[0];
      for (final angle in closeAngles) {
        final diff = (rotation - angle).abs();
        final wrapDiff = (2 * pi - diff).abs();
        final actualDiff = math.min(diff, wrapDiff);
        if (actualDiff < minDiff) {
          minDiff = actualDiff;
          closestAngle = angle;
        }
      }

      if (minDiff < settings.rotationalEnterAngle &&
          !(assistDrawables[ObjectDrawableAssist.rotation]?.contains(index) ??
              false)) {
        assistDrawables[ObjectDrawableAssist.rotation]?.add(index);
        settings.hapticFeedback.impact();
      }
      return closestAngle;
    }

    if (closeAngles.isEmpty &&
        (assistDrawables[ObjectDrawableAssist.rotation]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.rotation]?.remove(index);
    }

    return null;
  }

  Offset get center {
    final renderBox = PainterController.of(context)
        .painterKey
        .currentContext
        ?.findRenderObject() as RenderBox?;
    final center = renderBox == null
        ? Offset.zero
        : Offset(
            renderBox.size.width / 2,
            renderBox.size.height / 2,
          );
    return center;
  }

  void updateDrawable(ObjectDrawable oldDrawable, ObjectDrawable newDrawable,
      {bool newAction = false}) {
    setState(() {
      PainterController.of(context)
          .replaceDrawable(oldDrawable, newDrawable, newAction: newAction);
    });
  }

  void onRotationControlPanStart(int controlIndex,
      MapEntry<int, ObjectDrawable> entry, DragStartDetails details) {
    setState(() {
      controlsAreActive[controlIndex] = true;
    });
    onDrawableScaleStart(
        entry,
        ScaleStartDetails(
          pointerCount: 2,
          localFocalPoint: entry.value.position,
        ));
  }

  void onRotationControlPanUpdate(MapEntry<int, ObjectDrawable> entry,
      DragUpdateDetails details, Size size) {
    final index = entry.key;
    final initial = initialScaleDrawables[index];
    if (initial == null) return;

    final centerToHandle = details.localPosition -
        Offset(size.width / 2 + objectPadding, size.height / 2 + objectPadding);
    final currentAngle = centerToHandle.direction;
    const initialHandleAngle = -pi / 4;
    final rotationDelta = currentAngle - initialHandleAngle;
    final initialObjectRotation = initial.rotationAngle;
    final newRotation = initialObjectRotation + rotationDelta;

    onDrawableScaleUpdate(
        entry,
        ScaleUpdateDetails(
          pointerCount: 2,
          rotation: newRotation - initialObjectRotation,
          scale: 1,
          localFocalPoint: entry.value.position,
        ));
  }

  void onRotationControlPanEnd(int controlIndex,
      MapEntry<int, ObjectDrawable> entry, DragEndDetails details) {
    setState(() {
      controlsAreActive[controlIndex] = false;
    });
    onDrawableScaleEnd(entry);
  }

  void onResizeControlPanStart(int controlIndex,
      MapEntry<int, ObjectDrawable> entry, DragStartDetails details) {
    setState(() {
      controlsAreActive[controlIndex] = true;
    });
    onDrawableScaleStart(
        entry,
        ScaleStartDetails(
          pointerCount: 1,
          localFocalPoint: entry.value.position,
        ));
  }

  void onResizeControlPanEnd(int controlIndex,
      MapEntry<int, ObjectDrawable> entry, DragEndDetails details) {
    setState(() {
      controlsAreActive[controlIndex] = false;
    });
    onDrawableScaleEnd(entry);
  }

  void onTransformUpdated() {
    final m4storage =
        PainterController.of(context).transformationController.value.storage;
    final scale = m4storage[0];
    setState(() {
      transformationScale = scale;
    });
  }
}

Rect? getDrawableBounds(Drawable drawable) {
  if (drawable is ObjectDrawable) {
    final size = drawable.getSize();
    final center = drawable.position;
    final angle = drawable.rotationAngle;

    if (size.width <= 0 || size.height <= 0) return null;

    final double sinAngle = math.sin(angle);
    final double cosAngle = math.cos(angle);
    final double dx = (size.width / 2 * drawable.scale).abs();
    final double dy = (size.height / 2 * drawable.scale).abs();

    final Offset tl = Offset(center.dx + (-dx * cosAngle - -dy * sinAngle),
        center.dy + (-dx * sinAngle + -dy * cosAngle));
    final Offset tr = Offset(center.dx + (dx * cosAngle - -dy * sinAngle),
        center.dy + (dx * sinAngle + -dy * cosAngle));
    final Offset bl = Offset(center.dx + (-dx * cosAngle - dy * sinAngle),
        center.dy + (-dx * sinAngle + dy * cosAngle));
    final Offset br = Offset(center.dx + (dx * cosAngle - dy * sinAngle),
        center.dy + (dx * sinAngle + dy * cosAngle));

    final double minX = [tl.dx, tr.dx, bl.dx, br.dx].reduce(math.min);
    final double maxX = [tl.dx, tr.dx, bl.dx, br.dx].reduce(math.max);
    final double minY = [tl.dy, tr.dy, bl.dy, br.dy].reduce(math.min);
    final double maxY = [tl.dy, tr.dy, bl.dy, br.dy].reduce(math.max);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  } else if (drawable is PathDrawable) {
    if (drawable.path.isEmpty) return null;
    return drawable.path.getBounds().inflate(drawable.strokeWidth / 2);
  }
  return null;
}

extension PathBounds on List<Offset> {
  Rect getBounds() {
    if (isEmpty) return Rect.zero;
    double left = this[0].dx;
    double top = this[0].dy;
    double right = this[0].dx;
    double bottom = this[0].dy;
    for (final offset in this) {
      if (offset.dx < left) left = offset.dx;
      if (offset.dx > right) right = offset.dx;
      if (offset.dy < top) top = offset.dy;
      if (offset.dy > bottom) bottom = offset.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class _ObjectControlBox extends StatelessWidget {
  final BoxShape shape;
  final bool active;
  final Color inactiveColor;
  final Color? activeColor;
  final Color shadowColor;

  const _ObjectControlBox({
    Key? key,
    this.shape = BoxShape.rectangle,
    this.active = false,
    this.inactiveColor = Colors.white,
    this.activeColor,
    this.shadowColor = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData? theme = Theme.of(context);
    if (theme == ThemeData.fallback()) theme = null;
    final effectiveActiveColor =
        activeColor ?? theme?.colorScheme.secondary ?? Colors.blue;
    return AnimatedContainer(
      duration: _ObjectWidgetState.controlsTransitionDuration,
      decoration: BoxDecoration(
        color: active ? effectiveActiveColor : inactiveColor,
        shape: shape,
        boxShadow: [
          if (!usingHtmlRenderer)
            BorderBoxShadow(
              color: shadowColor,
              blurRadius: 2,
            )
          else
            BoxShadow(
              color: shadowColor,
              blurRadius: 2,
            )
        ],
      ),
    );
  }
}
