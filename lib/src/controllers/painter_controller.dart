// lib/src/controllers/painter_controller.dart

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
// Impor yang diperlukan
import '../views/widgets/painter_controller_widget.dart';
import 'actions/actions.dart';
import 'drawables/image_drawable.dart'; // Pastikan ImageDrawable diimpor jika digunakan
import 'events/events.dart';
import 'drawables/background/background_drawable.dart';
import 'drawables/object_drawable.dart';
import 'settings/settings.dart';
import '../views/painters/painter.dart';
import 'drawables/drawable.dart';
import 'events/selected_object_drawable_removed_event.dart'; // Impor event remove

/// Controller used to control a FlutterPainter widget.
///
/// * IMPORTANT: *
/// Each FlutterPainter should have its own controller.
class PainterController extends ValueNotifier<PainterControllerValue> {
  /// A controller for an event stream which widgets will listen to.
  ///
  /// This will dispatch events that represent actions, such as adding a new text drawable.
  final StreamController<PainterEvent> _eventsStreamController;

  /// This key will be used by the FlutterPainter widget assigned this controller.
  final GlobalKey painterKey;

  /// This controller will be used by the InteractiveViewer in FlutterPainter to notify
  /// children widgets of transformation changes.
  final TransformationController transformationController;

  /// Create a [PainterController].
  PainterController({
    PainterSettings settings = const PainterSettings(),
    List<Drawable>? drawables, // Buat drawables opsional
    BackgroundDrawable? background,
  }) : this.fromValue(PainterControllerValue(
            settings: settings,
            drawables:
                drawables ?? const [], // Default ke list kosong jika null
            background: background));

  /// Create a [PainterController] from a [PainterControllerValue].
  PainterController.fromValue(PainterControllerValue value)
      : _eventsStreamController = StreamController<PainterEvent>.broadcast(),
        painterKey = GlobalKey(),
        transformationController = TransformationController(),
        super(value);

  /// The stream of [PainterEvent]s dispatched from this controller.
  Stream<PainterEvent> get events => _eventsStreamController.stream;

  /// Setting background.
  set background(BackgroundDrawable? background) =>
      value = value.copyWith(background: background);

  /// Queues used to track actions.
  Queue<ControllerAction> performedActions = DoubleLinkedQueue(),
      unperformedActions = DoubleLinkedQueue();

  /// Get PainterController from context.
  static PainterController of(BuildContext context) {
    return PainterControllerWidget.of(context).controller;
  }

  /// Add drawables.
  void addDrawables(Iterable<Drawable> drawables, {bool newAction = true}) {
    // Jangan tambahkan jika iterable kosong dan ini adalah aksi baru
    // untuk mencegah aksi kosong di history undo
    if (newAction && drawables.isEmpty) return;

    final action = AddDrawablesAction(drawables.toList());
    action.perform(this);
    _addAction(action, newAction);
  }

  /// Insert drawables.
  void insertDrawables(int index, Iterable<Drawable> drawables,
      {bool newAction = true}) {
    if (newAction && drawables.isEmpty) return; // Mencegah aksi kosong

    final action = InsertDrawablesAction(index, drawables.toList());
    action.perform(this);
    _addAction(action, newAction);
  }

  /// Replace drawable.
  bool replaceDrawable(Drawable oldDrawable, Drawable newDrawable,
      {bool newAction = true}) {
    // Modifikasi Anda: Pastikan newDrawable adalah ObjectDrawable jika oldDrawable adalah ObjectDrawable
    // Atau pastikan tipe dasarnya sama jika bukan ObjectDrawable
    if (oldDrawable is ObjectDrawable && newDrawable is! ObjectDrawable) {
      // print("Warning: Attempting to replace ObjectDrawable with non-ObjectDrawable.");
      return false;
    }
    // (Tambahan opsional: cek tipe lain jika perlu)

    final action = ReplaceDrawableAction(oldDrawable, newDrawable);
    final performed = action.perform(this);
    if (performed) _addAction(action, newAction);
    return performed;
  }

  /// Remove drawable.
  bool removeDrawable(Drawable drawable, {bool newAction = true}) {
    // Modifikasi Anda: Jangan dispose di sini
    final action = RemoveDrawableAction(drawable);
    final performed = action.perform(this);
    if (performed) {
      _addAction(action, newAction); // Hanya tambah aksi jika berhasil
    }
    return performed;
  }

  /// Remove last drawable.
  void removeLastDrawable({bool newAction = true}) {
    if (value.drawables.isNotEmpty) {
      removeDrawable(value.drawables.last, newAction: newAction);
    }
  }

  /// Clear drawables.
  void clearDrawables({bool newAction = true}) {
    // Modifikasi Anda: Hapus loop dispose
    final action = ClearDrawablesAction();
    action.perform(this);
    _addAction(action, newAction);
  }

