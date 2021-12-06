library mask;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'proxy_box.dart';

/// Where to paint a cavity mask.
enum MaskPosition {
  /// Paint the cavity mask behind the children.
  background,

  /// Paint the cavity mask in front of the children.
  foreground,
}

/// Created by box on 2021/12/4.
///
/// 遮罩
class CavityMask extends SingleChildRenderObjectWidget {
  /// 构造mask
  const CavityMask({
    Key? key,
    required this.color,
    this.barrier = false,
    this.position = MaskPosition.foreground,
    this.isComplex = false,
    this.willChange = false,
    Widget? child,
  })  : assert(position == MaskPosition.foreground || !barrier),
        super(key: key, child: child);

  /// 颜色
  final Color color;

  /// barrier
  final bool barrier;

  /// position
  final MaskPosition position;

  /// Whether the painting is complex enough to benefit from caching.
  ///
  /// The compositor contains a raster cache that holds bitmaps of layers in
  /// order to avoid the cost of repeatedly rendering those layers on each
  /// frame. If this flag is not set, then the compositor will apply its own
  /// heuristics to decide whether the this layer is complex enough to benefit
  /// from caching.
  ///
  /// This flag can't be set to true if both [painter] and [foregroundPainter]
  /// are null because this flag will be ignored in such case.
  final bool isComplex;

  /// Whether the raster cache should be told that this painting is likely
  /// to change in the next frame.
  ///
  /// This flag can't be set to true if both [painter] and [foregroundPainter]
  /// are null because this flag will be ignored in such case.
  final bool willChange;

  @override
  _RenderCavityMask createRenderObject(BuildContext context) {
    return _RenderCavityMask(
      color: color,
      barrier: barrier,
      position: position,
      isComplex: isComplex,
      willChange: willChange,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderCavityMask renderObject) {
    renderObject
      ..color = color
      ..barrier = barrier
      ..position = position
      ..isComplex = isComplex
      ..willChange = willChange;
  }
}

class _RenderCavityMask extends RenderProxyBox {
  _RenderCavityMask({
    required Color color,
    required bool barrier,
    required this.position,
    required this.isComplex,
    required this.willChange,
  })  : _paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill,
        _barrier = barrier;

  final Paint _paint;

  Color get color => _paint.color;

  set color(Color value) {
    if (value == color) {
      return;
    }
    _paint.color = value;
    markNeedsPaint();
  }

  bool get barrier => _barrier;

  set barrier(bool value) {
    if (value == _barrier) {
      return;
    }
    _barrier = value;
  }

  bool _barrier;

  MaskPosition position;

  /// Whether to hint that this layer's painting should be cached.
  ///
  /// The compositor contains a raster cache that holds bitmaps of layers in
  /// order to avoid the cost of repeatedly rendering those layers on each
  /// frame. If this flag is not set, then the compositor will apply its own
  /// heuristics to decide whether the this layer is complex enough to benefit
  /// from caching.
  bool isComplex;

  /// Whether the raster cache should be told that this painting is likely
  /// to change in the next frame.
  bool willChange;

  bool get _opaque => color.alpha != 0x00;

  final _children = <_RenderCavity>[];

  @override
  bool hitTest(BoxHitTestResult result, {required ui.Offset position}) {
    if (size.contains(position)) {
      if (this.position == MaskPosition.foreground && barrier && hitTestSelf(position) ||
          hitTestChildren(result, position: position) && hitTestSelf(position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return false;
  }

  @override
  bool hitTestSelf(ui.Offset position) {
    return _children.every((element) => element.clipPath?.contains(position) != true) && _opaque;
  }

  @override
  void performLayout() {
    _visitChildren();
    super.performLayout();
  }

  void _visitChildren() {
    _children.clear();
    void visitChildren(RenderObject child) {
      if (child is _RenderCavity) {
        _children.add(child);
      } else if (child is! _RenderCavityMask) {
        child.visitChildren(visitChildren);
      }
    }

    if (_opaque) {
      this.visitChildren(visitChildren);
    }
  }

  void _paintColor(Canvas canvas, Offset offset) {
    final rect = offset & size;
    canvas.save();
    final backgroundPath = Path();
    backgroundPath.addRect(rect);

    final clipPath = Path();
    clipPath.fillType = PathFillType.nonZero;

    for (var child in _children) {
      final path = child.clipPath;
      if (path != null && rect.overlaps(path.getBounds())) {
        clipPath.addPath(path, Offset.zero);
      }
    }

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, clipPath),
      _paint,
    );
    canvas.restore();
  }

  void _setRasterCacheHints(PaintingContext context) {
    if (isComplex) {
      context.setIsComplexHint();
    }
    if (willChange) {
      context.setWillChangeHint();
    }
  }

  void _markNeedsLayout() {
    if (_opaque && !debugNeedsLayout) {
      Timer.run(markNeedsLayout);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_opaque && size > Size.zero && position == MaskPosition.background) {
      _paintColor(context.canvas, offset);
      _setRasterCacheHints(context);
    }
    if (child != null) {
      context.paintChild(child!, offset);
    }
    if (_opaque && size > Size.zero && position == MaskPosition.foreground) {
      _paintColor(context.canvas, offset);
      _setRasterCacheHints(context);
    }
  }
}

/// rect
class CavityRect extends SingleChildRenderObjectWidget {
  /// Creates a rectangular clip.
  ///
  /// If [clipper] is null, the clip will match the layout size and position of
  /// the child.
  ///
  /// The [clipBehavior] argument must not be null or [Clip.none].
  const CavityRect({Key? key, this.clipper, this.clipBehavior = Clip.hardEdge, Widget? child})
      : super(key: key, child: child);

