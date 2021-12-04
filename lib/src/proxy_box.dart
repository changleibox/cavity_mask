part of mask;

/// Created by box on 2021/12/4.

abstract class _RenderCavity<T> extends RenderProxyBox {
  _RenderCavity({
    RenderBox? child,
    CustomClipper<T>? clipper,
    Clip clipBehavior = Clip.antiAlias,
  })  : _clipper = clipper,
        _clipBehavior = clipBehavior,
        super(child);

  /// If non-null, determines which clip to use on the child.
  CustomClipper<T>? get clipper => _clipper;
  CustomClipper<T>? _clipper;

  set clipper(CustomClipper<T>? newClipper) {
    if (_clipper == newClipper) {
      return;
    }
    final oldClipper = _clipper;
    _clipper = newClipper;
    assert(newClipper != null || oldClipper != null);
    if (newClipper == null ||
        oldClipper == null ||
        newClipper.runtimeType != oldClipper.runtimeType ||
        newClipper.shouldReclip(oldClipper)) {
      _markNeedsClip();
    }
    if (attached) {
      oldClipper?.removeListener(_markNeedsClip);
      newClipper?.addListener(_markNeedsClip);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clipper?.addListener(_markNeedsClip);
  }

  @override
  void detach() {
    _clipper?.removeListener(_markNeedsClip);
    super.detach();
  }

  void _markNeedsClip() {
    _clip = null;
    _clipPath = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  T get _defaultClip;

  T? _clip;

  Clip get clipBehavior => _clipBehavior;

  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
    }
  }

  Clip _clipBehavior;

  Path? get clipPath => _clipPath;
  Path? _clipPath;

  Path _createPath(Offset offset, T clip);

  @override
  void performLayout() {
    final oldSize = hasSize ? size : null;
    super.performLayout();
    if (oldSize != size) {
      _clip = null;
      _clipPath = null;
    }
  }

  void _updateClip() {
    _clip ??= _clipper?.getClip(size) ?? _defaultClip;
  }

  void _updateClipPath(Offset offset) {
    _clipPath = _createPath(offset, _clip!);
  }

  @override
  Rect describeApproximatePaintClip(RenderObject child) {
    return _clipper?.getApproximateClipRect(size) ?? Offset.zero & size;
  }

  Paint? _debugPaint;
  TextPainter? _debugText;

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      _debugPaint ??= Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(10.0, 10.0),
          <Color>[const Color(0x00000000), const Color(0xFFFF00FF), const Color(0xFFFF00FF), const Color(0x00000000)],
          <double>[0.25, 0.25, 0.75, 0.75],
          TileMode.repeated,
        )
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      _debugText ??= TextPainter(
        text: const TextSpan(
          text: '✂',
          style: TextStyle(
            color: Color(0xFFFF00FF),
            fontSize: 14.0,
          ),
        ),
        textDirection: TextDirection.rtl, // doesn't matter, it's one character
      )..layout();
      return true;
    }());
  }
}

/// Clips its child using a rectangle.
///
/// By default, [RenderCavityRect] prevents its child from painting outside its
/// bounds, but the size and location of the clip rect can be customized using a
/// custom [clipper].
class RenderCavityRect extends _RenderCavity<Rect> {
  /// Creates a rectangular clip.
  ///
  /// If [clipper] is null, the clip will match the layout size and position of
  /// the child.
  ///
  /// The [clipBehavior] must not be null or [Clip.none].
  RenderCavityRect({
    RenderBox? child,
    CustomClipper<Rect>? clipper,
    Clip clipBehavior = Clip.antiAlias,
  })  : assert(clipBehavior != Clip.none),
        super(child: child, clipper: clipper, clipBehavior: clipBehavior);

  @override
  Rect get _defaultClip => Offset.zero & size;

  @override
  ui.Path _createPath(ui.Offset offset, ui.Rect clip) {
    return Path()..addRect(clip.shift(offset));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      _updateClipPath(offset);
      layer = context.pushClipRect(
        needsCompositing,
        offset,
        _clip!,
        super.paint,
        clipBehavior: clipBehavior,
        oldLayer: layer as ClipRectLayer?,
      );
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawRect(_clip!.shift(offset), _debugPaint!);
        _debugText!
            .paint(context.canvas, offset + Offset(_clip!.width / 8.0, -_debugText!.text!.style!.fontSize! * 1.1));
      }
      return true;
    }());
  }
}

/// Clips its child using a rounded rectangle.
///
/// By default, [RenderCavityRRect] uses its own bounds as the base rectangle for
/// the clip, but the size and location of the clip can be customized using a
/// custom [clipper].
class RenderCavityRRect extends _RenderCavity<RRect> {
  /// Creates a rounded-rectangular clip.
  ///
  /// The [borderRadius] defaults to [BorderRadius.zero], i.e. a rectangle with
  /// right-angled corners.
  ///
  /// If [clipper] is non-null, then [borderRadius] is ignored.
  ///
  /// The [clipBehavior] argument must not be null or [Clip.none].
  RenderCavityRRect({
    RenderBox? child,
    BorderRadius borderRadius = BorderRadius.zero,
    CustomClipper<RRect>? clipper,
    Clip clipBehavior = Clip.antiAlias,
  })  : assert(clipBehavior != Clip.none),
        _borderRadius = borderRadius,
        super(child: child, clipper: clipper, clipBehavior: clipBehavior);

