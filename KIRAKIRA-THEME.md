# キラキラ · 小王子星光

基于 Kazumi 2.3.9 的界面美化版本。主题来自用户提供的小王子插画，使用浅纸白、嫩绿、星星黄和淡紫灰，浅色模式使用浅底插画，深色模式自动使用星空插画与深蓝、暖金配色；跟随系统时也会同步切换。

## 改动范围

- 首页加入本地插画横幅；番剧封面、目录数据与原有交互保持原样。
- 插画横幅采用独立圆角卡片，配有细边框、窄幅内框、轻阴影与上下留白；明暗模式分别使用白色与深蓝卡片底面。
- 横幅文字与插画使用同一张底色，插画边缘柔和融入背景，避免左右色块割裂；两种模式同时适配。
- 横幅品牌字使用 Great Vibes 花体小写 `kirakira`，深色保留金黄色、浅色保留绿色；软件显示名称仍为“キラキラ”。字体随包附带，许可见 `licenses/great_vibes/OFL.txt`，来源为 Google Fonts 的 Great Vibes。
- 两处英文小字也使用 Great Vibes 花体，副标题 24px、底部说明 20px，保留原有文字颜色。
- 页面侧栏移除应用图标及其名称，保留搜索与导航；系统应用图标保持原样。
- 推荐页面右上角增加太阳/月亮按钮，按实际显示的明暗主题切换，并复用原主题设置保存选择；在外观设置中仍可选择跟随系统。
- 播放器选集面板为每个条目增加独立的小号集数标签，原标题保持原样显示在下一行，不将集数拼接进标题；离线缓存按原缓存集数显示，不改变选集回调与播放逻辑。
- 统一导航、卡片、按钮、输入框、弹窗、底部面板及文字层级。
- 默认配色为“小王子星光”。原有自选颜色、动态配色、字体和 OLED 选项继续保留。
- 应用显示名称、托盘、桌面快捷方式和各平台打包名称改为 キラキラ。
- 应用图标使用用户提供的“小王子-圆角图标.png”，覆盖 Windows、Android、iOS、macOS、Linux、网页、托盘与 iOS 启动画面。原图保存在 `assets/images/logo/kirakira-original.png`，未改构图。
- Dart 包名和平台通信通道保持原样；安卓定制包使用 `com.predidit.kazumi.kirakira` 独立安装，可与原版共存，数据相互独立。
- 2026-10-22 搜索修复：定制构建没有上游镜像的 `KAZUMI_APPID` / `KAZUMI_KEY`，默认镜像搜索返回 401。缺少镜像凭据时，关键词搜索使用 Bangumi 官方公开 API；其他镜像请求和用户主动选择的直连/ECH 保持原路线。搜索网络失败显示重试按钮，正常空结果仍显示“没有找到番剧”。此功能修复独立于弹幕审核。
- 保留 Kazumi 的开源来源与 GPL-3.0 许可。关于页面保留项目来源，并注明主题图片由用户提供。

## 打包

弹幕 API 使用官方 AppId / AppSecret 签名。需要先在 https://dev.dandanplay.com/ 申请审核，将凭据填入源码目录之外的 `%LOCALAPPDATA%\kirakira-build\dandan-credentials.json`；字段名见 `tools/dandan-credentials.example.json`。打包脚本会先检查配置与官方 API，再通过 `--dart-define-from-file` 注入凭据；不输出密钥。可用 `-DartDefineFile` 指定其他本地配置路径。尚未获得凭据时，原有安装包的弹幕认证问题仍然存在。

沿用原项目 Flutter 3.47.7 环境；安装对应平台工具链后，在项目目录运行：

```powershell
# Windows 便携 ZIP，包含 kirakira.exe
powershell -File .\tools\build-kirakira.ps1 -Platform windows

# Windows 安装程序 EXE，包含应用本地 C++ 运行库
powershell -File .\tools\build-kirakira.ps1 -Platform windows -Installer

# 同时生成 MSIX；本地包沿用原项目的未签名设置
powershell -File .\tools\build-kirakira.ps1 -Platform windows -Msix

# Android 分架构 APK，应用列表中的名称为 キラキラ
powershell -File .\tools\build-kirakira.ps1 -Platform android
```

输出目录：`dist`。示例：`キラキラ_windows_2.3.9.zip`、`キラキラ_android_2.3.9_arm64-v8a.apk`。

EXE 安装包需要 Inno Setup 6。Windows 原生依赖 `ech_http 0.2.2` 的证书文本超过 MSVC 单个字符串的长度限制，需安装 LLVM；打包脚本会检测 `Program Files\LLVM\bin\clang-cl.exe`，在首次编译遇到限制后，通过 `prepare-windows-native.ps1` 为该原生依赖的 CMake 缓存选择 clang-cl 并重试。Windows 主程序仍使用 MSVC，证书与业务源码不作修改。生成名称为 `キラキラ-2.3.9-windows-x64-setup.exe`，默认安装至当前用户的 `AppData\Local\Programs\kirakira`，支持开始菜单、可选桌面快捷方式和卸载入口。

如需重新生成图标：

```powershell
dart run flutter_launcher_icons
dart run tools/regenerate_icon_extras.dart
```

Windows ICO 含 16、20、24、32、40、48、64、128、256 像素九种尺寸。Android 自适应图标及 iOS 不透明底色取深蓝，保留原图的圆角与透明边缘效果。

macOS、iOS 和 Linux 的应用名称与现有 GitHub 工作流产物名称也已更新；这些平台未在本机编译。

## 主题图片

- 主题插画由用户提供：`womany_prince_4_1436805762-19680-7031.jpg`。
- 浅色原图作为 `assets/images/little_prince_theme.jpg` 打包；深色原图作为 `assets/images/little_prince_night.jpg` 打包，两张图片均未修改内容。
- 首页保留小王子人物主体与星星，移动端显示完整插画；运行时无需访问图片网站。
- 软件图标继续使用此前提供的“小王子-圆角图标.png”。

## 验证说明

完整源码静态分析与改动文件检查结果见交付目录中的验证报告。独立 Flutter 预览使用生产主题、横幅和设置组件，目录封面仅为预览样本；预览不是完整播放器运行测试。

Windows x64 正式版与 EXE 安装包已构建，已在本机完成安装及启动检查。Windows 安装包未签名，卸载入口已注册，未执行卸载检查。安卓 ARM64 正式 APK 已使用本地独立发行密钥签名，最低 Android 7.0；已在 Android 16 模拟器中安装同一个 ARM64 包，检查启动、明暗切换、重启后主题保存和搜索结果。未进行实体手机验证，也未完成播放、弹幕、投屏或下载的完整回归；弹幕审核状态独立于界面打包。

安卓重建时设置 `JAVA_HOME`、`ANDROID_HOME` 并使用 Flutter 3.47.7，运行 `tools/package-android.ps1`。脚本从源码目录外的 `%LOCALAPPDATA%\kirakira-build\android-signing.json` 读取本地签名配置，私钥及密码不随源码分发。该签名密钥用于后续版本覆盖升级，应保留本机原文件。脚本仅检查弹幕配置完整性并注入凭据，官方审核是否生效仍需另行联网核实。
