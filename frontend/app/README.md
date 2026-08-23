# GoWind Kanban 前端应用

本项目是 GoWind Kanban 的前端部分，面向看板（Kanban）协作场景，提供跨平台的原生客户端体验。

## 📱 版本介绍

### Flutter 版本 (`/flutter_app`)
基于 Flutter 框架构建的跨平台原生应用，是当前唯一实现并维护的版本。
- **技术栈**: Flutter + Dart
- **架构**: BLoC 状态管理 + go_router 路由 + 特性模块化 (Feature-First)
- **核心依赖**: dio (网络)、sqflite (本地存储)、flutter_bloc (状态管理)、go_router (路由)、retrofit (API 生成)、cached_network_image (图片缓存)
- **特点**:
  - 真正的跨平台原生体验 (Android / iOS / Web / macOS / Windows / Linux)
  - Feature-First 模块化架构
  - BLoC/Cubit 状态管理模式
  - 支持国际化 (中/英)、主题切换 (亮色/暗色)
  - OpenAPI 代码自动生成 (swagger_parser + retrofit)
  - 响应式布局，适配移动端与桌面端
- **页面模块**: 看板列表、看板详情（桌面端/移动端）、列与卡片管理、标签管理、关于、法律信息、设置
- **适用场景**: 原生移动应用、跨平台桌面应用

> 早期的 React / Taro / Vue 版本为历史遗留脚手架，已不再维护，可在各对应目录中查阅残留结构。

## 🚀 快速开始

### Flutter 版本
```bash
cd flutter_app
flutter pub get
flutter run  # 或 flutter run -d chrome / flutter run -d windows
```

## 📁 目录结构

```
frontend/app/
├── flutter_app/    # Flutter 版本 - 跨平台原生 Kanban 应用
└── README.md       # 项目说明文档
```

## 🛠️ 技术特性

- **国际化支持**: 中文/英文多语言
- **状态管理**: BLoC/Cubit 模式
- **API 集成**: 基于 OpenAPI 生成的类型化 RESTful 客户端
- **响应式设计**: 移动端 / 桌面端布局自适应
- **类型安全**: Dart 强类型
- **主题支持**: 亮色/暗色主题切换

## 📝 开发规范

- 遵循 Flutter / Dart 的最佳实践
- 统一的代码风格和质量标准
- 完善的注释和文档
- 模块化和组件化开发

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来改进项目！
