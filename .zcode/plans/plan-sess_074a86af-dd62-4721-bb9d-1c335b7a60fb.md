# go-wind-kanban CMS 域清除方案

## 决策记录（已确认）

**保留**：identity（用户/租户/角色/组织/岗位/成员）、authentication、permission（RBAC: 菜单/API/权限组/策略）、board（看板）、**audit、dict、task、internal_message**（含 admin SSE）。
**删除**：content（page/post/section/category/tag 及翻译表）、comment、interaction、media、site（site/navigation/site_setting）、translator、storage（file/file-transfer/MinIO）、OpenSearch/ES 搜索、DTM（已断链，删除即修复构建）。

**前置事实**：ent 层零跨域边（全是软外键），identity 不依赖 file/media（头像为纯字符串 URL），permission 只依赖 menu/api——删除无悬空引用风险。`backend/`、`frontend/` 目前未被 git 跟踪，删除不可逆。

## Step 0：安全快照（必做）

`git add -A && git commit -m "snapshot: full go-wind-cms baseline before CMS domain removal"`——大规模删除前建立唯一还原点（原 go-wind-cms 仓仍是外部备份）。

## Step 1：Proto 层删减

**删除域包** `backend/api/protos/`：`content/ comment/ interaction/ media/ site/ translator/ storage/` 七个目录。
**删除 admin 面 i_ 文件**：`i_post i_category i_tag i_comment i_interaction i_page i_section i_site i_site_setting i_navigation i_navigation_item i_media_asset i_file i_file_transfer i_translator`。
**删除 app 面 i_ 文件**：`i_post i_category i_tag i_page i_section i_comment i_interaction i_navigation i_file_transfer`。
**buf.gen.yaml**：删除 content/comment/interaction/media/site/translator/storage 七条 go_package override（保留 board 及其余）。
执行 `make api`——`clean: true` 自动清空重生成 `gen/go/`，被删域的生成物随之消失。
**admin_doc.proto / app_doc.proto** 标题从 "GoWind Content Hub" 改为 "GoWind Kanban"（纯 OpenAPI 元数据，无 CMS API 定义）。

## Step 2：core 服务删减

**ent/schema 删除 19 个**：`comment comment_like interaction_counter post post_translation post_category post_tag post_like post_watch page page_translation section section_translation category category_translation tag tag_translation site site_setting navigation navigation_item media_asset media_variant file` → `make ent` 重生成。
**data/ 删除 repo**：post/page/section/category/category_translation/tag/tag_translation/comment/interaction/media_asset/media_variant/file/search/site/site_setting/navigation/navigation_item 共 16 个 `*_repo.go`；删除 `client/elasticsearch_client.go`、`client/minio_client.go`。
**service/ 删除**：post/page/section/category/tag/comment/interaction/interaction_admin/media_asset/site/site_setting/navigation/navigation_item/search/file/file_transfer 共 15 个 `*_service.go`。
**task_service.go 剥离搜索残留**：删 `EnqueueSearchReindex`、删未使用的 `userRepo` 构造参数。
**asynq_server.go**：删 `searchService` 参数与 `ReindexPost` 注册，保留 task 注册与 StartAllTask。
**grpc_server.go**：删被移除服务的参数与 Register 行。
**wire sets**：data 层删 `NewSearchRepo/NewMinIoClient/NewElasticSearchClient` + 16 repo；service 层删 15 service。
**configs**：`core/data.yaml` 删 opensearch 块；删 `core/configs/oss.yaml`（asynq 块保留）。

## Step 3：admin/app BFF 删减

