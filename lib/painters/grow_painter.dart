import 'dart:math';
import 'package:flutter/material.dart';

import '../core/weather.dart';

enum CatPose { sit, lie, sleep, walk }

class Drop {
  double x, y;
  final double v, len;
  Drop(this.x, this.y, this.v, this.len);
}

class Flake {
  double x, y;
  final double v, phase;
  Flake(this.x, this.y, this.v, this.phase);
}

class Leaf {
  double x, y, vx, vy;
  final double phase;
  final bool petal;
  final Color color;
  Leaf(this.x, this.y, this.vx, this.vy, this.phase, this.petal, this.color);
}

class Scene {
  final Season season;
  final WeatherType weather;
  final DateTime time;
  final double catX;
  final CatPose pose;
  final double umbrella;
  final int bob;
  final List<Drop> rain;
  final List<Flake> snow;
  final List<Leaf> leaves;
  final double windK;

  Scene({
    required this.season,
    required this.weather,
    required this.time,
    required this.catX,
    required this.pose,
    required this.umbrella,
    required this.bob,
    required this.rain,
    required this.snow,
    required this.leaves,
    required this.windK,
  });
}

class GrowPainter extends CustomPainter {
  GrowPainter(this.scene);

  final Scene scene;

  static const Color ink = Color(0xFF3B3742);
  static const Color catBody = Color(0xFFF8F5F2);
  static const Color catPatch = Color(0xFFD7D3CF);
  static const Color catLine = Color(0xFF7C7671);
  static const Color catEar = Color(0xFFF2C4C9);
  static const Color catNose = Color(0xFFE3A7B0);

  final Paint _p = Paint()..style = PaintingStyle.fill;

  void _px(Canvas c, double x, double y, Color col) {
    _p.color = col;
    c.drawRect(Rect.fromLTWH(x, y, 1, 1), _p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 160;
    canvas.save();
    canvas.scale(k);
    _sky(canvas);
    _sunMoon(canvas);
    _clouds(canvas);
    _ground(canvas);
    _leaves(canvas);
    _cat(canvas);
    if (scene.umbrella > 0.02) _umbrella(canvas);
    _precip(canvas);
    canvas.restore();
  }

  // ---------- 天空 ----------

  List<Color> _skyColors() {
    final h = WeatherEngine.hourOf(scene.time);
    const stops = [
      [0.0, 224, 229, 240, 238, 241, 246],
      [4.6, 224, 229, 240, 238, 241, 246],
      [6.1, 252, 231, 212, 255, 243, 230],
      [8.4, 253, 249, 241, 251, 250, 248],
      [16.2, 253, 248, 238, 251, 250, 248],
      [18.1, 249, 218, 196, 253, 240, 226],
      [20.6, 224, 229, 240, 238, 241, 246],
      [24.0, 224, 229, 240, 238, 241, 246],
    ];
    var a = stops.first, b = stops.last;
    for (var i = 0; i < stops.length - 1; i++) {
      if (h >= stops[i][0] && h < stops[i + 1][0]) {
        a = stops[i];
        b = stops[i + 1];
        break;
      }
    }
    final span = b[0] - a[0];
    final t = span > 0 ? ((h - a[0]) / span).clamp(0.0, 1.0).toDouble() : 0.0;
    int mix(int i) => (a[i] + (b[i] - a[i]) * t).round();
    var top = Color.fromARGB(255, mix(1), mix(2), mix(3));
    var bottom = Color.fromARGB(255, mix(4), mix(5), mix(6));
    switch (scene.season) {
      case Season.winter:
        top = _blend(top, const Color(0xFFDCE6F2), 0.18);
        bottom = _blend(bottom, const Color(0xFFE6EEF7), 0.12);
        break;
      case Season.autumn:
        top = _blend(top, const Color(0xFFF7E6CE), 0.16);
        bottom = _blend(bottom, const Color(0xFFFBEFDD), 0.1);
        break;
      case Season.spring:
        top = _blend(top, const Color(0xFFFDEFF0), 0.08);
        break;
      case Season.summer:
        break;
    }
    return [top, bottom];
  }

  Color _blend(Color a, Color b, double t) => Color.fromARGB(
        255,
        (a.red + (b.red - a.red) * t).round(),
        (a.green + (b.green - a.green) * t).round(),
        (a.blue + (b.blue - a.blue) * t).round(),
      );

  void _sky(Canvas c) {
    final col = _skyColors();
    final rect = const Rect.fromLTWH(0, 0, 160, 140);
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [col[0], col[1]],
    ).createShader(rect);
    c.drawRect(rect, _p);
    _p.shader = null;
  }

  void _disc(Canvas c, double cx, double cy, double r, Color col) {
    _p.color = col;
    for (var y = -r; y <= r; y += 0.6) {
      final half = sqrt(max(0.0, r * r - y * y));
      c.drawRect(Rect.fromLTWH(cx - half, cy + y, half * 2, 0.75), _p);
    }
  }

