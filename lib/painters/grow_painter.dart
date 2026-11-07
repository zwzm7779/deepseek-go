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

/// 猫的像素掩码：0 空、1 身体、2 花纹、3 耳朵、4 眼睛、5 鼻子、6 铃铛、7 轮廓
class CatSprite {
  static const int w = 26, h = 30;

  static List<List<int>> build(CatPose pose) {
    final g = List.generate(h, (_) => List.filled(w, 0));

    void set(int x, int y, int v) {
      if (x >= 0 && x < w && y >= 0 && y < h) g[y][x] = v;
    }

    void ellipse(double cx, double cy, double rx, double ry, int v) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final dx = (x + 0.5 - cx) / rx;
          final dy = (y + 0.5 - cy) / ry;
          if (dx * dx + dy * dy <= 1) set(x, y, v);
        }
      }
    }

    void tri(List<List<int>> pts, int v) {
      int sign(int ax, int ay, int bx, int by, int cx, int cy) =>
          (ax - cx) * (by - cy) - (bx - cx) * (ay - cy);
      final a = pts[0], b = pts[1], c = pts[2];
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final d1 = sign(x, y, a[0], a[1], b[0], b[1]);
          final d2 = sign(x, y, b[0], b[1], c[0], c[1]);
          final d3 = sign(x, y, c[0], c[1], a[0], a[1]);
          final neg = d1 < 0 || d2 < 0 || d3 < 0;
          final pos = d1 > 0 || d2 > 0 || d3 > 0;
          if (!(neg && pos)) set(x, y, v);
        }
      }
    }

    switch (pose) {
      case CatPose.sit:
        ellipse(13, 22, 7.2, 7.0, 1); // 身体
        ellipse(13, 10, 8.2, 7.4, 1); // 头
        tri([[5, 5], [9, 3], [8, 9]], 3);
        tri([[21, 5], [17, 3], [18, 9]], 3);
        ellipse(9.5, 23, 3.2, 4.0, 2); // 花纹
        set(10, 10, 4);
        set(11, 10, 4);
        set(16, 10, 4);
        set(17, 10, 4);
        set(13, 13, 5);
        set(13, 18, 6);
        // 尾巴
        for (var i = 0; i < 6; i++) {
          set(21 + (i > 3 ? 1 : 0), 22 - i, 1);
        }
        break;
      case CatPose.lie:
        ellipse(13, 25, 10.5, 4.2, 1);
        ellipse(8, 19, 7.4, 6.2, 1);
        tri([[2, 15], [5, 14], [5, 19]], 3);
        tri([[14, 15], [11, 14], [11, 19]], 3);
        ellipse(5, 26, 3.0, 2.6, 2);
        set(6, 19, 4);
        set(7, 19, 4);
        set(11, 19, 4);
        set(12, 19, 4);
        set(9, 21, 5);
        for (var i = 0; i < 7; i++) {
          set(22 + (i > 4 ? 1 : 0), 26 - (i ~/ 2), 1);
        }
        break;
      case CatPose.sleep:
        ellipse(13, 25, 10.5, 4.2, 1);
        ellipse(8, 19, 7.4, 6.2, 1);
        tri([[2, 15], [5, 14], [5, 19]], 3);
        tri([[14, 15], [11, 14], [11, 19]], 3);
        ellipse(5, 26, 3.0, 2.6, 2);
        set(6, 19, 4);
        set(7, 19, 4);
        set(11, 19, 4);
        set(12, 19, 4);
        set(9, 21, 5);
        for (var i = 0; i < 7; i++) {
          set(22 + (i > 4 ? 1 : 0), 26 - (i ~/ 2), 1);
        }
        break;
      case CatPose.walk:
        ellipse(13, 22, 8.0, 4.6, 1);
        ellipse(9, 13, 7.0, 6.4, 1);
        tri([[3, 9], [6, 8], [6, 13]], 3);
        tri([[15, 9], [12, 8], [12, 13]], 3);
        set(7, 13, 4);
        set(8, 13, 4);
        set(12, 13, 4);
        set(13, 13, 4);
        set(10, 15, 5);
        for (var i = 0; i < 4; i++) {
          set(6 + i * 3, 26, 1);
        }
        for (var i = 0; i < 7; i++) {
          set(21 + (i > 4 ? 1 : 0), 22 - (i ~/ 2), 1);
        }
        break;
    }

    // 轮廓：贴着形状外侧描一圈
    final out = List.generate(h, (y) => List<int>.from(g[y]));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (g[y][x] != 0) continue;
        var near = false;
        for (final d in const [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1]
        ]) {
          final nx = x + d[0], ny = y + d[1];
          if (nx >= 0 && nx < w && ny >= 0 && ny < h && g[ny][nx] != 0) {
            near = true;
            break;
          }
        }
        if (near) out[y][x] = 7;
      }
    }
    return out;
  }
}