  /// The border radius of the rounded corners.
  ///
  /// Values are clamped so that horizontal and vertical radii sums do not
  /// exceed width/height.
  ///
  /// This value is ignored if [clipper] is non-null.
  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;

  set borderRadius(BorderRadius value) {
    if (_borderRadius == value) {
      return;
    }
    _borderRadius = value;
    _markNeedsClip();
  }

  @override
  RRect get _defaultClip => _borderRadius.toRRect(Offset.zero & size);

  @override
  ui.Path _createPath(ui.Offset offset, ui.RRect clip) {
    return Path()..addRRect(clip.shift(offset));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      _updateClipPath(offset);
      layer = context.pushClipRRect(
        needsCompositing,
        offset,
        _clip!.outerRect,
        _clip!,
        super.paint,
        clipBehavior: clipBehavior,
        oldLayer: layer as ClipRRectLayer?,
      );
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawRRect(_clip!.shift(offset), _debugPaint!);
        _debugText!.paint(context.canvas, offset + Offset(_clip!.tlRadiusX, -_debugText!.text!.style!.fontSize! * 1.1));
      }
      return true;
    }());
  }
}

/// Clips its child using an oval.
///
/// By default, inscribes an axis-aligned oval into its layout dimensions and
/// prevents its child from painting outside that oval, but the size and
/// location of the clip oval can be customized using a custom [clipper].
class RenderCavityOval extends _RenderCavity<Rect> {
  /// Creates an oval-shaped clip.
  ///
  /// If [clipper] is null, the oval will be inscribed into the layout size and
  /// position of the child.
  ///
  /// The [clipBehavior] argument must not be null or [Clip.none].
  RenderCavityOval({
    RenderBox? child,
    CustomClipper<Rect>? clipper,
    Clip clipBehavior = Clip.antiAlias,
  })  : assert(clipBehavior != Clip.none),
        super(child: child, clipper: clipper, clipBehavior: clipBehavior);

  Rect? _cachedRect;
  late Path _cachedPath;

  Path _getClipPath(Rect rect) {
    if (rect != _cachedRect) {
      _cachedRect = rect;
      _cachedPath = Path()..addOval(_cachedRect!);
    }
    return _cachedPath;
  }

  @override
  Rect get _defaultClip => Offset.zero & size;

  @override
  ui.Path _createPath(ui.Offset offset, ui.Rect clip) {
    return _getClipPath(clip)..shift(offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    _updateClip();
    assert(_clip != null);
    final center = _clip!.center;
    // convert the position to an offset from the center of the unit circle
    final offset = Offset(
      (position.dx - center.dx) / _clip!.width,
      (position.dy - center.dy) / _clip!.height,
    );
    // check if the point is outside the unit circle
    if (offset.distanceSquared > 0.25) {
      return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      _updateClipPath(offset);
      layer = context.pushClipPath(
        needsCompositing,
        offset,
        _clip!,
        _getClipPath(_clip!),
        super.paint,
        clipBehavior: clipBehavior,
        oldLayer: layer as ClipPathLayer?,
      );
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawPath(_getClipPath(_clip!).shift(offset), _debugPaint!);
        _debugText!.paint(context.canvas,
            offset + Offset((_clip!.width - _debugText!.width) / 2.0, -_debugText!.text!.style!.fontSize! * 1.1));
      }
      return true;
    }());
  }
}

/// Clips its child using a path.
///
/// Takes a delegate whose primary method returns a path that should
/// be used to prevent the child from painting outside the path.
///
/// Clipping to a path is expensive. Certain shapes have more
/// optimized render objects:
///
///  * To clip to a rectangle, consider [RenderCavityRect].
///  * To clip to an oval or circle, consider [RenderCavityOval].
///  * To clip to a rounded rectangle, consider [RenderCavityRRect].
class RenderCavityPath extends _RenderCavity<Path> {
  /// Creates a path clip.
  ///
  /// If [clipper] is null, the clip will be a rectangle that matches the layout
  /// size and location of the child. However, rather than use this default,
  /// consider using a [RenderCavityRect], which can achieve the same effect more
  /// efficiently.
  ///
  /// The [clipBehavior] argument must not be null or [Clip.none].
  RenderCavityPath({
    RenderBox? child,
    CustomClipper<Path>? clipper,
    Clip clipBehavior = Clip.antiAlias,
  })  : assert(clipBehavior != Clip.none),
        super(child: child, clipper: clipper, clipBehavior: clipBehavior);

  @override
  Path get _defaultClip => Path()..addRect(Offset.zero & size);

  @override
  ui.Path _createPath(ui.Offset offset, ui.Path clip) {
    return clip..shift(offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      _updateClip();
      _updateClipPath(offset);
      layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        _clip!,
        super.paint,
        clipBehavior: clipBehavior,
        oldLayer: layer as ClipPathLayer?,
      );
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        context.canvas.drawPath(_clip!.shift(offset), _debugPaint!);
        _debugText!.paint(context.canvas, offset);
      }
      return true;
    }());
  }
}
