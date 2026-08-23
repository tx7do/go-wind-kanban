<div align="center">

# GoWind Kanban

**An out-of-the-box enterprise kanban collaboration platform**

> **Let team collaboration flow as freely as the wind — GoWind Kanban**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go)](https://go.dev/)
[![Vue](https://img.shields.io/badge/Vue-3.x-4FC08D?logo=vuedotjs)](https://vuejs.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)

**English** | [中文](./README.md) | [日本語](./README.ja-JP.md)

</div>

---

## Project Highlights

- **Microservices + Monolith, freely switchable**: Built on the go-kratos microservice framework, the admin / app / core services interconnect via gRPC + Gateway, while also supporting monolithic-mode development and deployment to flexibly fit team size
- **Enterprise-grade RBAC**: Supports multi-tenant, multi-role, multi-department, and menu / button / data-level permission control
- **Full-stack code generation**: Protobuf → Go API / Dart clients, Ent Schema → ORM, one-click scaffolding
- **Real-time collaboration**: Real-time multi-device sync of board columns / cards / labels via SSE and WebSocket with one-time ticket handshake
- **Cross-platform native client**: A single Flutter codebase compiles to iOS / Android / Web / macOS / Windows / Linux, with adaptive mobile and desktop layouts

---

## Tech Stack

<table>
<tr><th>Layer</th><th>Technology</th></tr>
<tr><td><strong>Backend framework</strong></td><td><code>Golang</code> · <code>go-kratos v2</code> · <code>Wire</code> · <code>Protobuf / Buf</code></td></tr>
<tr><td><strong>ORM</strong></td><td><code>Ent</code> · <code>PostgreSQL</code></td></tr>
<tr><td><strong>Middleware</strong></td><td><code>Redis</code> · <code>Etcd</code> (service discovery) · <code>Jaeger</code> (tracing)</td></tr>
<tr><td><strong>Auth</strong></td><td><code>JWT</code> · <code>RBAC</code></td></tr>
<tr><td><strong>Real-time</strong></td><td><code>SSE</code> (server push) · <code>WebSocket</code> (one-time ticket handshake) · <code>Asynq</code> (async tasks)</td></tr>
<tr><td><strong>Admin frontend</strong></td><td><code>Vue 3</code> · <code>TypeScript</code> · <code>Vite</code> · <code>Ant Design Vue</code> · <code>Vben Admin</code></td></tr>
<tr><td><strong>App frontend</strong></td><td><code>Flutter</code> · <code>Dart</code> · <code>BLoC / Cubit</code> · <code>go_router</code> (cross-platform native app)</td></tr>
<tr><td><strong>DevOps</strong></td><td><code>Docker</code> · <code>Docker Compose</code> · <code>PM2</code> · <code>Swagger UI</code></td></tr>
</table>

---

## Quick Start

### Environment Requirements

| Tool | Version |
|------|---------|
| Go | 1.26+ |
| Node.js | >= 20.10.0 |
| pnpm | >= 10.0.0 |
| Flutter | 3.x (App client development) |
| Docker | 20.0+ |

### Script Selection

- Linux / macOS dev environment: `backend/scripts/env/install_unix_dev.sh`
- Linux / macOS production environment: `backend/scripts/env/install_unix_prod.sh`
- Windows dev environment: `backend/scripts/env/install_windows_dev.ps1`

### Docker Deployment Modes

- **full_deploy (full mode)**: Starts middleware + backend applications together, suitable for one-click demos and production deployment
- **libs_only (dependency mode, recommended for dev)**: Starts only middleware; applications run locally in the IDE for debugging

### Backend Startup

**Linux / macOS:**

```shell
# Grant execute permission to scripts
chmod +x backend/scripts/**/*.sh

# Development environment (recommended)
./backend/scripts/env/install_unix_dev.sh
./backend/scripts/docker/libs_only.sh

# Enter the corresponding service directory to run (admin / app / core)
cd backend/app/admin/service
make run

# Production environment
./backend/scripts/env/install_unix_prod.sh
./backend/scripts/docker/full_deploy.sh

# PM2 process supervision (advanced production)
./backend/scripts/deploy/pm2_service.sh
```

**Windows (PowerShell as administrator):**

```powershell
# Bypass script policy (run once only)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Initialize environment
.\backend\scripts\env\install_windows_dev.ps1

# Local development
.\backend\scripts\docker\libs_only.ps1
cd backend\app\admin\service
make run

# One-click full deployment
.\backend\scripts\docker\full_deploy.ps1
```

### Frontend Startup

The frontend is split into an admin console and a cross-platform client, both under the `frontend/` directory.

| Frontend | Directory | Command | Port |
|----------|-----------|---------|------|
| Admin (Vue3 Vben) | `frontend/admin` | `pnpm dev:antd` | 5666 |
| App (Flutter) | `frontend/app/flutter_app` | `flutter run` | — |

```shell
# Admin frontend
cd frontend/admin
pnpm install
pnpm dev:antd

# Flutter App
cd frontend/app/flutter_app
flutter pub get
flutter run   # or flutter run -d chrome / windows
```

---

## Feature List

### Organization & Permissions

| Feature | Description |
|---------|-------------|
| User management | Manage and query users; supports department-linked views, disable / enable, password reset, multi-role and multi-department configuration |
| Tenant management | Manage tenants; creating a tenant auto-initializes its department and default administrator |
| Role management | Manage roles and role groups, set menu and data permissions, batch add and remove members |
| Permission management | Manage permission groups, menus, and permission points, displayed as trees |
| Organization management | Manage organizational structure, displayed as a tree |
| Position management | Manage user job positions; positions can serve as user tags |
| Menu management | Configure system menus, operation permissions, and button permission identifiers (directory / menu / button) |
| API management | Manage APIs used for selecting interfaces when adding permission points, displayed as trees |

### System Functions

| Feature | Description |
|---------|-------------|
| Kanban collaboration | Creation / editing / dragging of boards, columns and cards, label management, real-time cross-device sync |
| Dictionary management | Manage dictionary categories and their entries, with linking, import and export |
| Task scheduling | Manage and view tasks and their run logs; supports start / stop and immediate execution |
| Login policy | Manage login restriction policies, configuring restriction type, mode, value, and reason |
| Language management | Manage supported languages, configuring language codes, enabled and default states |

### Messages & Logs

| Feature | Description |
|---------|-------------|
| Internal message | Internal message management; supports detail view, delete, mark-as-read, and mark-all-read |
| Login log | Login log query; records successful and failed logins |
| Operation log | Operation log query; records normal and abnormal user operations |
| API log | API log query; records the operator, path, method, and success status of requests |
| Data log | Data access log query; records data access behavior |
| Permission log | Permission change log query; records permission change operations |

### Personal Center

| Feature | Description |
|---------|-------------|
| Personal center | View and edit personal info, view last login info, change password |

---

## Project Structure

```
go-wind-kanban/
├── backend/                        # Backend project
│   ├── api/                        # Protobuf API definitions and generated code
│   │   ├── protos/                 # .proto sources (layered by domain)
│   │   └── gen/go/                 # buf-generated Go code
│   ├── app/                        # Service applications
│   │   ├── admin/service/          # Admin service (admin console API)
│   │   ├── app/service/            # App service (client API + WebSocket)
│   │   └── core/service/           # Core service (business core, kanban domain)
│   │       └── internal/data/ent/  # Ent ORM generated code (board/card/column/label)
│   ├── pkg/                        # Common packages
│   ├── scripts/                    # Deployment scripts (env/docker/deploy)
│   └── sql/                        # Initialization SQL files
├── frontend/
│   ├── admin/                      # Admin frontend (Vue 3 + Vben Admin)
│   └── app/flutter_app/            # App client (Flutter cross-platform native app)
└── docs/                           # Project documentation
```

---

## Community & Contribution

Contributions to GoWind Kanban are welcome. The following docs describe how to contribute code and report issues:

- [Backend conventions](./backend/AGENTS.md) — Kratos / Protobuf / Ent code generation conventions
- [Frontend conventions](./frontend/admin/AGENTS.md) — Admin frontend architecture and conventions
- [Flutter conventions](./frontend/app/flutter_app/AGENTS.md) — App client architecture and conventions

## Contact

- WeChat: `yang_lin_bo` (note: `go-wind-kanban`)

## Acknowledgments

[![JetBrains](https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg)](https://jb.gg/OpenSource)

Thanks to JetBrains for providing free GoLand & WebStorm open-source licenses.