class GrowPainter extends CustomPainter {
  GrowPainter(this.scene);

  final Scene scene;

  static const Color catBody = Color(0xFFF8F5F2);
  static const Color catPatch = Color(0xFFD7D3CF);
  static const Color catLine = Color(0xFF7C7671);
  static const Color catEar = Color(0xFFF2C4C9);
  static const Color catInk = Color(0xFF4F4B52);
  static const Color catNose = Color(0xFFE3A7B0);
  static const Color catBell = Color(0xFFEFC469);

  final Paint _p = Paint()..style = PaintingStyle.fill;

  static List<List<int>>? _spriteSit, _spriteLie, _spriteSleep, _spriteWalk;

  List<List<int>> _sprite(CatPose pose) {
    switch (pose) {
      case CatPose.sit:
        return _spriteSit ??= CatSprite.build(CatPose.sit);
      case CatPose.lie:
        return _spriteLie ??= CatSprite.build(CatPose.lie);
      case CatPose.sleep:
        return _spriteSleep ??= CatSprite.build(CatPose.sleep);
      case CatPose.walk:
        return _spriteWalk ??= CatSprite.build(CatPose.walk);
    }
  }

  void _px(Canvas c, double x, double y, Color col, [double w = 1, double h = 1]) {
    _p.color = col;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 160;
    final h = size.height / u;
    canvas.save();
    canvas.scale(u);
    _sky(canvas, h);
    _sunMoon(canvas, h);
    _clouds(canvas, h);
    _ground(canvas, h);
    _leaves(canvas, h);
    _cat(canvas, h);
    if (scene.umbrella > 0.02) _umbrella(canvas, h);
    _precip(canvas, h);
    canvas.restore();
  }

  // ---------- 天空 ----------

  List<Color> _skyColors() {
    final hr = WeatherEngine.hourOf(scene.time);
    const stops = [
      [0.0, 222, 228, 240, 236, 240, 246],
      [4.6, 222, 228, 240, 236, 240, 246],
      [6.1, 252, 231, 212, 254, 242, 229],
      [8.4, 253, 249, 241, 251, 250, 248],
      [16.2, 253, 248, 238, 251, 250, 248],
      [18.1, 249, 218, 196, 253, 240, 226],
      [20.6, 222, 228, 240, 236, 240, 246],
      [24.0, 222, 228, 240, 236, 240, 246],
    ];
    var a = stops.first, b = stops.last;
    for (var i = 0; i < stops.length - 1; i++) {
      if (hr >= stops[i][0] && hr < stops[i + 1][0]) {
        a = stops[i];
        b = stops[i + 1];
        break;
      }
    }
    final span = b[0] - a[0];
    final t = span > 0 ? ((hr - a[0]) / span).clamp(0.0, 1.0).toDouble() : 0.0;
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

  void _sky(Canvas c, double h) {
    final col = _skyColors();
    final rect = Rect.fromLTWH(0, 0, 160, h);
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [col[0], _blend(col[0], col[1], 0.6), col[1]],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rect);
    c.drawRect(rect, _p);
    _p.shader = null;
  }

  void _disc(Canvas c, double cx, double cy, double r, Color col) {
    _p.color = col;
    for (var y = -r; y <= r; y += 0.7) {
      final half = sqrt(max(0.0, r * r - y * y));
      c.drawRect(Rect.fromLTWH(cx - half, cy + y, half * 2, 0.8), _p);
    }
  }

  void _sunMoon(Canvas c, double h) {
    final s = scene.season;
    final hr = WeatherEngine.hourOf(scene.time);
    final rise = WeatherEngine.sunrise(s);
    final set = WeatherEngine.sunset(s);
    if (hr >= rise && hr < set) {
      final t = ((hr - rise) / (set - rise)).clamp(0.0, 1.0).toDouble();
      final sx = 24 + t * 112;
      final sy = 42 - sin(t * pi) * 20;
      final bright = (s == Season.summer ? 1.0 : (s == Season.winter ? 0.82 : 0.92)) *
          (0.45 + 0.55 * (min(hr - rise, set - hr) / 1.3).clamp(0.0, 1.0).toDouble());
      final glow = s == Season.summer
          ? const Color(0xFFFBE7A8)
          : (s == Season.winter ? const Color(0xFFE9E5DA) : const Color(0xFFF8E2B0));
      _disc(c, sx, sy, 8, glow.withOpacity(0.10 * bright));
      _disc(c, sx, sy, 6, glow.withOpacity(0.18 * bright));
      _disc(c, sx, sy, 4,
          (s == Season.summer ? const Color(0xFFF8D680) : const Color(0xFFF4D696))
              .withOpacity(0.95 * bright));
    } else {
      final span = 24 - set + rise;
      final tt = (hr >= set ? (hr - set) / span : (hr + 24 - set) / span)
          .clamp(0.0, 1.0)
          .toDouble();
      final mx = 24 + tt * 112;
      final my = 42 - sin(tt * pi) * 20;
      _disc(
          c,
          mx,
          my,
          3.6,
          (s == Season.winter ? const Color(0xFFF3ECD8) : const Color(0xFFF0DFA8))
              .withOpacity(0.9));
    }
  }

