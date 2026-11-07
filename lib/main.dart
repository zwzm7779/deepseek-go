import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/grow_page.dart';

void main() {
  runApp(const DaiYiHuiApp());
}

const Color kBg = Color(0xFFFBFAF8);
const Color kInk = Color(0xFF3B3742);
const Color kInk2 = Color(0xFF8A8490);

class DaiYiHuiApp extends StatelessWidget {
  const DaiYiHuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '待一会',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kInk,
          brightness: Brightness.light,
          surface: kBg,
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// 专注计时：倒计时 / 正向计时，今日累计分钟数落本地存储。
class FocusStore extends ChangeNotifier {
  static const _keyMinutes = 'daiyihui.minutes';
  static const _keyDay = 'daiyihui.day';

  bool countUp = false;
  bool running = false;
  bool paused = false;
  int totalSeconds = 25 * 60;
  int remaining = 25 * 60;
  int elapsed = 0;
  int todayMinutes = 0;

  Timer? _tick;
  DateTime? _endAt;
  DateTime? _startAt;

  String get dayKey {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  static String fmt(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  String get display => countUp ? fmt(elapsed) : fmt(remaining);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    if (sp.getString(_keyDay) == dayKey) {
      todayMinutes = sp.getInt(_keyMinutes) ?? 0;
    } else {
      todayMinutes = 0;
      await sp.setString(_keyDay, dayKey);
      await sp.setInt(_keyMinutes, 0);
    }
    notifyListeners();
  }

  Future<void> _saveMinutes() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyDay, dayKey);
    await sp.setInt(_keyMinutes, todayMinutes);
  }

  void toggleMode() {
    if (running) return;
    countUp = !countUp;
    remaining = totalSeconds;
    elapsed = 0;
    notifyListeners();
  }

  void start() {
    if (running) return;
    running = true;
    paused = false;
    final now = DateTime.now();
    _startAt = now;
    _endAt = now.add(Duration(seconds: remaining));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    paused = true;
    running = false;
    _tick?.cancel();
    notifyListeners();
  }

  void resume() {
    if (running || !paused) return;
    paused = false;
    running = true;
    _endAt = DateTime.now().add(Duration(seconds: remaining));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
    notifyListeners();
  }

  void stop() {
    running = false;
    paused = false;
    _tick?.cancel();
    remaining = totalSeconds;
    elapsed = 0;
    notifyListeners();
  }

  void _onTick() {
    final now = DateTime.now();
    if (countUp) {
      elapsed = now.difference(_startAt!).inSeconds;
      notifyListeners();
      return;
    }
    final left = _endAt!.difference(now).inSeconds;
    remaining = left < 0 ? 0 : left;
    if (left <= 0) {
      _finish();
    } else {
      notifyListeners();
    }
  }

  void _finish() {
    _tick?.cancel();
    running = false;
    paused = false;
    todayMinutes += (totalSeconds / 60).round();
    _saveMinutes();
    remaining = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FocusStore store = FocusStore();

  @override
  void initState() {
    super.initState();
    store.load();
    store.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = store.running || store.paused;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(
              store.display,
              style: const TextStyle(
                fontSize: 76,
                fontWeight: FontWeight.w200,
                letterSpacing: 2,
                color: kInk,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modeChip('倒计时', !store.countUp, store.toggleMode),
                const SizedBox(width: 6),
                const Text('·', style: TextStyle(color: Color(0xFFDCD6DE))),
                const SizedBox(width: 6),
                _modeChip('正向计时', store.countUp, store.toggleMode),
              ],
            ),
            const Spacer(flex: 2),
            if (!running)
              _primaryButton('待一会', store.start)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _primaryButton(store.paused ? '继续' : '暂停',
                      store.paused ? store.resume : store.pause),
                  const SizedBox(width: 12),
                  _softButton('结束', store.stop),
                ],
              ),
            const SizedBox(height: 10),
            _petEntry(),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Text(
                '今日 ${store.todayMinutes} 分钟',
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.6,
                  color: Color(0xFFA49EA8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _petEntry() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GrowPage()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EDE7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '🐾 宠物养成',
          style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: kInk2),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.8,
            color: on ? const Color(0xFF4F4B55) : const Color(0xFFB9B3BD),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: 176,
      height: 56,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kInk,
          foregroundColor: const Color(0xFFFAF7F3),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, letterSpacing: 3.8)),
      ),
    );
  }

  Widget _softButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kInk2,
          side: const BorderSide(color: Color(0xFFEAE3D9)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
