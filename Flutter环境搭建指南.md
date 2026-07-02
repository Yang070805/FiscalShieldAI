# FiscalShieldAI — Flutter 开发环境搭建指南

> **适用系统：Windows 11**  
> **目标：从零配置，到能创建并运行 Flutter 项目**  
> **预计耗时：30-60 分钟**

---

## 一、安装清单

| 工具 | 用途 | 必须 |
|------|------|------|
| Android Studio | Android SDK 管理 + IDE | ✅ |
| Flutter SDK | Flutter 开发框架 | ✅ |
| VS Code（可选） | 轻量编辑器 | ❌ |

---

## 二、安装 Android Studio

### 2.1 下载

由于国内网络访问 Google 官网较慢，使用**国内镜像**下载：

- **Google 中国镜像**：https://developer.android.google.cn/studio?hl=zh-cn
- **清华镜像**：https://mirrors.tuna.tsinghua.edu.cn/android/studio/

选择 **Windows (64 位)** 版本下载（约 1.5GB）。

### 2.2 安装

1. 双击运行安装程序
2. 安装路径建议放 **D 盘**（C 盘空间紧张的话）：`D:\AndroidStudio`
3. 安装时勾选：
   - ✅ Android Virtual Device（模拟器）
4. 安装完成后启动 Android Studio

### 2.3 首次启动配置

Android Studio 首次启动会进入 Setup Wizard：

1. 选择 **Standard** 安装类型
2. 选择你喜欢的 UI 主题（Dark / Light）
3. 等待它自动下载 SDK 组件（需要几分钟）

### 2.4 安装必要 SDK 组件

进入 Android Studio 后：

1. 菜单栏 → **Tools → SDK Manager**
2. 在 **SDK Platforms** 标签页：
   - ✅ 勾选 **Android 16.0 (API 36)** 或最新版本
3. 切换到 **SDK Tools** 标签页，确保勾选：
   - ✅ **Android SDK Build-Tools**
   - ✅ **Android SDK Command-line Tools (latest)**
   - ✅ **Android SDK Platform-Tools**
   - ✅ **NDK (Side by side)**（C++ 编译需要）
   - ✅ **Android Emulator**（模拟器）
4. 点击 **Apply** → 等待下载完成

> ⚠️ 如果下载很慢，在 SDK Manager 的 **Edit** → **HTTP Proxy** 里设置代理，
> 或者在 SDK Update Sites 里添加国内镜像：
> - 阿里云：`https://mirrors.aliyun.com/android/repository/`
> - 清华源：`https://mirrors.tuna.tsinghua.edu.cn/android/repository/`

### 2.5 确认 SDK 安装路径

默认安装路径为：
```
C:\Users\<你的用户名>\AppData\Local\Android\Sdk
```

记下这个路径，后面会用到。

---

## 三、安装 Flutter SDK

### 3.1 下载

Flutter 也有国内镜像，推荐使用：

**Flutter 国内镜像下载页**：https://flutter.cn/community/china

或者直接下载稳定版 zip（约 1.1GB）：

```
https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.44.4-stable.zip
```

> ⚠️ 不要用 `git clone` 下载！Git clone 下来的是 Linux 版，在 Windows 上跑不了。

### 3.2 解压

将 zip 解压到一个**没有中文和空格**的路径，例如：

```
D:\flutter
```

解压后的目录结构：
```
D:\flutter\
├── bin\          ← flutter.bat 在这里
├── cache\
├── packages\
└── ...
```

### 3.3 添加环境变量

1. 按 `Win + S`，搜索 **"环境变量"**
2. 点击 **"编辑系统环境变量"**
3. 点击 **"环境变量"** 按钮
4. 在 **用户变量** 中找到 `Path`，双击编辑
5. 点击 **新建**，添加两行：

```
D:\flutter\bin
C:\Users\<你的用户名>\AppData\Local\Android\Sdk\platform-tools
```

6. 一路点确定保存

### 3.4 验证安装

**关闭所有终端窗口**，重新打开 PowerShell 或 CMD，运行：

```powershell
flutter doctor
```

首次运行会下载 Dart SDK（约 2 分钟），然后输出诊断结果：

```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.44.4, ...)
[✓] Android toolchain - develop for Android devices
[✓] Connected device (1 available)
```

看到全部绿色 ✅ 就成功了！

