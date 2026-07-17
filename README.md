<p align="center">
  <h1 align="center"> SuikaMultiPlayer Client</h1>
  <p align="center">
    多人在线同步听歌 · Flutter 桌面客户端
  </p>
  <p align="center">
    <a>
    <img src="./assets/images/app_icon.png" alt="logo" title="logo" width="200"/>
</a>
  </p>
</p>

---

## 📖 简介

SuikaMultiPlayer Client 是 SuikaMultiPlayer 的 Flutter 桌面客户端，提供用户登录注册、房间加入与管理、音乐搜索与播放、实时歌词显示等功能。

基于 **Flutter 3.x + Riverpod** 构建，采用 **双 WebSocket 架构**（全局连接 + 房间连接），实现与服务器的高效实时通信。播放进度跟随服务器权威时钟，确保房间内所有成员同步聆听。

### 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x (Dart) |
| 平台 | Windows 桌面 |
| 状态管理 | flutter_riverpod |
| HTTP 客户端 | Dio |
| WebSocket | web_socket_channel |
| 音频播放 | media_kit |
| 路由 | go_router |
| 窗口管理 | window_manager（无边框窗口） |
| 持久化 | shared_preferences |
| 主题 | Material 3 深色主题 |
| 字体 | MiSans |

### TODO List

- [ ] 投票切歌
- [ ] 随机播放
- [ ] 播放自定义链接
- [ ] 网易云歌单界面
- [ ] 历史记录

---

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.11+
- Windows 10/11
- 已启动的 [SuikaMultiPlayer Server](https://github.com/LeavinSuika/SuikaMultiPlayer-Server)（默认 `127.0.0.1:8001`）

### 安装与运行

```bash
# 1. 克隆项目
git clone <repo-url>
cd SuikaMultiPlayer-Client-flutter

# 2. 安装依赖
flutter pub get

# 3. 运行（Windows 桌面）
flutter run -d windows
```

首次启动进入启动页，自动尝试登录（若本地存有凭证），否则跳转至登录/注册页。可在设置页面修改服务器地址。

---

## 📁 项目结构

```text
SuikaMultiPlayer-Client-flutter/
├── pubspec.yaml                  # Dart 依赖配置
├── assets/
│   ├── fonts/
│   │   └── MiSans-Regular.otf    # 自定义字体
│   └── images/                   # 图片资源
└── lib/
    ├── main.dart                 # 应用入口（窗口管理、MaterialApp）
    ├── config/
    │   ├── api_config.dart       # 服务器地址配置（支持 HTTP/HTTPS 切换）
    │   ├── constants.dart        # UI 常量
    │   └── theme.dart            # Material 3 深色主题
    ├── models/
    │   ├── user.dart             # 用户模型
    │   ├── room.dart             # 房间 + 成员模型
    │   ├── track.dart            # 歌曲模型
    │   ├── lyrics.dart           # 歌词模型（LRC/YRC 解析）
    │   └── playback_state.dart   # 播放状态模型
    ├── services/
    │   ├── api_service.dart      # HTTP REST 客户端
    │   ├── websocket_service.dart # 双 WebSocket 服务（全局 + 房间）
    │   ├── audio_player_service.dart # 音频播放器封装
    │   └── netease_service.dart  # 网易云音乐搜索 / 详情 API
    ├── providers/
    │   ├── auth_provider.dart    # 认证状态
    │   ├── websocket_provider.dart # WebSocket 连接 + 播放同步通知
    │   ├── music_provider.dart   # 搜索、歌曲缓存、歌词、播放器状态机
    │   ├── room_provider.dart    # 房间状态（加入/退出/歌单/在线用户）
    │   ├── sidebar_provider.dart # 侧边栏标签切换
    │   ├── server_config_provider.dart # 服务器配置
    │   └── user_cache_provider.dart # 用户信息缓存
    ├── screens/
    │   ├── splash_screen.dart    # 启动 / 自动登录页
    │   ├── login_screen.dart     # 登录/注册页（含服务器配置）
    │   ├── main_shell.dart       # 主界面：布局装配、播放同步核心逻辑
    │   ├── profile_screen.dart   # 个人资料页
    │   └── settings_screen.dart  # 服务器配置 / 关于页
    ├── layout/
    │   ├── toolbar.dart          # 自定义标题栏（可拖动）
    │   ├── icon_sidebar.dart     # 左侧图标导航栏
    │   ├── content_area.dart     # 内容区域路由器
    │   ├── user_panel.dart       # 右侧在线用户面板
    │   └── mini_player.dart      # 底部迷你播放器
    ├── widgets/
    │   ├── player/               # 歌词显示、播放控制
    │   ├── search/               # 歌曲搜索、添加到歌单
    │   └── room/                 # 房间列表、创建/加入对话框
    └── utils/
        ├── http_client.dart      # Dio 客户端工厂
        └── storage.dart          # SharedPreferences 封装
```

---

## 🖥️ 界面概览

| 区域 | 说明 |
|------|------|
| 自定义标题栏 | 可拖动、显示用户信息，支持最小化/最大化/关闭 |
| 左侧导航栏 | 图标式导航（房间、搜索、个人） |
| 中央内容区 | 根据导航切换显示内容 |
| 右侧用户面板 | 当前房间在线/离线成员，区分角色 |
| 底部迷你播放器 | 当前播放歌曲、播放/暂停、进度条 |

---

## 🏗️ 架构要点

### 双 WebSocket 连接

| 连接 | 端点 | Ping 间隔 | 功能 |
|------|------|-----------|------|
| 全局 WS | `/ws?user_uuid=...` | 30s | 心跳保活、在线状态维护 |
| 房间 WS | `/ws/room/{room_id}?user_uuid=...` | 15s | 播放同步、歌单管理、房间事件 |

房间 WS 断开后自动重连（前 3 次间隔 1s，之后间隔 5s，最多 10 次）。

### 播放同步策略

客户端使用 **服务器权威时钟** 模型：

1. **切歌同步** —— 当服务器 `track_id` 与本地不同时，加载新歌曲并 seek 到服务器位置
2. **同曲目同步** —— 同步 play/pause 状态，位置偏差 > 3s 时校正
3. **自动切歌** —— 本地播放器 idle 后自动移除当前歌曲、播放下一首、通知服务器
4. **本地位置推进** —— 使用音频播放器真实位置，不依赖服务器的 `track_pos_align`

### 状态管理（Riverpod）

```text
authProvider          → 认证状态（登录/注册/自动登录）
globalWsProvider      → 全局 WebSocket 连接
websocketProvider     → 房间 WebSocket 连接 + PlaybackNotifier
roomProvider          → 房间信息、歌单、在线/离线用户
playerProvider        → 音频播放器状态（当前歌曲、播放/暂停、进度）
trackCacheProvider    → 歌曲信息缓存
userCacheProvider     → 用户信息缓存
sidebarTabProvider    → 侧边栏当前选中标签
serverConfigProvider  → 服务器地址配置
```

### 状态流转

```text
SplashScreen ──自动登录──▶ MainShell
      │                        │
      └──无凭证──▶ LoginScreen │
                      │       │
                      └──登录──┘

MainShell 初始化：
  1. 连接全局 WebSocket (/ws)
  2. 加载已加入的房间列表
  3. 监听房间 WS 消息流
```

---

## 🔗 相关链接

- [SuikaMultiPlayer Server](https://github.com/LeavinSuika/SuikaMultiPlayer-Server) — 后端服务

---

## 📄 许可证

本项目基于 MIT 许可证开源，详见 [LICENSE](../SuikaMultiPlayer-Server/LICENSE)。