  /// Group drawables.
  void groupDrawables({bool newAction = true}) {
    final action = MergeDrawablesAction();
    action.perform(this);
    _addAction(action, newAction);
  }

  // _addAction: Menambahkan aksi ke history dan menghapus history redo
  void _addAction(ControllerAction action, bool newAction) {
    performedActions.add(action);
    if (!newAction) _mergeAction(); // Gabungkan jika bukan aksi baru
    unperformedActions.clear(); // Hapus history redo saat aksi baru dilakukan
    // Panggil notifyListeners setelah state diubah oleh action.perform()
    // Meskipun ValueNotifier melakukannya, ini memastikan konsistensi jika ada listener lain
    notifyListeners();
  }

  /// Check if undo is possible.
  bool get canUndo => performedActions.isNotEmpty;

  /// Check if redo is possible.
  bool get canRedo => unperformedActions.isNotEmpty;

  /// Undo action.
  void undo() {
    if (!canUndo) return;
    final action = performedActions.removeLast();
    action.unperform(this);
    unperformedActions.add(action);
    notifyListeners(); // Panggil notifyListeners setelah undo
  }

  /// Redo action.
  void redo() {
    if (!canRedo) return;
    final action = unperformedActions.removeLast();
    action.perform(this);
    performedActions.add(action);
    notifyListeners(); // Panggil notifyListeners setelah redo
  }

  // Modifikasi Anda: Logika merge dipertahankan
  void _mergeAction() {
    if (performedActions.length < 2) return;
    final second = performedActions.removeLast();
    final first = performedActions.removeLast();
    final groupedAction = second.merge(first);
    if (groupedAction != null) performedActions.add(groupedAction);
  }

  /// Add text drawable event.
  void addText() {
    _eventsStreamController.add(const AddTextPainterEvent());
  }

  /// Add image drawable.
  void addImage(ui.Image image, [Size? size]) {
    // ... (kode ini tetap sama) ...
    final renderBox =
        painterKey.currentContext?.findRenderObject() as RenderBox?;
    final center = renderBox == null
        ? Offset.zero
        : Offset(renderBox.size.width / 2, renderBox.size.height / 2);
    final ImageDrawable drawable;
    if (size == null) {
      drawable = ImageDrawable(image: image, position: center);
    } else {
      drawable = ImageDrawable.fittedToSize(
          image: image, position: center, size: size);
    }
    addDrawables([drawable]);
  }

  /// Render image from drawables.
  Future<ui.Image> renderImage(Size size) async {
    // ... (kode ini tetap sama) ...
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = Painter(
      drawables: value.drawables,
      // Gunakan ukuran dari context jika ada, fallback ke size parameter
      scale: painterKey.currentContext?.size ?? size,
      background: value.background,
    );
    painter.paint(canvas, size);
    return await recorder
        .endRecording()
        .toImage(size.width.floor(), size.height.floor());
  }

  /// Get selected object drawable.
  ObjectDrawable? get selectedObjectDrawable => value.selectedObjectDrawable;

  /// Select object drawable.
  void selectObjectDrawable(ObjectDrawable? drawable) {
    if (drawable == value.selectedObjectDrawable) return;
    if (drawable != null && !value.drawables.contains(drawable)) return;
    // Update value dan panggil notifyListeners secara implisit oleh ValueNotifier
    value = value.copyWith(selectedObjectDrawable: drawable);
  }

  /// Deselect object drawable.
  void deselectObjectDrawable({bool isRemoved = false}) {
    if (selectedObjectDrawable != null && isRemoved) {
      _eventsStreamController.add(const SelectedObjectDrawableRemovedEvent());
    }
    selectObjectDrawable(null); // Ini akan memanggil notifyListeners
  }

  /// Dispose controller resources.
  @override
  void dispose() {
    _eventsStreamController.close();
    transformationController.dispose();
    super.dispose();
  }
} // <-- Akhir kelas PainterController

/// The current paint mode, drawables and background values of a [FlutterPainter] widget.
@immutable
class PainterControllerValue {
  /// The current paint mode of the widget.
  final PainterSettings settings;

  /// The list of drawables currently present to be painted.
  final List<Drawable> _drawables;

  /// The current background drawable of the widget.
  final BackgroundDrawable? background;

  /// The currently selected object drawable.
  final ObjectDrawable? selectedObjectDrawable;

  /// Modifikasi Anda: Set untuk menyimpan drawable yang sedang dihapus
  final Set<Drawable> drawablesBeingErased;

  /// Creates a new [PainterControllerValue] with the provided [settings] and [background].
  ///
  /// The user can pass a list of initial [drawables] which will be drawn without user interaction.
  const PainterControllerValue({
    required this.settings,
    List<Drawable> drawables = const [],
    this.background,
    this.selectedObjectDrawable,
    // Modifikasi Anda: Inisialisasi default
    this.drawablesBeingErased = const {},
  }) : _drawables = drawables;