  void _sunMoon(Canvas c) {
    final s = scene.season;
    final h = WeatherEngine.hourOf(scene.time);
    final rise = WeatherEngine.sunrise(s);
    final set = WeatherEngine.sunset(s);
    if (h >= rise && h < set) {
      final t = ((h - rise) / (set - rise)).clamp(0.0, 1.0).toDouble();
      final sx = 22 + t * 116;
      final sy = 18 - sin(t * pi) * 8;
      final bright = (s == Season.summer ? 1.0 : (s == Season.winter ? 0.8 : 0.92)) *
          (0.42 + 0.58 * (min(h - rise, set - h) / 1.3).clamp(0.0, 1.0).toDouble());
      final glow = s == Season.summer
          ? const Color(0xFFFBE7A8)
          : (s == Season.winter ? const Color(0xFFE9E5DA) : const Color(0xFFF8E2B0));
      _disc(c, sx, sy, 7, glow.withOpacity(0.12 * bright));
      _disc(c, sx, sy, 5.2, glow.withOpacity(0.2 * bright));
      _disc(c, sx, sy, 3.6,
          (s == Season.summer ? const Color(0xFFF8D680) : const Color(0xFFF4D696))
              .withOpacity(0.95 * bright));
    } else {
      final span = 24 - set + rise;
      final tt = (h >= set ? (h - set) / span : (h + 24 - set) / span).clamp(0.0, 1.0).toDouble();
      final mx = 22 + tt * 116;
      final my = 18 - sin(tt * pi) * 8;
      _disc(c, mx, my, 3.4,
          (s == Season.winter ? const Color(0xFFF3ECD8) : const Color(0xFFF0DFA8))
              .withOpacity(0.9));
    }
  }

  void _clouds(Canvas c) {
    final dark = scene.weather == WeatherType.overcast || scene.weather == WeatherType.rain;
    final show = scene.weather == WeatherType.sunny ? 2 : 3;
    final base = dark ? const Color(0xFFD9D9E1) : const Color(0xFFF2EEE8);
    final light = dark ? const Color(0xFFC9C9D4) : const Color(0xFFE4DDD3);
    const xs = [10.0, 78.0, 126.0];
    const ys = [16.0, 30.0, 13.0];
    const ws = [15.0, 11.0, 13.0];
    for (var i = 0; i < show; i++) {
      final x = xs[i], y = ys[i], w = ws[i];
      _p.color = base;
      c.drawRect(Rect.fromLTWH(x + 2, y, w * 0.34, 1.4), _p);
      c.drawRect(Rect.fromLTWH(x + w * 0.04, y + 1.2, w * 0.92, 1.6), _p);
      _p.color = light;
      c.drawRect(Rect.fromLTWH(x, y + 2.6, w, 1.6), _p);
      c.drawRect(Rect.fromLTWH(x + 1, y + 4.2, w - 2, 1.2), _p);
    }
  }

  // ---------- 地面 ----------

  double _top(double x) {
    final t = ((x - 80) / 70).clamp(-1.0, 1.0).toDouble();
    return 100 + 2.2 * t * t;
  }

