import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daiyihui/core/weather.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('季节轮换', () {
    test('每 3 天推进一季，四序循环', () {
      final e = WeatherEngine();
      final a = kSeasonAnchor;
      expect(e.seasonAt(a), 0);
      expect(e.seasonAt(a + kSeasonMs - 1), 0);
      expect(e.seasonAt(a + kSeasonMs), 1);
      expect(e.seasonAt(a + kSeasonMs * 3), 3);
      expect(e.seasonAt(a + kSeasonMs * 4), 0);
    });

    test('基准点之前也能得到正确季节（负数取模）', () {
      final e = WeatherEngine();
      expect(e.seasonAt(kSeasonAnchor - 1), 3);
      expect(e.seasonAt(kSeasonAnchor - kSeasonMs), 3);
      expect(e.seasonAt(kSeasonAnchor - kSeasonMs * 4), 0);
    });

    test('一天之内季节不变（凌晨与深夜同季）', () {
      final e = WeatherEngine();
      final day = DateTime(2026, 3, 2, 0, 30).millisecondsSinceEpoch;
      final night = DateTime(2026, 3, 2, 23, 30).millisecondsSinceEpoch;
      expect(e.seasonAt(day), e.seasonAt(night));
    });
  });

  group('天气权重', () {
    final e = WeatherEngine();

    test('雪只在冬天出现', () {
      expect(e.weightOf(Season.winter, WeatherType.snow), greaterThan(0));
      for (final s in [Season.spring, Season.summer, Season.autumn]) {
        expect(e.weightOf(s, WeatherType.snow), 0);
      }
    });

    test('夏天雨比冬天多', () {
      expect(
        e.weightOf(Season.summer, WeatherType.rain),
        greaterThan(e.weightOf(Season.winter, WeatherType.rain)),
      );
    });

    test('每季至少有两种以上天气可选', () {
      for (final s in Season.values) {
        final kinds =
            WeatherType.values.where((w) => e.weightOf(s, w) > 0).length;
        expect(kinds, greaterThanOrEqualTo(4), reason: '$s 天气种类偏少');
      }
    });

    test('冬天抽样 2000 次，雪的比例接近权重', () {
      var snow = 0;
      for (var i = 0; i < 2000; i++) {
        if (e.pickFor(Season.winter) == WeatherType.snow) snow++;
      }
      // 权重 22/100，允许 ±5% 波动
      expect(snow / 2000, closeTo(0.22, 0.05));
    });

    test('夏天不会抽到雪', () {
      for (var i = 0; i < 500; i++) {
        expect(e.pickFor(Season.summer), isNot(WeatherType.snow));
      }
    });
  });

  group('天气持久化', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('首次加载写入 2.5~5.5 小时的区间', () async {
      final e = WeatherEngine();
      await e.load();
      expect(e.loaded, true);
      final span = e.until - e.start;
      expect(span, greaterThanOrEqualTo(150 * 60000));
      expect(span, lessThanOrEqualTo(330 * 60000));
    });

    test('重新打开时沿用未过期的天气', () async {
      final a = WeatherEngine();
      await a.load();
      final b = WeatherEngine();
      await b.load();
      expect(b.type, a.type);
      expect(b.start, a.start);
      expect(b.until, a.until);
      expect(b.seasonIndex, a.seasonIndex);
    });

    test('过期的天气会换新并写回存储', () async {
      final e0 = WeatherEngine();
      final now = DateTime.now().millisecondsSinceEpoch;
      final si = e0.seasonAt(now);
      SharedPreferences.setMockInitialValues({
        'daiyihui.weather.v2': jsonEncode({
          'type': 'rain',
          'start': now - 7200000,
          'until': now - 1000,
          'season': si,
        }),
      });
      final e = WeatherEngine();
      await e.load();
      expect(e.until, greaterThan(now));
      expect(e.start, greaterThanOrEqualTo(now - 5000));
    });

    test('季节变了会换天气（不沿用上一季的雪）', () async {
      final e0 = WeatherEngine();
      final now = DateTime.now().millisecondsSinceEpoch;
      final prevSeason = (e0.seasonAt(now) + 3) % 4;
      SharedPreferences.setMockInitialValues({
        'daiyihui.weather.v2': jsonEncode({
          'type': 'snow',
          'start': now - 60000,
          'until': now + 3600000,
          'season': prevSeason,
        }),
      });
      final e = WeatherEngine();
      await e.load();
      expect(e.seasonIndex, e0.seasonAt(now));
      expect(e.until, greaterThan(now));
    });
  });

  group('昼夜', () {
    test('正午最亮、深夜为 0', () {
      final noon = DateTime(2026, 6, 1, 12);
      final night = DateTime(2026, 6, 1, 2);
      expect(WeatherEngine.daylight(noon, Season.summer), greaterThan(0.9));
      expect(WeatherEngine.daylight(night, Season.summer), 0);
    });

    test('日出日落时间随季节移动', () {
      expect(WeatherEngine.sunrise(Season.summer),
          lessThan(WeatherEngine.sunrise(Season.winter)));
      expect(WeatherEngine.sunset(Season.summer),
          greaterThan(WeatherEngine.sunset(Season.winter)));
    });
  });
}