> 如果有黄色 ⚠️ 或红色 ✗，根据提示修复即可。

---

## 四、安装 Android Studio Flutter 插件（推荐）

这个插件让 Android Studio 直接支持 Flutter 开发：

1. 打开 Android Studio
2. **File → Settings → Plugins**
3. 搜索 **Flutter**，点击 **Install**（会自动安装 Dart 插件）
4. **重启 Android Studio**
5. 重启后，**New Project** 里会出现 **Flutter** 选项

> 用了这个插件后，可以直接在 Android Studio 里创建、运行、调试 Flutter 项目。

---

## 五、创建第一个 Flutter 项目

### 方式一：Android Studio（推荐）

1. **File → New → New Flutter Project**
2. 选择 **Flutter**（左侧 Generators 列表最下方）
3. 填写：
   - **Flutter SDK path**：`D:\flutter`
   - **Project name**：`my_app`
   - **Project location**：选择项目存放目录
   - **Organization**：`com.example`（改成你自己的域名）
   - **Project type**：Application
   - **Android language**：Kotlin
   - **Platforms**：全勾
4. 点击 **Create**

### 方式二：命令行

```powershell
cd D:\
flutter create my_app
cd my_app
flutter run
```

---

## 六、运行项目

### 用模拟器

1. Android Studio → **Tools → Device Manager**
2. 点击 **Create Virtual Device**
3. 选择一个手机型号（如 Pixel 7）→ Next
4. 下载一个系统镜像（如 API 34）→ Next → Finish
5. 点击 ▶️ 启动模拟器
6. 在 Flutter 项目中点击 **Run**（绿色三角形）

### 用真机（推荐）

1. 手机开启 **开发者模式**（连续点击"版本号"7 次）
2. 开启 **USB 调试**
3. 用数据线连接电脑
4. 手机上弹出授权提示 → 点击 **允许**
5. 在 Android Studio 中选择你的设备 → 点击 **Run**

---

## 七、常见问题

### Q1: `flutter doctor` 报 "cmdline-tools component is missing"

**Android Studio → SDK Manager → SDK Tools** → 勾选 **Android SDK Command-line Tools** → Apply

### Q2: `flutter doctor` 报 "NDK not found"

**Android Studio → SDK Manager → SDK Tools** → 勾选 **NDK (Side by side)** → Apply

### Q3: Gradle 下载很慢 / 超时

在项目目录 `android/gradle/wrapper/gradle-wrapper.properties` 中，把：
```
distributionUrl=https\://services.gradle.org/distributions/gradle-x.x.x-all.zip
```
改为腾讯镜像：
```
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-x.x.x-all.zip
```

同时在 `android/build.gradle.kts` 和 `android/settings.gradle.kts` 的 `repositories` 中，在 `google()` 和 `mavenCentral()` **前面**加上：
```kotlin
maven { url = uri("https://maven.aliyun.com/repository/google") }
maven { url = uri("https://maven.aliyun.com/repository/central") }
maven { url = uri("https://maven.aliyun.com/repository/public") }
```

### Q4: Android Studio 下载 SDK 很慢

在 SDK Manager → Edit（扳手图标）→ HTTP Proxy → 设置代理，
或者在 SDK Update Sites 中添加国内镜像。

### Q5: `flutter doctor` 报 "Android sdk file not found: adb"

环境变量 Path 里需要包含：
```
C:\Users\<你的用户名>\AppData\Local\Android\Sdk\platform-tools
```
添加后重启终端。

---

## 八、有用的资源

| 资源 | 链接 |
|------|------|
| Flutter 官方文档 | https://docs.flutter.dev |
| Flutter 中文社区 | https://flutter.cn |
| Dart 语言教程 | https://dart.dev/language |
| Flutter Widget Catalog | https://docs.flutter.dev/ui/widgets |
| Material Design 3 | https://m3.material.io |
| Flutter Packages | https://pub.dev |

---

## 九、检查清单

配置完成后，确认以下命令都能正常运行：

```powershell
flutter --version        # 应显示 Flutter 3.44.4
flutter doctor           # 应全部绿色 ✅
dart --version           # 应显示 Dart 3.x.x
adb devices              # 应显示已连接设备（或空列表）
```

全部通过后，你就可以开始开发了！🚀

---

*最后更新：2026-07-01*