  void _clouds(Canvas c, double h) {
    final dark = scene.weather == WeatherType.overcast || scene.weather == WeatherType.rain;
    final show = scene.weather == WeatherType.sunny ? 2 : 3;
    final base = dark ? const Color(0xFFD9D9E1) : const Color(0xFFF4F0EA);
    final light = dark ? const Color(0xFFC9C9D4) : const Color(0xFFE8E1D7);
    const xs = [10.0, 78.0, 126.0];
    final ys = [h * 0.10, h * 0.16, h * 0.065];
    const ws = [15.0, 11.0, 13.0];
    for (var i = 0; i < show; i++) {
      final x = xs[i], y = ys[i], w = ws[i];
      _px(c, x + 2, y, base, w * 0.34, 1.4);
      _px(c, x + w * 0.04, y + 1.2, base, w * 0.92, 1.6);
      _px(c, x, y + 2.6, light, w, 1.6);
      _px(c, x + 1, y + 4.2, light, w - 2, 1.2);
    }
  }

  // ---------- 地面 ----------

  double _groundBase(double h) => h - 40;

  double _top(double x, double h) {
    final t = ((x - 80) / 70).clamp(-1.0, 1.0).toDouble();
    return _groundBase(h) + 2.2 * t * t;
  }

  void _ground(Canvas c, double h) {
    final base = _groundBase(h);
    final path = Path()..moveTo(0, _top(0, h));
    for (var x = 0.0; x <= 160; x += 2) {
      path.lineTo(x, _top(x, h));
    }
    path
      ..lineTo(160, h)
      ..lineTo(0, h)
      ..close();
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFFDFEECD), Color(0xFFD4E7BD), Color(0xFFC6BBA5)],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(0, base, 160, 44));
    c.drawPath(path, _p);
    _p.shader = null;

    final wind = 0.55 + 0.55 * scene.windK;
    for (var i = 0; i < 42; i++) {
      final x = 6 + i * 3.8;
      final sy = _top(x, h);
      final sway = sin(scene.time.millisecondsSinceEpoch / 4200 + i) * 0.9 * wind;
      _p.color = i.isEven ? const Color(0xFFBCD9A6) : const Color(0xFFA9CD97);
      c.drawRect(Rect.fromLTWH(x, sy - 4, 1, 4), _p);
      c.drawRect(Rect.fromLTWH(x + sway.roundToDouble(), sy - 5, 1, 1), _p);
    }
    const flowers = [
      [18.0, 0xFFFDFCFA],
      [34.0, 0xFFF4CDD4],
      [52.0, 0xFFF7E9B6],
      [70.0, 0xFFDDD2EE],
      [88.0, 0xFFFDFCFA],
      [106.0, 0xFFF4CDD4],
      [124.0, 0xFFF7E9B6],
      [142.0, 0xFFDDD2EE],
    ];
    for (final f in flowers) {
      final x = f[0].toDouble();
      final y = _top(x, h) - 2;
      _p.color = const Color(0xFFB3D49C);
      c.drawRect(Rect.fromLTWH(x, y, 1, 3), _p);
      _p.color = Color(f[1].toInt());
      c.drawRect(Rect.fromLTWH(x - 1, y - 1, 3, 2), _p);
      c.drawRect(Rect.fromLTWH(x, y - 2, 1, 1), _p);
    }
  }

  void _leaves(Canvas c, double h) {
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

  Color _catColor(int v) => switch (v) {
        1 => catBody,
        2 => catPatch,
        3 => catEar,
        4 => catInk,
        5 => catNose,
        6 => catBell,
        _ => catLine,
      };

  void _cat(Canvas c, double h) {
    final x = scene.catX.roundToDouble();
    final gy = _top(x, h) + scene.bob;
    final sprite = _sprite(scene.pose);
    final ox = (x - 13).roundToDouble();
    final oy = (gy - 29).roundToDouble();

    _p.color = const Color(0x1A000000);
    c.drawOval(Rect.fromLTWH(x - 9, gy - 1.5, 18, 3), _p);

    for (var py = 0; py < CatSprite.h; py++) {
      for (var px = 0; px < CatSprite.w; px++) {
        final v = sprite[py][px];
        if (v == 0) continue;
        _px(c, ox + px, oy + py, _catColor(v));
      }
    }
  }

  // ---------- 伞 ----------

  void _umbrella(Canvas c, double h) {
    final x = scene.catX.roundToDouble();
    final gy = _top(x, h) + scene.bob;
    final r = 15.0 * scene.umbrella;
    final baseY = gy - 30;
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

  void _precip(Canvas c, double h) {
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