**admin data.go**：删 post/category/tag/comment/interaction/page/section/site/site-setting/navigation/navigation-item/media-asset/file/file-transfer/translator 的 15 个 client 工厂；**删除 `data/dtm.go`** 及 `data.go` 中 `NewDtmDriver` 调用；`grpc_server.go` 删 `workflow.InitGrpc`。
**admin service/**：删除对应 15 个 pass-through；保留 AdminPortalService（只依赖 menu/permission/role/user）、internal_message×3、task、audit、dict、board。
**rest_server.go**：删对应参数与 Register 行；删 `registerFileTransferServiceHandler` 与 `server/i_file_transfer_http.pb.go`（手写 multipart handler）。
**sse_server.go 保留**（internal_message 域保留，admin SSE 即其推送通道）。
**app 同构**：删 9 个 client 工厂 + 9 个 pass-through + dtm.go + InitGrpc + 手写 handler；保留 auth/user_profile/board×3；app sse（仅 auth 鉴权的空壳）保留。
**configs**：删 admin/app 的 `oss.yaml`。
三服务 `make wire` 重生成。

## Step 4：pkg 与 go.mod

- 删除 `pkg/oss/`（唯一使用方是 storage 域）；`pkg/task/` 删 `search_reindex.go` 留 `backup.go`。
- `go mod tidy`——自动剔除 opensearch/minio/dtm/gopher-lua 等孤儿依赖。

## Step 5：sql / scripts 清理

- `sql/postgresql-demo-data.sql`、`mysql-demo-data.sql`：删除 CMS 表种子（pages/posts/categories/tags/comments/sites/navigations/media 等约 2500 行 INSERT），保留 identity/dict/task/internal_message/audit 种子。
- 删 `scripts/docker/opensearch/Dockerfile`；`full_deploy`/`libs_only` 脚本中去掉 opensearch 与 minio 服务引用。

## Step 6：验证后端

`make api && make ent && make wire && make build`；`go build ./...`（pkg/lua 已不存在，全模块应过）；`go vet ./pkg/lexorank/... ./app/core/service/internal/...`；`go test ./pkg/lexorank/...`；`make openapi` 重生成 Swagger 资产（确认 CMS 路由消失）。

## Step 7：admin 前端（apps/admin/src，packages/ 零改动）

- **删除 views**：`views/app/content/`（22 文件）、`views/app/engagement/`（2）、`views/app/media/`（2）、`views/app/site_setting/`（10）、`views/app/system/file/`（file 域已删）。保留 internal_message/opm/permission/log/system（dict/task/login_policy/language）/tenant。
- **删除路由模块**：`modules/app/content.ts engagement.ts media.ts site_setting.ts`；编辑 `system.ts` 去掉 file 路由。
- **删除 composables**：post/page/category/tag/section/comment/media-asset/navigation/navigation-item/site/site-setting/translator/file-transfer/file 共 14 个；保留其余（含 internal-message/task/dict/language/audit/admin-portal）。
- **重新生成 TS 客户端**：`buf generate --template buf.admin.typescript.gen.yaml`（index.ts 单文件自动瘦身，identity 与 CMS 共享一个 ApiClient 的问题随重生成消解）。
- **locales**：`langs/{en-US,zh-CN}/{menu,page,enum}.json` 删除已移除模块的键（menu 必清，page/enum 清明显块）。
- 验证：`pnpm build`（或 vue-tsc 类型检查）通过。

## Step 8：Flutter（frontend/app/flutter_app）

- 删 `lib/src/features/cms/`（46 文件）及 `data/mock_data.dart`。
- 重写 `app_router.dart`：去掉 14 处 CMS 页面导入，保留 auth + 壳路由。
- `app.dart`/`main.dart` 剥离 CMS 引用（类名 CMSApp→KanbanApp 顺带改名，README 改题）。
- 修 `test/widget_test.dart`（当前 pump CMSApp）。
- **重新生成 dart 客户端**：`buf generate --template buf.app.dart.gen.yaml`（clean:true 自动瘦身）。
- 验证：`flutter analyze` 通过。

## 风险与说明

- **不可逆**：Step 0 快照是唯一内部还原点；原 go-wind-cms 仓为外部备份。
- **将来卡片附件**：文件域删除后，做附件功能时从原仓移植（或按看板需求重构），原型链路在原仓完整。
- **module 名仍为 go-wind-cms**：本次不改（牵动全仓 import 路径，属独立重构任务，建议后续单做）。
- **admin 前端 system/file 页** 与后端 file 域同步删除，避免死页面。
- **dashboard/message 占位页** 无 API 依赖或属保留域，不动。

## 交付顺序

Step 0 → 1 → 2 → 3 → 4 → 5 → 6（后端绿）→ 7（admin 绿）→ 8（flutter 绿）。任一步验证失败即停在该步修复，不带病前进。