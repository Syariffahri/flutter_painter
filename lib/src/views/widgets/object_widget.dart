// lib/src/views/widgets/object_widget.dart

part of 'flutter_painter.dart';

/// Flutter widget to move, scale and rotate [ObjectDrawable]s.
class _ObjectWidget extends StatefulWidget {
  /// Child widget.
  final Widget child;

  /// Whether scaling is enabled or not.
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

  PainterController? controller;
  double transformationScale = 1;

  double get objectPadding => 25 / transformationScale;
  static Duration get controlsTransitionDuration =>
      const Duration(milliseconds: 100);
  double get controlsSize =>
      (settings.enlargeControlsResolver() ? 20 : 10) / transformationScale;
  double get selectedBlurRadius => 2 / transformationScale;
  double get selectedBorderWidth => 1 / transformationScale;

  Map<int, Offset> drawableInitialLocalFocalPoints = {};
  Map<int, ObjectDrawable> initialScaleDrawables = {};
  Map<ObjectDrawableAssist, Set<int>> assistDrawables = {
    for (var e in ObjectDrawableAssist.values) e: <int>{}
  };
  Map<int, bool> controlsAreActive = {
    for (var e in List.generate(12, (index) => index)) e: false,
  };

  StreamSubscription<PainterEvent>? controllerEventSubscription;

  List<ObjectDrawable> get drawables => PainterController.of(context)
      .value
      .drawables
      .whereType<ObjectDrawable>()
      .toList();

  bool cancelControlsAnimation = false;