  /// If non-null, determines which clip to use.
  final CustomClipper<Rect>? clipper;

  /// {@macro flutter.rendering.ClipRectLayer.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  @override
  RenderCavityRect createRenderObject(BuildContext context) {
    assert(clipBehavior != Clip.none);
    return RenderCavityRect(clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCavityRect renderObject) {
    assert(clipBehavior != Clip.none);
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior;
  }

  @override
  void didUnmountRenderObject(RenderCavityRect renderObject) {
    renderObject.clipper = null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomClipper<Rect>>('clipper', clipper, defaultValue: null));
  }
}

/// rrect
class CavityRRect extends SingleChildRenderObjectWidget {
  /// Creates a rounded-rectangular clip.
  ///
  /// The [borderRadius] defaults to [BorderRadius.zero], i.e. a rectangle with
  /// right-angled corners.
  ///
  /// If [clipper] is non-null, then [borderRadius] is ignored.
  ///
  /// The [clipBehavior] argument must not be null or [Clip.none].
  const CavityRRect({
    Key? key,
    this.borderRadius = BorderRadius.zero,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    Widget? child,
  })  : assert(borderRadius != null || clipper != null),
        super(key: key, child: child);

  /// The border radius of the rounded corners.
  ///
  /// Values are clamped so that horizontal and vertical radii sums do not
  /// exceed width/height.
  ///
  /// This value is ignored if [clipper] is non-null.
  final BorderRadius? borderRadius;

  /// If non-null, determines which clip to use.
  final CustomClipper<RRect>? clipper;

  /// {@macro flutter.rendering.ClipRectLayer.clipBehavior}
  ///
  /// Defaults to [Clip.antiAlias].
  final Clip clipBehavior;

  @override
  RenderCavityRRect createRenderObject(BuildContext context) {
    assert(clipBehavior != Clip.none);
    return RenderCavityRRect(borderRadius: borderRadius!, clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCavityRRect renderObject) {
    assert(clipBehavior != Clip.none);
    renderObject
      ..borderRadius = borderRadius!
      ..clipBehavior = clipBehavior
      ..clipper = clipper;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius, showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<CustomClipper<RRect>>('clipper', clipper, defaultValue: null));
  }
}

/// oval
class CavityOval extends SingleChildRenderObjectWidget {
  /// Creates an oval-shaped clip.
  ///
  /// If [clipper] is null, the oval will be inscribed into the layout size and
  /// position of the child.
  ///
  /// The [clipBehavior] argument must not be null or [Clip.none].
  const CavityOval({Key? key, this.clipper, this.clipBehavior = Clip.antiAlias, Widget? child})
      : super(key: key, child: child);

  /// If non-null, determines which clip to use.
  ///
  /// The delegate returns a rectangle that describes the axis-aligned
  /// bounding box of the oval. The oval's axes will themselves also
  /// be axis-aligned.
  ///
  /// If the [clipper] delegate is null, then the oval uses the
  /// widget's bounding box (the layout dimensions of the render
  /// object) instead.
  final CustomClipper<Rect>? clipper;

  /// {@macro flutter.rendering.ClipRectLayer.clipBehavior}
  ///
  /// Defaults to [Clip.antiAlias].
  final Clip clipBehavior;

  @override
  RenderCavityOval createRenderObject(BuildContext context) {
    assert(clipBehavior != Clip.none);
    return RenderCavityOval(clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCavityOval renderObject) {
    assert(clipBehavior != Clip.none);
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior;
  }

  @override
  void didUnmountRenderObject(RenderCavityOval renderObject) {
    renderObject.clipper = null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomClipper<Rect>>('clipper', clipper, defaultValue: null));
  }
}

/// path
class CavityPath extends SingleChildRenderObjectWidget {
  /// Creates a path clip.
  ///
  /// If [clipper] is null, the clip will be a rectangle that matches the layout
  /// size and location of the child. However, rather than use this default,
  /// consider using a [ClipRect], which can achieve the same effect more
  /// efficiently.
  ///
  /// The [clipBehavior] argument must not be null or [Clip.none].
  const CavityPath({
    Key? key,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    Widget? child,
  }) : super(key: key, child: child);

  /// Creates a shape clip.
  ///
  /// Uses a [ShapeBorderClipper] to configure the [CavityPath] to clip to the
  /// given [ShapeBorder].
  static Widget shape({
    Key? key,
    required ShapeBorder shape,
    Clip clipBehavior = Clip.antiAlias,
    Widget? child,
  }) {
    assert(clipBehavior != Clip.none);
    return Builder(
      key: key,
      builder: (BuildContext context) {
        return CavityPath(
          clipper: ShapeBorderClipper(
            shape: shape,
            textDirection: Directionality.maybeOf(context),
          ),
          clipBehavior: clipBehavior,
          child: child,
        );
      },
    );
  }

  /// If non-null, determines which clip to use.
  ///
  /// The default clip, which is used if this property is null, is the
  /// bounding box rectangle of the widget. [ClipRect] is a more
  /// efficient way of obtaining that effect.
  final CustomClipper<Path>? clipper;

  /// {@macro flutter.rendering.ClipRectLayer.clipBehavior}
  ///
  /// Defaults to [Clip.antiAlias].
  final Clip clipBehavior;

  @override
  RenderCavityPath createRenderObject(BuildContext context) {
    assert(clipBehavior != Clip.none);
    return RenderCavityPath(clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCavityPath renderObject) {
    assert(clipBehavior != Clip.none);
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior;
  }

  @override
  void didUnmountRenderObject(RenderCavityPath renderObject) {
    renderObject.clipper = null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomClipper<Path>>('clipper', clipper, defaultValue: null));
  }
}
