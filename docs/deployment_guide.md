# 救援APP部署指南

## 概述

本文档提供了救援APP的完整部署指南，包括开发环境配置、构建流程、发布准备和生产环境部署。

## 1. 开发环境配置

### 1.1 Flutter环境

**要求**:
- Flutter SDK 3.19.0 或更高版本
- Dart SDK 3.3.0 或更高版本
- Android Studio / VS Code
- Xcode (iOS开发)

**安装验证**:
```bash
flutter doctor -v
```

### 1.2 依赖安装

```bash
# 获取项目依赖
flutter pub get

# 生成代码（如果有）
flutter packages pub run build_runner build
```

### 1.3 Firebase配置

**Android配置**:
1. 下载 `google-services.json` 文件
2. 放置到 `android/app/` 目录
3. 确保 `android/app/build.gradle` 包含Firebase插件

**iOS配置**:
1. 下载 `GoogleService-Info.plist` 文件
2. 添加到 `ios/Runner/` 目录
3. 在Xcode中添加到项目

## 2. 权限配置

### 2.1 Android权限

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<!-- 位置权限 -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- 网络权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- 后台服务权限 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- 通知权限 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### 2.2 iOS权限

在 `ios/Runner/Info.plist` 中添加：

```xml
<!-- 位置权限 -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>救援APP需要位置权限来记录和共享您的位置轨迹</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>救援APP需要后台位置权限来在应用后台时继续记录轨迹</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>救援APP需要后台位置权限来确保轨迹记录的完整性</string>

<!-- 后台模式 -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-fetch</string>
    <string>background-processing</string>
</array>
```

## 3. 构建配置

### 3.1 Android构建配置

**签名配置** (`android/app/build.gradle`):

```gradle
android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

**ProGuard规则** (`android/app/proguard-rules.pro`):

```proguard
# Flutter相关
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase相关
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Geolocator相关
-keep class com.baseflow.geolocator.** { *; }
```

### 3.2 iOS构建配置

**Xcode项目配置**:
1. 设置Bundle Identifier
2. 配置Team和Provisioning Profile
3. 设置Deployment Target (iOS 12.0+)
4. 启用必要的Capabilities

## 4. 测试流程

### 4.1 单元测试

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/models/track_point_model_test.dart

# 生成测试覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### 4.2 集成测试

```bash
# 运行集成测试
flutter drive --target=test_driver/app.dart
```

### 4.3 真机测试

**Android测试**:
```bash
# 调试版本
flutter run --debug

# 发布版本测试
flutter run --release
```

**iOS测试**:
```bash
# 调试版本
flutter run --debug

# 发布版本测试
flutter run --release
```

## 5. 构建发布版本

### 5.1 Android APK/AAB

```bash
# 构建APK
flutter build apk --release

# 构建App Bundle (推荐)
flutter build appbundle --release

# 分析APK大小
flutter build apk --analyze-size
```

### 5.2 iOS IPA

```bash
# 构建iOS应用
flutter build ios --release

# 在Xcode中Archive并导出IPA
```

## 6. 发布准备

### 6.1 应用商店资源

**必需资源**:
- 应用图标 (各种尺寸)
- 启动画面
- 应用截图 (各种设备)
- 应用描述
- 隐私政策
- 使用条款

### 6.2 版本管理

**版本号规则**:
- 主版本.次版本.修订版本+构建号
- 例如: 1.0.0+1

**更新 `pubspec.yaml`**:
```yaml
version: 1.0.0+1
```

### 6.3 发布检查清单

- [ ] 所有测试通过
- [ ] 性能测试完成
- [ ] 权限配置正确
- [ ] Firebase配置验证
- [ ] 签名证书配置
- [ ] 应用图标和资源
- [ ] 隐私政策和条款
- [ ] 版本号更新

## 7. 应用商店发布

### 7.1 Google Play Store

**发布步骤**:
1. 创建Google Play Console账户
2. 创建新应用
3. 上传App Bundle
4. 填写应用信息
5. 设置定价和分发
6. 提交审核

**关键配置**:
- 目标API级别: 34 (Android 14)
- 应用签名: 使用Play App Signing
- 发布轨道: 内部测试 → 封闭测试 → 开放测试 → 生产

### 7.2 Apple App Store

**发布步骤**:
1. 注册Apple Developer账户
2. 在App Store Connect创建应用
3. 上传IPA文件
4. 填写应用信息
5. 提交审核

**关键配置**:
- iOS Deployment Target: 12.0
- 应用分类: 导航
- 年龄分级: 4+

## 8. 持续集成/持续部署 (CI/CD)

### 8.1 GitHub Actions配置

创建 `.github/workflows/build.yml`:

```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.19.0'
    - run: flutter pub get
    - run: flutter test
    - run: flutter build apk --debug

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.19.0'
    - run: flutter pub get
    - run: flutter build appbundle --release
```

### 8.2 自动化部署

**Fastlane配置** (可选):
- 自动化构建流程
- 自动上传到应用商店
- 自动化测试分发

## 9. 监控和维护

### 9.1 崩溃监控

**Firebase Crashlytics**:
- 实时崩溃报告
- 性能监控
- 用户行为分析

### 9.2 应用更新

**热更新策略**:
- 关键bug修复: 立即发布
- 功能更新: 定期发布
- 安全更新: 优先处理

### 9.3 用户反馈

**反馈渠道**:
- 应用商店评论
- 应用内反馈
- 客服支持

## 10. 安全考虑

### 10.1 数据安全

- 使用HTTPS传输
- 敏感数据加密存储
- 定期安全审计

### 10.2 权限最小化

- 只请求必要权限
- 及时释放权限
- 透明的权限说明

## 总结

通过遵循本部署指南，可以确保救援APP的稳定发布和持续维护。关键要点：

1. **完整的测试覆盖** - 确保应用质量
2. **正确的权限配置** - 保证功能正常
3. **安全的构建流程** - 保护应用安全
4. **持续的监控维护** - 确保用户体验

建议在正式发布前进行充分的内测和公测，收集用户反馈并持续优化。
