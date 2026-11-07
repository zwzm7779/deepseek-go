# 待一会 · Flutter 版

从单文件 HTML 迁移过来的原生版本。当前进度：主页计时 + 宠物养成页（像素场景 + 四季天气）。

## 目录

```
lib/main.dart                 入口、主页计时、宠物入口
lib/core/weather.dart         四季 / 天气 / 昼夜（纯逻辑，可单测、可迁移）
lib/ui/grow_page.dart         宠物养成页：状态机、粒子、伞的开合
lib/painters/grow_painter.dart 像素场景绘制（天空、日月、云、草地、落叶、猫、伞、雨雪）
.github/workflows/build.yml   推代码自动构建 APK
pubspec.yaml                  依赖（shared_preferences）
```

`android/`、`ios/` 等平台目录由 CI 里的 `flutter create` 自动生成，不提交到仓库。

## 四季天气规则（与 HTML 版一致）

- 季节：固定基准 2026-01-01，每 3 天换一季，春→夏→秋→冬循环
- 天气：晴 / 多云 / 阴 / 大风 / 小雨 / 下雪，每季独立概率，持续 2.5～5.5 小时
- 持久化：`shared_preferences` 键 `daiyihui.weather.v2`，存类型与起止时间戳
- 昼夜：按小时插值天空色，日出日落随季节前后移动，太阳贴近地平线时变暗
- 雨天：不散步、坐/趴/睡，透明伞缓开缓收

## 测试

```bash
flutter test
```

- `test/weather_test.dart`：季节轮换（含负时间）、天气权重与抽样分布、持久化（首次/重开沿用/过期换新/换季）、昼夜亮度
- `test/widget_test.dart`：主页渲染、进入宠物页渲染

CI 里构建前会自动跑 `flutter test`。

## 本机构建（有 Flutter 的电脑）

```bash
flutter pub get
flutter create --platforms=android --org com.daiyihui --project-name daiyihui .
flutter run
```

## 云端构建（手机就能拿到 APK）

推到 `main` 分支后，GitHub Actions 自动构建：

1. 打开仓库的 **Actions** 标签
2. 点最新一次 `build-apk`
3. 在 **Artifacts** 里下载 `daiyihui-debug-apk`
4. 解压出 `app-debug.apk`，装到手机上

## 待办

- [ ] 像素猫精细度对齐原版（姿态、尾巴、表情）
- [ ] 便签抽屉
- [ ] 倒数日
- [ ] 计划与统计
- [ ] 正式签名（上架前）
