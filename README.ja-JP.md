<div align="center">

<img src="docs/brand/vortex-tile.svg" width="120" alt="GoWind Kanban｜風行カンバン" />

# GoWind Kanban｜風行カンバン

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go)](https://go.dev/)
[![Vue](https://img.shields.io/badge/Vue-3.x-4FC08D?logo=vuedotjs)](https://vuejs.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)

[English](./README.en-US.md) | [中文](./README.md) | **日本語**

</div>

---

## プロジェクトの特徴

- **マイクロサービスとモノリスを自由に切り替え**：go-kratos マイクロサービスフレームワークに基づき、admin / app / core の3サービスが gRPC + Gateway で相互接続します。同時にモノリス構成での開発・デプロイもサポートし、チーム規模に柔軟に対応します
- **エンタープライズ級 RBAC**：マルチテナント、マルチロール、マルチ部門、メニュー / ボタン / データレベルの権限制御をサポートします
- **フルスタックのコード生成**：Protobuf → Go API / Dart クライアント、Ent Schema → ORM、ワンクリックの足場作成
- **リアルタイム協業**：SSE と WebSocket のワンタイムチケット握手による、ボードの列 / カード / ラベルのリアルタイム多端末同期
- **クロスプラットフォームのネイティブクライアント**：単一の Flutter コードベースが iOS / Android / Web / macOS / Windows / Linux にコンパイルされ、モバイルとデスクトップの適応レイアウトを提供します

---

## 技術スタック

<table>
<tr><th>階層</th><th>技術</th></tr>
<tr><td><strong>バックエンドフレームワーク</strong></td><td><code>Golang</code> · <code>go-kratos v2</code> · <code>Wire</code> · <code>Protobuf / Buf</code></td></tr>
<tr><td><strong>ORM</strong></td><td><code>Ent</code> · <code>PostgreSQL</code></td></tr>
<tr><td><strong>ミドルウェア</strong></td><td><code>Redis</code> · <code>Etcd</code>（サービスディスカバリ） · <code>Jaeger</code>（トレーシング）</td></tr>
<tr><td><strong>認証・認可</strong></td><td><code>JWT</code> · <code>RBAC</code></td></tr>
<tr><td><strong>リアルタイム通信</strong></td><td><code>SSE</code>（サーバープッシュ） · <code>WebSocket</code>（ワンタイムチケット握手） · <code>Asynq</code>（非同期タスク）</td></tr>
<tr><td><strong>Admin フロントエンド</strong></td><td><code>Vue 3</code> · <code>TypeScript</code> · <code>Vite</code> · <code>Ant Design Vue</code> · <code>Vben Admin</code></td></tr>
<tr><td><strong>App フロントエンド</strong></td><td><code>Flutter</code> · <code>Dart</code> · <code>BLoC / Cubit</code> · <code>go_router</code>（クロスプラットフォームネイティブアプリ）</td></tr>
<tr><td><strong>DevOps</strong></td><td><code>Docker</code> · <code>Docker Compose</code> · <code>PM2</code> · <code>Swagger UI</code></td></tr>
</table>

---

## クイックスタート

### 環境要件

| ツール | バージョン |
|--------|------------|
| Go | 1.26+ |
| Node.js | >= 20.10.0 |
| pnpm | >= 10.0.0 |
| Flutter | 3.x（App クライアント開発） |
| Docker | 20.0+ |

### スクリプト選択

- Linux / macOS 開発環境：`backend/scripts/env/install_unix_dev.sh`
- Linux / macOS 本番環境：`backend/scripts/env/install_unix_prod.sh`
- Windows 開発環境：`backend/scripts/env/install_windows_dev.ps1`

### Docker の2つのデプロイモード

- **full_deploy（フルモード）**：ミドルウェアとバックエンドアプリを同時に起動し、ワンクリックのデモや本番デプロイに適します
- **libs_only（依存モード、開発推奨）**：ミドルウェアのみ起動し、アプリはローカル IDE で実行・デバッグします

### バックエンドの起動

**Linux / macOS：**

```shell
# スクリプトに実行権限を付与
chmod +x backend/scripts/**/*.sh

# 開発環境（推奨）
./backend/scripts/env/install_unix_dev.sh
./backend/scripts/docker/libs_only.sh

# 対応するサービスディレクトリに入って実行（admin / app / core）
cd backend/app/admin/service
make run

# 本番環境
./backend/scripts/env/install_unix_prod.sh
./backend/scripts/docker/full_deploy.sh

# PM2 によるプロセス管理（本番・上級）
./backend/scripts/deploy/pm2_service.sh
```

**Windows（管理者権限の PowerShell）：**

```powershell
# スクリプトポリシーを回避（初回のみ実行）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 環境を初期化
.\backend\scripts\env\install_windows_dev.ps1

# ローカル開発
.\backend\scripts\docker\libs_only.ps1
cd backend\app\admin\service
make run

# ワンクリックでフルデプロイ
.\backend\scripts\docker\full_deploy.ps1
```

### フロントエンドの起動

フロントエンドは管理コンソールとクロスプラットフォームクライアントの2つに分かれており、いずれも `frontend/` ディレクトリに配置されています。

| フロントエンド | ディレクトリ | 起動コマンド | ポート |
|----------------|--------------|--------------|--------|
| Admin（Vue3 Vben） | `frontend/admin` | `pnpm dev:antd` | 5666 |
| App（Flutter） | `frontend/app/flutter_app` | `flutter run` | — |

```shell
# Admin フロントエンド
cd frontend/admin
pnpm install
pnpm dev:antd

# Flutter App
cd frontend/app/flutter_app
flutter pub get
flutter run   # または flutter run -d chrome / windows
```

---

## 機能一覧

### 組織と権限

| 機能 | 説明 |
|------|------|
| ユーザー管理 | ユーザーの管理と照会。部門連動表示、無効化 / 有効化、パスワードリセット、複数ロール・複数部門の設定をサポート |
| テナント管理 | テナントを管理。テナント作成時に部門とデフォルト管理者を自動初期化 |
| ロール管理 | ロールとロールグループを管理し、メニューとデータ権限を設定、メンバーの一括追加・削除をサポート |
| 権限管理 | 権限グループ、メニュー、権限ポイントを管理、ツリー形式で表示 |
| 組織管理 | 組織構造を管理、ツリー形式で表示 |
| 職位管理 | ユーザーの職務を管理。職位はユーザーのタグとして使用可能 |
| メニュー管理 | システムメニュー、操作権限、ボタン権限識別子（ディレクトリ / メニュー / ボタン）を設定 |
| API管理 | 権限ポイント追加時に選択するインターフェースを管理、ツリー形式で表示 |

### システム機能

| 機能 | 説明 |
|------|------|
| カンバン協業 | ボード、列、カードの作成 / 編集 / ドラッグ、ラベル管理、クロスデバイスのリアルタイム同期 |
| 辞書管理 | 辞書の大分類と小分類を管理、連動、インポート・エクスポートをサポート |
| タスクスケジューリング | タスクとその実行ログを管理・参照。開始 / 停止、即時実行をサポート |
| ログインポリシー | ログイン制限ポリシーを管理し、制限タイプ、方式、値、理由を設定 |
| 言語管理 | サポートする多言語を管理し、言語コード、有効・デフォルト状態を設定 |

### メッセージとログ

| 機能 | 説明 |
|------|------|
| 站内信（サイト内メッセージ） | サイト内メッセージの管理。詳細表示、削除、既読化、一括既読化をサポート |
| ログインログ | ログインログの照会。ログインの成功と失敗を記録 |
| 操作ログ | 操作ログの照会。ユーザーの正常・異常操作を記録 |
| APIログ | APIログの照会。リクエストの操作者、パス、メソッド、成功状態を記録 |
| データログ | データアクセスログの照会。データアクセス挙動を記録 |
| 権限ログ | 権限変更ログの照会。権限変更操作を記録 |

### 個人センター

| 機能 | 説明 |
|------|------|
| 個人センター | 個人情報の表示と編集、最終ログイン情報の確認、パスワード変更など |

---

## プロジェクト構造

```
go-wind-kanban/
├── backend/                        # バックエンドプロジェクト
│   ├── api/                        # Protobuf API 定義と生成コード
│   │   ├── protos/                 # .proto ソース（ドメイン別階層）
│   │   └── gen/go/                 # buf 生成の Go コード
│   ├── app/                        # サービスアプリケーション
│   │   ├── admin/service/          # Admin サービス（管理コンソール API）
│   │   ├── app/service/            # App サービス（クライアント API + WebSocket）
│   │   └── core/service/           # Core サービス（業務コア、カンバンドメイン）
│   │       └── internal/data/ent/  # Ent ORM 生成コード（board/card/column/label）
│   ├── pkg/                        # 共通パッケージ
│   ├── scripts/                    # デプロイスクリプト（env/docker/deploy）
│   └── sql/                        # 初期化 SQL ファイル
├── frontend/
│   ├── admin/                      # Admin フロントエンド（Vue 3 + Vben Admin）
│   └── app/flutter_app/            # App クライアント（Flutter クロスプラットフォームネイティブアプリ）
└── docs/                           # プロジェクトドキュメント
```

---

## コミュニティと貢献

GoWind Kanban への貢献を歓迎します。コードの貢献方法や問題の報告方法については以下のドキュメントを参照してください：

- [バックエンド開発規約](./backend/AGENTS.md) —— Kratos / Protobuf / Ent のコード生成規約
- [フロントエンド開発規約](./frontend/admin/AGENTS.md) —— Admin フロントエンドのアーキテクチャと規約
- [Flutter 開発規約](./frontend/app/flutter_app/AGENTS.md) —— App クライアントのアーキテクチャと規約

## お問い合わせ

- WeChat：`yang_lin_bo`（備考：`go-wind-kanban`）

## 謝辞

[![JetBrains](https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg)](https://jb.gg/OpenSource)

JetBrains に、無料の GoLand & WebStorm オープンソースライセンスを提供していただき感謝いたします。
