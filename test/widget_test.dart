import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daiyihui/main.dart';
import 'package:daiyihui/ui/grow_page.dart';

void main() {
  testWidgets('主页显示倒计时与宠物入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DaiYiHuiApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('待一会'), findsOneWidget);
    expect(find.text('🐾 宠物养成'), findsOneWidget);
  });

  testWidgets('进入宠物页能正常渲染几帧', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DaiYiHuiApp());
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('🐾 宠物养成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GrowPage), findsOneWidget);
    expect(find.text('宠物养成'), findsWidgets);
  });
}
