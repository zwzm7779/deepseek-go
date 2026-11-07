import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/weather.dart';
import '../painters/grow_painter.dart';

const Color gBg = Color(0xFFFBFAF8);
const Color gInk = Color(0xFF3B3742);
const Color gInk2 = Color(0xFF8A8490);

class GrowPage extends StatefulWidget {
  const GrowPage({super.key});

  @override
  State<GrowPage> createState() => _GrowPageState();
}

class _GrowPageState extends State<GrowPage> with SingleTickerProviderStateMixin {
  final WeatherEngine _wx = WeatherEngine();
  final Random _rnd = Random();
  late final Ticker _ticker;

  final List<Drop> _rain = [];
  final List<Flake> _snow = [];
  final List<Leaf> _leaves = [];

  double _catX = 80;
  double _targetX = 80;
  CatPose _pose = CatPose.sit;
  int _poseUntil = 0;
  double _umbrella = 0;
  int _bob = 0;
  double _windK = 1;
  int _lastMs = 0;
  int _nextLeafAt = 0;
  int _weatherCheckAt = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _wx.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastMs == 0) _lastMs = nowMs;
    final dt = ((nowMs - _lastMs) / 1000).clamp(0.0, 0.06).toDouble();
    _lastMs = nowMs;

    if (nowMs > _weatherCheckAt) {
      _weatherCheckAt = nowMs + 30000;
      _wx.tick();
    }

    _windK = switch (_wx.type) {
      WeatherType.windy => 1.9,
      WeatherType.rain => 1.15,
      WeatherType.snow => 0.75,
      _ => 1.0,
    };

    _updateParticles(dt, nowMs);
    _updateCat(nowMs, dt);

    final wantUmbrella = _wx.isRaining && _pose != CatPose.walk ? 1.0 : 0.0;
    _umbrella += (wantUmbrella - _umbrella) * min(1.0, dt * 1.5);
    if (wantUmbrella == 0 && _umbrella < 0.02) _umbrella = 0;

    _bob = sin(nowMs / 3300) > 0.55 ? -1 : 0;

    if (mounted) setState(() {});
  }

  void _updateParticles(double dt, int nowMs) {
    if (_wx.type == WeatherType.rain) {
      while (_rain.length < 34) {
        _rain.add(Drop(_rnd.nextDouble() * 160,
            -40 + _rnd.nextDouble() * 180, 60 + _rnd.nextDouble() * 45,
            2 + _rnd.nextDouble()));
      }
    } else {
      _rain.clear();
    }
    if (_wx.type == WeatherType.snow) {
      while (_snow.length < 26) {
        _snow.add(Flake(_rnd.nextDouble() * 160,
            -30 + _rnd.nextDouble() * 170, 8 + _rnd.nextDouble() * 10,
            _rnd.nextDouble() * 6.28));
      }
    } else {
      _snow.clear();
    }

    for (final d in _rain) {
      d.y += d.v * dt;
      d.x += 18 * dt;
      if (d.y > 142) {
        d.y = -6 - _rnd.nextDouble() * 34;
        d.x = _rnd.nextDouble() * 160;
      }
      if (d.x > 164) d.x = -4;
    }
    for (final f in _snow) {
      f.y += f.v * dt;
      f.x += sin(nowMs / 1600 + f.phase) * 0.35;
      if (f.y > 142) {
        f.y = -6 - _rnd.nextDouble() * 24;
        f.x = _rnd.nextDouble() * 160;
      }
      if (f.x < -4) f.x = 164;
      if (f.x > 164) f.x = -4;
    }

    // 落叶 / 花瓣
    final spring = _wx.season == Season.spring;
    final autumn = _wx.season == Season.autumn;
    final cap = spring ? 6 : (autumn ? 7 : (_wx.season == Season.winter ? 2 : 4));
    if (nowMs > _nextLeafAt && _leaves.length < cap) {
      final petal = _rnd.nextDouble() < (spring ? 0.5 : (autumn ? 0.05 : 0.12));
      final color = petal
          ? const Color(0xFFF4C9CE)
          : (autumn ? const Color(0xFFE2B45E) : const Color(0xFFAECF9A));
      _leaves.add(Leaf(
        _rnd.nextDouble() * 144 + 8,
        -10,
        (_rnd.nextDouble() < 0.5 ? -1 : 1) * (1.2 + _rnd.nextDouble() * 2) * (0.7 + _windK * 0.5),
        3 + _rnd.nextDouble() * 4,
        _rnd.nextDouble() * 6.28,
        petal,
        color,
      ));
      _nextLeafAt = nowMs + (spring ? 1500 : (autumn ? 900 : 2600)) +
          _rnd.nextInt(1200);
    }
    for (final l in _leaves) {
      l.x += l.vx * dt;
      l.y += (l.vy + sin(nowMs / 2100 + l.phase) * 0.6) * dt;
    }
    _leaves.removeWhere((l) => l.y > 142 || l.x < -14 || l.x > 174);
  }

  void _updateCat(int nowMs, double dt) {
    if (nowMs < _poseUntil) {
      if (_pose == CatPose.walk) {
        final dir = (_targetX - _catX).sign;
        _catX += dir * 14 * dt;
        if ((_targetX - _catX).abs() < 1.5) {
          _catX = _targetX;
          _setPose(nowMs, CatPose.sit, 6);
        }
      }
      return;
    }
    if (_wx.isRaining) {
      // 雨天不散步：只坐、趴、睡
      final pick = _rnd.nextInt(3);
      _setPose(nowMs, pick == 0 ? CatPose.lie : (pick == 1 ? CatPose.sleep : CatPose.sit),
          8 + _rnd.nextInt(10));
      return;
    }
    final pick = _rnd.nextInt(4);
    if (pick == 0) {
      _targetX = 36 + _rnd.nextDouble() * 88;
      _setPose(nowMs, CatPose.walk, 5);
    } else if (pick == 1) {
      _setPose(nowMs, CatPose.sit, 8 + _rnd.nextInt(12));
    } else if (pick == 2) {
      _setPose(nowMs, CatPose.lie, 10 + _rnd.nextInt(12));
    } else {
      _setPose(nowMs, CatPose.sleep, 12 + _rnd.nextInt(14));
    }
  }

  void _setPose(int nowMs, CatPose pose, int seconds) {
    _pose = pose;
    _poseUntil = nowMs + seconds * 1000;
    if (pose == CatPose.sleep && !_wx.isRaining) _umbrella = 0;
  }

  @override
  Widget build(BuildContext context) {
    final season = _wx.loaded ? _wx.season : Season.spring;
    final weather = _wx.loaded ? _wx.type : WeatherType.sunny;

    return Scaffold(
      backgroundColor: gBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(season, weather),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 160 / 140,
                  child: CustomPaint(
                    painter: GrowPainter(Scene(
                      season: season,
                      weather: weather,
                      time: DateTime.now(),
                      catX: _catX,
                      pose: _pose,
                      umbrella: _umbrella,
                      bob: _bob,
                      rain: _rain,
                      snow: _snow,
                      leaves: _leaves,
                      windK: _windK,
                    )),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                '和小猫互动，可以提升好感度哦',
                style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: gInk2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Season season, WeatherType weather) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left, color: gInk2),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '宠物养成',
                style: TextStyle(fontSize: 14, letterSpacing: 2, color: gInk),
              ),
            ),
          ),
          Text(
            '${seasonName(season)} · ${weatherName(weather)}',
            style: const TextStyle(fontSize: 11, color: gInk2),
          ),
        ],
      ),
    );
  }
}
