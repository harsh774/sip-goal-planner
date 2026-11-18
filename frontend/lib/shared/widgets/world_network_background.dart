import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Blurred backdrop for the auth pages: a dotted globe with money routes
/// arcing between countries and a rising market line across it.
class WorldNetworkBackground extends StatelessWidget {
  const WorldNetworkBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: CustomPaint(painter: _WorldPainter(), size: Size.infinite),
        ),
      ),
    );
  }
}

class _WorldPainter extends CustomPainter {
  // Rough (longitude, latitude) of financial centres.
  static const _cities = [
    (72.9, 19.1),
    (77.2, 28.6),
    (-74.0, 40.7),
    (-0.1, 51.5),
    (55.3, 25.2),
    (103.8, 1.35),
    (139.7, 35.7),
    (151.2, -33.9),
    (-46.6, -23.5),
    (8.7, 50.1),
    (121.5, 31.2),
    (-79.4, 43.7),
  ];
  static const _routes = [
    (0, 2),
    (0, 3),
    (0, 4),
    (0, 5),
    (1, 6),
    (3, 9),
    (2, 11),
    (4, 5),
    (5, 7),
    (6, 10),
    (8, 2),
    (3, 4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) * 0.42;
    final centre = Offset(size.width * 0.62, size.height * 0.5);
    const tilt = 0.35;
    const spin = -1.2;

    Offset? project(double lon, double lat) {
      final l = lon * math.pi / 180 + spin;
      final p = lat * math.pi / 180;
      final x = math.cos(p) * math.sin(l);
      final y = math.sin(p);
      final z = math.cos(p) * math.cos(l);
      final y2 = y * math.cos(tilt) - z * math.sin(tilt);
      final z2 = y * math.sin(tilt) + z * math.cos(tilt);
      if (z2 < -0.05) return null;
      return centre + Offset(x * r, -y2 * r);
    }

    canvas.drawCircle(
      centre,
      r * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.gold.withValues(alpha: 0.18), Colors.transparent],
        ).createShader(Rect.fromCircle(center: centre, radius: r * 1.15)),
    );

    final grid = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var lat = -60; lat <= 60; lat += 30) {
      _polyline(canvas, [
        for (var lon = -180; lon <= 180; lon += 6) project(lon.toDouble(), lat.toDouble()),
      ], grid);
    }
    for (var lon = -180; lon < 180; lon += 30) {
      _polyline(canvas, [
        for (var lat = -90; lat <= 90; lat += 6) project(lon.toDouble(), lat.toDouble()),
      ], grid);
    }
    canvas.drawCircle(centre, r, grid..color = AppColors.gold.withValues(alpha: 0.3));

    final route = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final (a, b) in _routes) {
      final pa = project(_cities[a].$1, _cities[a].$2);
      final pb = project(_cities[b].$1, _cities[b].$2);
      if (pa == null || pb == null) continue;
      final mid = (pa + pb) / 2;
      final lift = (mid - centre) * 0.35;
      canvas.drawPath(
        Path()
          ..moveTo(pa.dx, pa.dy)
          ..quadraticBezierTo(mid.dx + lift.dx, mid.dy + lift.dy, pb.dx, pb.dy),
        route,
      );
    }
    for (final (lon, lat) in _cities) {
      final p = project(lon, lat);
      if (p == null) continue;
      canvas.drawCircle(p, 6, Paint()..color = AppColors.gold.withValues(alpha: 0.25));
      canvas.drawCircle(p, 3, Paint()..color = AppColors.goldHover);
    }

    // Rising market line with an arrow head, sweeping across the globe.
    final rnd = math.Random(7);
    final pts = <Offset>[];
    var y = size.height * 0.82;
    for (var i = 0; i <= 14; i++) {
      final x = size.width * (0.05 + i * 0.065);
      y -= size.height * (0.02 + rnd.nextDouble() * 0.04) * (i.isEven ? 1.4 : -0.5);
      pts.add(Offset(x, y));
    }
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.success.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    final tip = pts.last;
    final dir = (tip - pts[pts.length - 2]).direction;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + 16 * math.cos(dir), tip.dy + 16 * math.sin(dir))
        ..lineTo(tip.dx + 10 * math.cos(dir + 2.3), tip.dy + 10 * math.sin(dir + 2.3))
        ..lineTo(tip.dx + 10 * math.cos(dir - 2.3), tip.dy + 10 * math.sin(dir - 2.3))
        ..close(),
      Paint()..color = AppColors.success.withValues(alpha: 0.7),
    );
  }

  void _polyline(Canvas canvas, List<Offset?> points, Paint paint) {
    Path? path;
    for (final p in points) {
      if (p == null) {
        if (path != null) canvas.drawPath(path, paint);
        path = null;
      } else if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WorldPainter old) => false;
}
