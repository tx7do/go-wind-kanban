<div align="center">

<img src="docs/brand/vortex-tile.svg" width="120" alt="GoWind Kanban｜风行看板" />

# GoWind Kanban｜风行看板

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go)](https://go.dev/)
[![Vue](https://img.shields.io/badge/Vue-3.x-4FC08D?logo=vuedotjs)](https://vuejs.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)

[English](./README.en-US.md) | **中文** | [日本語](./README.ja-JP.md)

</div>

---

## 项目亮点

- **微服务 + 单体自由切换**：基于 go-kratos 微服务框架，admin / app / core 三服务通过 gRPC + Gateway 互联，同时支持单体架构模式开发与部署，灵活适配团队规模
- **企业级 RBAC**：支持多租户、多角色、多部门、菜单 / 按钮 / 数据级权限控制
- **全栈代码生成**：Protobuf → Go API / Dart 客户端，Ent Schema → ORM，一键脚手架
- **实时协作**：基于 SSE 与 WebSocket 的一次性 ticket 握手，看板列 / 卡片 / 标签的实时多端同步
- **跨平台原生客户端**：一套 Flutter 代码编译 iOS / Android / Web / macOS / Windows / Linux，移动端与桌面端自适应布局

---

## 技术栈

<table>
<tr><th>层级</th><th>技术</th></tr>
<tr><td><strong>后端框架</strong></td><td><code>Golang</code> · <code>go-kratos v2</code> · <code>Wire</code> · <code>Protobuf / Buf</code></td></tr>
<tr><td><strong>ORM</strong></td><td><code>Ent</code> · <code>PostgreSQL</code></td></tr>
<tr><td><strong>中间件</strong></td><td><code>Redis</code> · <code>Etcd</code>（服务发现） · <code>Jaeger</code>（链路追踪）</td></tr>
<tr><td><strong>认证授权</strong></td><td><code>JWT</code> · <code>RBAC</code></td></tr>
<tr><td><strong>实时通信</strong></td><td><code>SSE</code>（服务端推送） · <code>WebSocket</code>（一次性 ticket 握手） · <code>Asynq</code>（异步任务）</td></tr>
<tr><td><strong>Admin 前端</strong></td><td><code>Vue 3</code> · <code>TypeScript</code> · <code>Vite</code> · <code>Ant Design Vue</code> · <code>Vben Admin</code></td></tr>
<tr><td><strong>App 前端</strong></td><td><code>Flutter</code> · <code>Dart</code> · <code>BLoC / Cubit</code> · <code>go_router</code>（跨平台原生应用）</td></tr>
<tr><td><strong>部署运维</strong></td><td><code>Docker</code> · <code>Docker Compose</code> · <code>PM2</code> · <code>Swagger UI</code></td></tr>
</table>

---

## 快速开始

### 环境要求

| 工具 | 版本 |
|------|------|
| Go | 1.26+ |
| Node.js | >= 20.10.0 |
| pnpm | >= 10.0.0 |
| Flutter | 3.x（App 客户端开发） |
| Docker | 20.0+ |

### 环境脚本选型

- Linux / macOS 开发环境：`backend/scripts/env/install_unix_dev.sh`
- Linux / macOS 生产环境：`backend/scripts/env/install_unix_prod.sh`
- Windows 开发环境：`backend/scripts/env/install_windows_dev.ps1`

### Docker 两种部署模式

- **full_deploy 完整模式**：同步启动中间件 + 后端应用，适用于一键演示、生产部署
- **libs_only 依赖模式（推荐开发）**：仅启动中间件，应用本地 IDE 运行调试

### 后端启动

**Linux / macOS：**

```shell
# 赋予脚本执行权限
chmod +x backend/scripts/**/*.sh

# 开发环境（推荐）
./backend/scripts/env/install_unix_dev.sh
./backend/scripts/docker/libs_only.sh

# 进入对应服务目录运行（admin / app / core）
cd backend/app/admin/service
make run

# 生产环境
./backend/scripts/env/install_unix_prod.sh
./backend/scripts/docker/full_deploy.sh

# PM2 进程托管（生产进阶）
./backend/scripts/deploy/pm2_service.sh
```

**Windows（PowerShell 管理员）：**

```powershell
# 放行脚本策略（首次仅需执行一次）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 初始化环境
.\backend\scripts\env\install_windows_dev.ps1

# 本地开发
.\backend\scripts\docker\libs_only.ps1
cd backend\app\admin\service
make run

# 一键完整部署
.\backend\scripts\docker\full_deploy.ps1
```

### 前端启动

前端分管理后台与跨平台客户端两部分，统一存放于 `frontend/` 目录。

| 前端版本 | 目录 | 启动命令 | 端口 |
|---------|------|---------|------|
| Admin（Vue3 Vben） | `frontend/admin` | `pnpm dev:antd` | 5666 |
| App（Flutter） | `frontend/app/flutter_app` | `flutter run` | — |

```shell
# Admin 前端
cd frontend/admin
pnpm install
pnpm dev:antd

# Flutter App
cd frontend/app/flutter_app
flutter pub get
flutter run   # 或 flutter run -d chrome / windows
```

---

## 功能列表

### 组织与权限

| 功能 | 说明 |
|------|-----|
| 用户管理 | 管理和查询用户，支持按部门联动、禁用 / 启用、重置密码、多角色与多部门配置 |
| 租户管理 | 管理租户，新增租户后自动初始化租户部门与默认管理员 |
| 角色管理 | 管理角色与角色分组，设置菜单与数据权限，批量添加和移除成员 |
| 权限管理 | 管理权限分组、菜单、权限点，树形列表展示 |
| 组织管理 | 管理组织架构，树形列表展示 |
| 职位管理 | 用户职务管理，职务可作为用户的一个标签 |
| 菜单管理 | 配置系统菜单、操作权限与按钮权限标识，包括目录、菜单、按钮 |
| 接口管理 | 管理接口，用于新增权限点时选择接口，树形列表展示 |

### 系统功能

| 功能 | 说明 |
|------|-----|
| 看板协作 | 看板、列与卡片的创建 / 编辑 / 拖拽，标签管理，跨端实时同步 |
| 字典管理 | 管理数据字典大类及其小类，支持联动与导入导出 |
| 任务调度 | 管理和查看任务及其运行日志，支持启停与立即执行 |
| 登录策略 | 管理登录限制策略，配置限制类型、方式、值与原因 |
| 语言管理 | 管理系统支持的多语言，配置语言代码、启用与默认状态 |

### 消息与日志

| 功能 | 说明 |
|------|-----|
| 站内信 | 站内消息管理，支持消息详细查看、删除、标为已读、全部已读 |
| 登录日志 | 登录日志列表查询，记录登录成功与失败日志 |
| 操作日志 | 操作日志列表查询，记录用户操作正常与异常日志 |
| API 日志 | API 日志列表查询，记录请求的操作者、路径、方法与成功状态 |
| 数据日志 | 数据访问日志列表查询，记录数据访问行为 |
| 权限日志 | 权限变更日志列表查询，记录权限变更操作 |

### 个人中心

| 功能 | 说明 |
|------|-----|
| 个人中心 | 个人信息展示和修改，查看最后登录信息，密码修改等功能 |

---

## 项目结构

```
go-wind-kanban/
├── backend/                        # 后端项目
│   ├── api/                        # Protobuf API 定义与生成代码
│   │   ├── protos/                 # .proto 源文件（按领域分层）
│   │   └── gen/go/                 # buf 生成的 Go 代码
│   ├── app/                        # 服务应用
│   │   ├── admin/service/          # Admin 服务（管理后台 API）
│   │   ├── app/service/            # App 服务（客户端 API + WebSocket）
│   │   └── core/service/           # Core 服务（业务核心，看板域）
│   │       └── internal/data/ent/  # Ent ORM 生成代码（board/card/column/label）
│   ├── pkg/                        # 公共包
│   ├── scripts/                    # 部署脚本（env/docker/deploy）
│   └── sql/                        # 初始化 SQL 文件
├── frontend/
│   ├── admin/                      # Admin 前端（Vue 3 + Vben Admin）
│   └── app/flutter_app/            # App 客户端（Flutter 跨平台原生应用）
└── docs/                           # 项目文档
```

---

## 社区与贡献

欢迎参与 GoWind Kanban 的建设。以下文档说明如何贡献代码、报告问题：

- [后端开发规范](./backend/AGENTS.md) —— Kratos / Protobuf / Ent 代码生成约定
- [前端开发规范](./frontend/admin/AGENTS.md) —— Admin 前端架构与约定
- [Flutter 开发规范](./frontend/app/flutter_app/AGENTS.md) —— App 客户端架构与约定

## 联系我们

- 微信个人号：`yang_lin_bo`（备注：`go-wind-kanban`）

## 致谢

[![JetBrains](https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg)](https://jb.gg/OpenSource)

感谢 JetBrains 提供免费的 GoLand & WebStorm 开源授权。
