library mask;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'proxy_box.dart';

/// Created by box on 2021/12/4.
///
/// 遮罩
class CavityMask extends SingleChildRenderObjectWidget {
  /// 构造mask
  const CavityMask({
    Key? key,
    required this.color,
    this.position = DecorationPosition.foreground,
    Widget? child,
  }) : super(key: key, child: child);

  /// 颜色
  final Color color;

  /// Whether to paint the box decoration behind or in front of the child.
  final DecorationPosition position;

  @override
  _RenderCavityMask createRenderObject(BuildContext context) {
    return _RenderCavityMask(color: color, position: position);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderCavityMask renderObject) {
    renderObject
      ..color = color
      ..position = position;
  }
}

class _RenderCavityMask extends RenderProxyBox {
  _RenderCavityMask({
    required Color color,
    required DecorationPosition position,
  })  : _position = position,
        _paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

  final Paint _paint;

  Color get color => _paint.color;

  set color(Color value) {
    if (value == color) {
      return;
    }
    _paint.color = value;
    markNeedsPaint();
  }

  DecorationPosition _position;

  DecorationPosition get position => _position;

  set position(DecorationPosition value) {
    if (value == position) {
      return;
    }
    _position = value;
    markNeedsPaint();
  }

  void _paintColor(Canvas canvas, Rect rect) {
    canvas.save();
    final path1 = Path();
    path1.addRect(rect);

    final path2 = Path();
    path2.fillType = PathFillType.nonZero;

    void visitChildren(RenderObject child) {
      if (child is _RenderCavity) {
        if (child._clip != null) {
          path2.addPath(child.clipPath, child.localToGlobal(Offset.zero));
        }
      } else if (child is! _RenderCavityMask) {
        child.visitChildren(visitChildren);
      }
    }

    this.visitChildren(visitChildren);

    canvas.drawPath(
      Path.combine(PathOperation.difference, path1, path2),
      _paint,
    );
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size != Size.zero && position == DecorationPosition.background) {
      _paintColor(context.canvas, offset & size);
    }
    if (child != null) {
      super.paint(context, offset);
    }
    if (size != Size.zero && position == DecorationPosition.foreground) {
      _paintColor(context.canvas, offset & size);
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