  /// Getter for the current drawables.
  ///
  /// The returned list is unmodifiable.
  List<Drawable> get drawables => List.unmodifiable(_drawables);

  /// Creates a copy of this value but with the given fields replaced with the new values.
  PainterControllerValue copyWith({
    PainterSettings? settings,
    List<Drawable>? drawables,
    // Gunakan objek sentinel untuk background dan selectedObjectDrawable
    dynamic background =
        _NoBackgroundPassedBackgroundDrawable.instance, // Gunakan dynamic
    dynamic selectedObjectDrawable =
        _NoObjectPassedBackgroundDrawable.instance, // Gunakan dynamic
    Set<Drawable>? drawablesBeingErased, // Modifikasi Anda
  }) {
    // Logika copyWith dengan objek sentinel
    final BackgroundDrawable? finalBackground;
    if (background == _NoBackgroundPassedBackgroundDrawable.instance) {
      finalBackground = this.background;
    } else {
      finalBackground = background as BackgroundDrawable?; // Cast kembali
    }

    final ObjectDrawable? finalSelectedObjectDrawable;
    if (selectedObjectDrawable == _NoObjectPassedBackgroundDrawable.instance) {
      finalSelectedObjectDrawable = this.selectedObjectDrawable;
    } else {
      finalSelectedObjectDrawable =
          selectedObjectDrawable as ObjectDrawable?; // Cast kembali
    }

    return PainterControllerValue(
      settings: settings ?? this.settings,
      drawables: drawables ?? _drawables,
      background: finalBackground,
      selectedObjectDrawable: finalSelectedObjectDrawable,
      // Modifikasi Anda: Sertakan dalam copyWith
      drawablesBeingErased: drawablesBeingErased ?? this.drawablesBeingErased,
    );
  }

  /// Checks if two [PainterControllerValue] objects are equal or not.
  @override
  bool operator ==(Object other) {
    return other is PainterControllerValue &&
        (const ListEquality().equals(_drawables, other._drawables) &&
            background == other.background &&
            settings == other.settings &&
            selectedObjectDrawable == other.selectedObjectDrawable &&
            // Modifikasi Anda: Bandingkan set drawablesBeingErased
            const SetEquality()
                .equals(drawablesBeingErased, other.drawablesBeingErased));
  }

  @override
  int get hashCode => Object.hash(
      Object.hashAll(_drawables),
      background,
      settings,
      selectedObjectDrawable,
      Object.hashAll(drawablesBeingErased)); // Modifikasi Anda
}

// ... (Kelas sentinel _NoBackgroundPassedBackgroundDrawable dan _NoObjectPassedBackgroundDrawable tetap sama) ...
/// Private class that is used internally to represent no
/// [BackgroundDrawable] argument passed for [PainterControllerValue.copyWith].
class _NoBackgroundPassedBackgroundDrawable extends BackgroundDrawable {
  /// Single instance.
  static const _NoBackgroundPassedBackgroundDrawable instance =
      _NoBackgroundPassedBackgroundDrawable._();

  /// Private constructor.
  const _NoBackgroundPassedBackgroundDrawable._() : super();

  /// Unimplemented implementation of the draw method.
  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    throw UnimplementedError(
        "This background drawable is only to hold the default value in the PainterControllerValue copyWith method, and must not be used otherwise.");
  }
}

/// Private class that is used internally to represent no
/// [ObjectDrawable] argument passed for [PainterControllerValue.copyWith].
class _NoObjectPassedBackgroundDrawable extends ObjectDrawable {
  /// Single instance.
  static const _NoObjectPassedBackgroundDrawable instance =
      _NoObjectPassedBackgroundDrawable._();

  /// Private constructor.
  const _NoObjectPassedBackgroundDrawable._()
      : super(
          position: const Offset(0, 0),
        );

  @override
  ObjectDrawable copyWith(
      {bool? hidden,
      Set<ObjectDrawableAssist>? assists,
      ui.Offset? position,
      double? rotation,
      double? scale,
      bool? locked}) {
    throw UnimplementedError(
        "This object drawable is only to hold the default value in the PainterControllerValue copyWith method, and must not be used otherwise.");
  }

  @override
  void drawObject(ui.Canvas canvas, ui.Size size) {
    throw UnimplementedError(
        "This object drawable is only to hold the default value in the PainterControllerValue copyWith method, and must not be used otherwise.");
  }

  @override
  ui.Size getSize({double minWidth = 0.0, double maxWidth = double.infinity}) {
    throw UnimplementedError(
        "This object drawable is only to hold the default value in the PainterControllerValue copyWith method, and must not be used otherwise.");
  }
}