  // [PERBAIKAN] Menggunakan MAP untuk menyimpan state awal dan akhir eraser
  // Key: Eraser Original (Saat Start Drag), Value: Eraser Terbaru (Saat Update)
  final Map<EraseDrawable, EraseDrawable> _linkedErasersMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timestamp) {
      controllerEventSubscription =
          PainterController.of(context).events.listen((event) {
        if (event is SelectedObjectDrawableRemovedEvent) {
          setState(() {
            cancelControlsAnimation = true;
          });
        }
      });
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
                  // Non-aktifkan interaksi shape saat mode DRAW atau ERASE aktif
                  child: freeStyleSettings.mode != FreeStyleMode.none
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

                                        // ROTATION HANDLE (Index 2)
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

                                        // HANDLES UNTUK 2D (KOTAK/LINGKARAN)
                                        if (entry.value is Sized2DDrawable) ...[
                                          // TOP-LEFT
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
                                                        true,
                                                        true),
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
                                          // TOP-RIGHT
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
                                                        true,
                                                        false),
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
                                          // BOTTOM-LEFT
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
                                                        false,
                                                        true),
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
                                          // BOTTOM-RIGHT
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
                                                        false,
                                                        false),
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
                                          // TOP CENTER
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
                                          // BOTTOM CENTER
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

                                        // HANDLES BERSAMA (2D & 1D - KIRI & KANAN)
                                        if (entry.value is Sized2DDrawable ||
                                            entry.value is Sized1DDrawable) ...[
                                          // LEFT CENTER (6)
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
                                          // RIGHT CENTER (7)
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

  // --- START EVENT (DENGAN MAGNETIC ERASER + MAP SNAPSHOT) ---
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

    // [FITUR] Magnetic Eraser: Inisialisasi Map
    _linkedErasersMap.clear();
    final currentController = PainterController.of(context);
    final allDrawables = currentController.value.drawables;

    final objectIndex = allDrawables.indexOf(drawable);
    final objectBounds = getDrawableBounds(drawable);

    if (objectBounds != null && objectIndex >= 0) {
      for (int i = objectIndex + 1; i < allDrawables.length; i++) {
        final d = allDrawables[i];
        if (d is EraseDrawable) {
          final eraseBounds = getDrawableBounds(d);
          if (eraseBounds != null && eraseBounds.overlaps(objectBounds)) {
            bool isAnchoredToStaticObject = false;
            for (int j = 0; j < i; j++) {
              final otherDrawable = allDrawables[j];
              if (otherDrawable != drawable &&
                  otherDrawable is ObjectDrawable) {
                final otherBounds = getDrawableBounds(otherDrawable);
                if (otherBounds != null && eraseBounds.overlaps(otherBounds)) {
                  isAnchoredToStaticObject = true;
                  break;
                }
              }
            }
            if (!isAnchoredToStaticObject) {
              // Key: Eraser Awal, Value: Eraser Awal (initially same)
              _linkedErasersMap[d] = d;
            }
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

  void onDrawableScaleEnd(MapEntry<int, ObjectDrawable> entry) {
    if (!widget.interactionEnabled) return;

    final index = entry.key;

    drawableInitialLocalFocalPoints.remove(index);
    initialScaleDrawables.remove(index);
    for (final assistSet in assistDrawables.values) {
      assistSet.remove(index);
    }
    _linkedErasersMap.clear();

    try {
      final ObjectDrawable drawable = drawables[index];
      final newDrawable = drawable.copyWith(assists: {});
      updateDrawable(drawable, newDrawable);
    } catch (e) {
      // Ignored
    }
  }

  // --- UPDATE EVENT (MOVE) ---
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

    // [FITUR] Update Eraser menggunakan Total Delta (Anti-Drift)
    final totalDelta = newDrawable.position - initialDrawable.position;
    final currentController = PainterController.of(context);

    if (totalDelta != Offset.zero && _linkedErasersMap.isNotEmpty) {
      _linkedErasersMap.forEach((initialEraser, currentEraser) {
        if (currentController.value.drawables.contains(currentEraser)) {
          final newPath =
              initialEraser.path.map((p) => p + totalDelta).toList();
          final newEraseDrawable = initialEraser.copyWith(path: newPath);
          currentController.replaceDrawable(currentEraser, newEraseDrawable,
              newAction: false);
          _linkedErasersMap[initialEraser] = newEraseDrawable;
        }
      });
    }

    updateDrawable(drawable, newDrawable);
  }

  // --- RESIZE SUDUT (CORNER) ---
  void onResizeCornerPanUpdate(
    MapEntry<int, ObjectDrawable> entry,
    DragUpdateDetails details,
    BoxConstraints constraints,
    bool isTop,
    bool isLeft,
  ) {
    final index = entry.key;
    final drawable = entry.value;

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
        axis: null,
        isTop: isTop,
        isLeft: isLeft,
      );
    }

    ObjectDrawable? newDrawableResult;

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
      newDrawableResult = drawable.copyWith(
        length: newLength,
        position: drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
      );
    } else if (drawable is Sized2DDrawable) {
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
      newDrawableResult = drawable.copyWith(
        size: newSize,
        position: drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
      );
    }

    if (newDrawableResult != null) {
      // [FITUR] Update Eraser saat Resize (Hanya geser posisi, tidak scale)
      // Agar eraser tetap berada di "tengah" relatif terhadap pergeseran pusat objek
      final currentController = PainterController.of(context);

      // Kita gunakan referensi 'initial' object untuk menghitung total displacement
      // Tapi karena resize mengubah ukuran, pusatnya bergeser.
      // Kita hitung delta dari posisi SEKARANG (drawable) ke POSISI BARU (newDrawableResult)
      final delta = newDrawableResult.position - drawable.position;

      if (delta != Offset.zero && _linkedErasersMap.isNotEmpty) {
        _linkedErasersMap.forEach((initialEraser, currentEraser) {
          if (currentController.value.drawables.contains(currentEraser)) {
            // Tambahkan delta ke path eraser SAAT INI
            // (Kita tidak pakai initialEraser di sini karena resize itu incremental)
            final newPath = currentEraser.path.map((p) => p + delta).toList();
            final newEraseDrawable = currentEraser.copyWith(path: newPath);

            currentController.replaceDrawable(currentEraser, newEraseDrawable,
                newAction: false);
            _linkedErasersMap[initialEraser] = newEraseDrawable;
          }
        });
      }

      updateDrawable(drawable, newDrawableResult);
    }
  }

  // --- LOGIKA RESIZE SISI (SIDE) ---
  void onResizeControlPanUpdate(MapEntry<int, ObjectDrawable> entry,
      DragUpdateDetails details, BoxConstraints constraints, Axis axis,
      [bool isReversed = true]) {
    final index = entry.key;
    final drawable = entry.value;

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

    ObjectDrawable? newDrawableResult;

    if (drawable is Sized1DDrawable) {
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
        newDrawableResult = drawable.copyWith(
          length: newLength,
          position:
              drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
        );
      }
    } else if (drawable is Sized2DDrawable) {
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
      newDrawableResult = drawable.copyWith(
        size: newSize,
        position: drawable.position + Offset(rotatedOffset.x, rotatedOffset.y),
      );
    }

    if (newDrawableResult != null) {
      // [FITUR] Update Eraser saat Resize (Sama seperti Corner)
      final delta = newDrawableResult.position - drawable.position;
      final currentController = PainterController.of(context);

      if (delta != Offset.zero && _linkedErasersMap.isNotEmpty) {
        _linkedErasersMap.forEach((initialEraser, currentEraser) {
          if (currentController.value.drawables.contains(currentEraser)) {
            final newPath = currentEraser.path.map((p) => p + delta).toList();
            final newEraseDrawable = currentEraser.copyWith(path: newPath);
            currentController.replaceDrawable(currentEraser, newEraseDrawable,
                newAction: false);
            _linkedErasersMap[initialEraser] = newEraseDrawable;
          }
        });
      }

      updateDrawable(drawable, newDrawableResult);
    }
  }

  ObjectSettings get settings =>
      PainterController.of(context).value.settings.object;
  FreeStyleSettings get freeStyleSettings =>
      PainterController.of(context).value.settings.freeStyle;

  void onBackgroundTapped() {
    SelectedObjectDrawableUpdatedNotification(null).dispatch(context);
    setState(() {
      controller?.deselectObjectDrawable();
    });
  }

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

  // (Sisanya seperti calculatePositionalAssists, calculateRotationalAssist, center, updateDrawable - TETAP SAMA)
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
}

// --- Helper Functions ---

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
