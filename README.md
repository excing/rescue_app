# rescue_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

请优化当前flutter项目, 包括但不限于轨迹的数据结构, 后台(熄屏锁屏)记录等. 其中保存用户轨迹数据的文档结构应优化以达到保存更多point的目的, 经纬度精确到 0.1 米即可. 文档名使用 `user-${userId}-${index}`.


New:

你是一个专业资深的 Flutter 开发工程师, 喜欢采用当下流行的设计理念和框架来制定开发计划并开发产品, 你喜欢严格遵守软件设计六大原则, 特别是单一职责原则, 注释完备, 具有很强的可扩展性和可维护性, 并能很好的适应未来的变化, 同时会保持代码优雅, 易读, 对新手友好, 你不会写很长的代码, 如果功能复杂, 你会拆分成多个简洁的函数来完成, 符合低耦合高内聚的开发理念, 你会对代码做详尽的测试以保证程序的质量.

现在你正在开发一个新的产品, 目前已经创建好了基本的配置文件, 请根据以下需求来完成开发.
这是一个用于共享轨迹和位置的救援APP. 用于共享参与同一个活动(救援)的人员轨迹和位置, 以及做在当前位置打点做标记(确认已搜索). 做到准实时更新(山林地貌复杂, 信号不好). 

数据结构:

救援数据结构:
id: 随机4位数字
description: 描述
location: 救援地点经纬度
altitude: 救援地点海拔
createdAt: 创建时间
isActive: 是否激活, 应始终为 true

```json
{
  "id": "3669",
  "description": "测试3669",
  "location": {
    "latitude": 25.59462,
    "longitude": 100.2457983
  },
  "altitude": 1970.2,
  "createdAt": "2025-08-13T03:44:19.507981",
  "createdBy": "user_1755027859507",
  "isActive": true
}
```

用户轨迹数据结构:
latitude: int32, 精确到 0.1 米
longitude: int32, 精确到 0.1 米
altitude: int32, 厘米
accuracy: int32, 厘米
timestamp: int64, 毫秒级时间戳
marked: bool, 该地点是否已搜索/已标记

```json
{
  "user_id": "uuid",
  "points": [
    "latitude,longitude,altitude,accuracy,marked,timestamp",
  ]
}
```
停止记录轨迹时, 则新增一条经纬度全是0的记录, 以表示停止.

存储策略: 每个救援一个集合(firestore collection), 每个人员的轨迹记录为一个文档(firestore document), 每个文档最大存储空间为 1MB, 存储不够时, 则新建文档, 文档名使用 timestamp 占位符, timestamp 为当前时间, 即 `user-${userId}-${timestamp}`. Firestore 服务通过调用后端 API 来完成(API: https://tools.blendiv.com), 后端 API 的源码可见 `/server` 目录.
同步策略: 加入一个救援时, 下载该救援下所有用户的轨迹记录并显示, 每隔 1 分钟左右同步一次, 可手动同步(需间隔5秒), 同步时, 下载该救援下所有用户的轨迹记录, 并上传当前用户在该救援下的所有轨迹记录.
数据使用策略: 本地优先, 优先使用本地数据, 同步数据需存储在本地.
后台(熄屏/锁屏): 设备在熄屏和锁屏状态下可正常的持续记录轨迹, 应使用flutter上原生的后台服务, android客户端应需要启动前台服务（通知栏常驻）来保证持续定位.

目前产品原型有三个页面, 原则是现代化, 年轻化, 易操作, 学习成本小, 核心UI是:

首页: 原型自由发挥, 核心UI是输入救援号.
创建救援页: 原型自由发挥, 核心UI是随机4位数字的救援号(可复制), 标题, 描述和救援地点经纬度和高度信息, 以及创建救援按钮.
救援页: 原型自由发挥, 背景是全屏的高等线地图, 地图上显示救援地点, 当前设备的位置信息(经纬度, 调试等), 以及所有参与者的位置和轨迹, 以及缩放地图按钮. 每个参与者使用不同的颜色. 底部有控制按钮, 包括开始/停止记录, 同步等.

样式:

首页背景:

```dart
gradient: LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF667eea),
    Color(0xFF764ba2),
  ],
),
```

创建救援页背景:

```dart
gradient: LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Colors.orange[600]!,
    Colors.orange[50]!,
  ],
),
```