  void _ground(Canvas c) {
    final path = Path()..moveTo(0, _top(0));
    for (var x = 0.0; x <= 160; x += 2) {
      path.lineTo(x, _top(x));
    }
    path
      ..lineTo(160, 140)
      ..lineTo(0, 140)
      ..close();
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFFDFEECD), const Color(0xFFD4E7BD), const Color(0xFFC6BBA5)],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(const Rect.fromLTWH(0, 96, 160, 44));
    c.drawPath(path, _p);
    _p.shader = null;

    // 草叶
    final wind = 0.55 + 0.55 * scene.windK;
    for (var i = 0; i < 34; i++) {
      final x = 14 + i * 4.0;
      final sy = _top(x);
      final sway = sin(scene.time.millisecondsSinceEpoch / 4200 + i) * 0.9 * wind;
      _p.color = i.isEven ? const Color(0xFFBCD9A6) : const Color(0xFFA9CD97);
      c.drawRect(Rect.fromLTWH(x, sy - 4, 1, 4), _p);
      c.drawRect(Rect.fromLTWH(x + sway.roundToDouble(), sy - 5, 1, 1), _p);
    }
    // 花
    const flowers = [
      [18.0, 0xFFFDFCFA],
      [29.0, 0xFFF4CDD4],
      [40.0, 0xFFF7E9B6],
      [52.0, 0xFFDDD2EE],
      [63.0, 0xFFFDFCFA],
      [98.0, 0xFFF4CDD4],
      [108.0, 0xFFF7E9B6],
      [128.0, 0xFFDDD2EE],
      [137.0, 0xFFF4CDD4],
    ];
    for (final f in flowers) {
      final x = f[0].toDouble();
      final y = _top(x) - 2;
      _p.color = const Color(0xFFB3D49C);
      c.drawRect(Rect.fromLTWH(x, y, 1, 3), _p);
      _p.color = Color(f[1].toInt());
      c.drawRect(Rect.fromLTWH(x - 1, y - 1, 3, 2), _p);
      c.drawRect(Rect.fromLTWH(x, y - 2, 1, 1), _p);
    }
  }

  // ---------- 落叶 / 花瓣 ----------

  void _leaves(Canvas c) {
    for (final l in scene.leaves) {
      _p.color = l.color.withOpacity(0.9);
      if (l.petal) {
        c.drawRect(Rect.fromLTWH(l.x, l.y, 2, 1), _p);
        c.drawRect(Rect.fromLTWH(l.x + 1, l.y + 1, 1, 1), _p);
      } else {
        c.drawRect(Rect.fromLTWH(l.x, l.y, 2, 1), _p);
        c.drawRect(Rect.fromLTWH(l.x + 1, l.y + 1, 1, 2), _p);
      }
    }
  }

  // ---------- 猫 ----------

  void _cat(Canvas c) {
    final x = scene.catX.roundToDouble();
    final gy = _top(x) + scene.bob;
    void px(double dx, double dy, Color col, [double w = 1, double h = 1]) {
      _p.color = col;
      c.drawRect(Rect.fromLTWH(x + dx, gy + dy, w, h), _p);
    }

    switch (scene.pose) {
      case CatPose.sit:
        px(-5, -9, catBody, 10, 7);
        px(-5, -2, catLine, 10, 1);
        px(-4, -17, catBody, 8, 8);
        px(-6, -19, catEar, 2, 3);
        px(4, -19, catEar, 2, 3);
        px(-4, -14, ink);
        px(3, -14, ink);
        px(-1, -12, catNose);
        px(5, -7, catPatch, 3, 2);
        px(5, -5, catBody, 1, 3);
        break;
      case CatPose.lie:
        px(-7, -5, catBody, 14, 4);
        px(-6, -1, catLine, 12, 1);
        px(-5, -10, catBody, 8, 6);
        px(-7, -12, catEar, 2, 3);
        px(5, -12, catEar, 2, 3);
        px(-4, -8, ink);
        px(2, -8, ink);
        px(-1, -7, catNose);
        px(7, -4, catPatch, 3, 2);
        break;
      case CatPose.sleep:
        px(-7, -5, catBody, 14, 4);
        px(-6, -1, catLine, 12, 1);
        px(-5, -10, catBody, 8, 6);
        px(-7, -12, catEar, 2, 3);
        px(5, -12, catEar, 2, 3);
        px(-4, -8, catLine, 2, 1);
        px(2, -8, catLine, 2, 1);
        px(-1, -7, catNose);
        break;
      case CatPose.walk:
        px(-4, -8, catBody, 9, 5);
        px(-5, -14, catBody, 7, 7);
        px(-7, -16, catEar, 2, 3);
        px(3, -16, catEar, 2, 3);
        px(-4, -11, ink);
        px(2, -11, ink);
        px(-1, -10, catNose);
        px(-3, -3, catLine, 1, 3);
        px(2, -3, catLine, 1, 3);
        px(-6, -6, catLine, 1, 4);
        break;
    }
    // 影子
    _p.color = const Color(0x22000000);
    c.drawOval(Rect.fromLTWH(x - 8, gy - 1, 16, 3), _p);
  }

  // ---------- 伞 ----------

  void _umbrella(Canvas c) {
    final x = scene.catX.roundToDouble();
    final gy = _top(x) + scene.bob;
    final r = 14.0 * scene.umbrella;
    final baseY = gy - 20;
    final ry = r * 0.62;
    for (var dy = -ry; dy <= 0; dy += 0.7) {
      final t = dy / ry;
      final half = r * sqrt(max(0.0, 1 - t * t));
      _p.color = const Color(0x2AA8BCCF);
      c.drawRect(Rect.fromLTWH(x - half, baseY + dy, half * 2, 0.8), _p);
      _p.color = const Color(0x8C7E8A9E);
      c.drawRect(Rect.fromLTWH(x - half, baseY + dy, 0.9, 0.8), _p);
      c.drawRect(Rect.fromLTWH(x + half - 0.9, baseY + dy, 0.9, 0.8), _p);
    }
    _p.color = const Color(0x8C7E8A9E);
    c.drawRect(Rect.fromLTWH(x - 0.4, baseY, 0.9, 6), _p);
  }

  // ---------- 雨雪 ----------

  void _precip(Canvas c) {
    if (scene.rain.isNotEmpty) {
      final paint = Paint()
        ..color = const Color(0x4D96A5BE)
        ..strokeWidth = 0.8;
      for (final d in scene.rain) {
        c.drawLine(Offset(d.x, d.y), Offset(d.x - 1, d.y - d.len), paint);
      }
    }
    if (scene.snow.isNotEmpty) {
      _p.color = const Color(0xD9FFFFFF);
      for (final f in scene.snow) {
        c.drawRect(Rect.fromLTWH(f.x, f.y, 1.1, 1.1), _p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GrowPainter old) => true;
}
