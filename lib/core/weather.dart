import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum Season { spring, summer, autumn, winter }

enum WeatherType { sunny, cloudy, overcast, windy, rain, snow }

const int kSeasonMs = 3 * 86400000;

/// 固定基准点：2026-01-01 00:00 本地时间，之后每 3 天换一季。
final int kSeasonAnchor = DateTime(2026, 1, 1).millisecondsSinceEpoch;

String seasonName(Season s) => switch (s) {
      Season.spring => '春天',
      Season.summer => '夏天',
      Season.autumn => '秋天',
      Season.winter => '冬天',
    };

String weatherName(WeatherType w) => switch (w) {
      WeatherType.sunny => '晴天',
      WeatherType.cloudy => '多云',
      WeatherType.overcast => '阴天',
      WeatherType.windy => '大风',
      WeatherType.rain => '小雨',
      WeatherType.snow => '下雪',
    };

/// 四季天气状态机：季节由真实时间推算，天气带起止时间戳并持久化。
class WeatherEngine {
  static const String _key = 'daiyihui.weather.v2';

  WeatherType type = WeatherType.sunny;
  int start = 0;
  int until = 0;
  int seasonIndex = 0;
  bool loaded = false;

  final Random _rnd = Random();

  Season get season => Season.values[seasonIndex];
  bool get isRaining => type == WeatherType.rain;

  static const Map<Season, Map<WeatherType, int>> _weights = {
    Season.spring: {
      WeatherType.sunny: 40,
      WeatherType.cloudy: 20,
      WeatherType.overcast: 12,
      WeatherType.windy: 13,
      WeatherType.rain: 15,
      WeatherType.snow: 0,
    },
    Season.summer: {
      WeatherType.sunny: 44,
      WeatherType.cloudy: 16,
      WeatherType.overcast: 8,
      WeatherType.windy: 8,
      WeatherType.rain: 24,
      WeatherType.snow: 0,
    },
    Season.autumn: {
      WeatherType.sunny: 34,
      WeatherType.cloudy: 22,
      WeatherType.overcast: 12,
      WeatherType.windy: 18,
      WeatherType.rain: 14,
      WeatherType.snow: 0,
    },
    Season.winter: {
      WeatherType.sunny: 28,
      WeatherType.cloudy: 20,
      WeatherType.overcast: 16,
      WeatherType.windy: 10,
      WeatherType.rain: 4,
      WeatherType.snow: 22,
    },
  };

  int seasonAt(int ms) {
    final d = ((ms - kSeasonAnchor) / kSeasonMs).floor();
    return ((d % 4) + 4) % 4;
  }

  WeatherType _pick(Season s) {
    final table = _weights[s]!;
    final total = table.values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return WeatherType.sunny;
    var r = _rnd.nextInt(total);
    for (final e in table.entries) {
      r -= e.value;
      if (r < 0) return e.key;
    }
    return WeatherType.sunny;
  }

  int _durationMs() => (150 + _rnd.nextInt(180)) * 60000; // 2.5 ~ 5.5 小时

  /// 供测试与调试使用：某季某天气的权重。
  int weightOf(Season s, WeatherType w) => _weights[s]?[w] ?? 0;

  /// 供测试与调试使用：按权重抽一种天气。
  WeatherType pickFor(Season s) => _pick(s);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final si = seasonAt(now);
    try {
      final raw = jsonDecode(sp.getString(_key) ?? 'null');
      if (raw is Map) {
        final t = raw['type'];
        final u = raw['until'];
        final ss = raw['season'];
        if (t is String && u is int && ss == si && u > now && u - now < 8 * 3600000) {
          type = WeatherType.values.firstWhere((e) => e.name == t,
              orElse: () => WeatherType.sunny);
          start = (raw['start'] as int?) ?? now;
          until = u;
          seasonIndex = si;
          loaded = true;
          return;
        }
      }
    } catch (_) {}
    seasonIndex = si;
    start = now;
    type = _pick(season);
    until = now + _durationMs();
    loaded = true;
    await _save();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode({
        'type': type.name,
        'start': start,
        'until': until,
        'season': seasonIndex,
      }),
    );
  }

  /// 每次进页面或定时调用：季节变了或天气到期就换一种。
  Future<void> tick() async {
    if (!loaded) {
      await load();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final si = seasonAt(now);
    if (si != seasonIndex || now >= until) {
      seasonIndex = si;
      var next = _pick(season);
      if (next == type && _rnd.nextDouble() < 0.5) next = _pick(season);
      type = next;
      start = now;
      until = now + _durationMs();
      await _save();
    }
  }

  // ---------- 昼夜 ----------

  static double hourOf(DateTime t) =>
      t.hour + t.minute / 60 + t.second / 3600;

  static double sunrise(Season s) => switch (s) {
        Season.spring => 5.7,
        Season.summer => 5.1,
        Season.autumn => 5.7,
        Season.winter => 6.7,
      };

  static double sunset(Season s) => switch (s) {
        Season.spring => 18.7,
        Season.summer => 19.3,
        Season.autumn => 18.7,
        Season.winter => 17.4,
      };

  /// 0=夜深 1=正午，用于太阳高度和亮度。
  static double daylight(DateTime t, Season s) {
    final h = hourOf(t);
    final rise = sunrise(s), set = sunset(s);
    if (h < rise || h > set) return 0;
    return sin(((h - rise) / (set - rise)) * pi).clamp(0.0, 1.0).toDouble();
  }
}
