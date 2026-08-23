BEGIN;

SET LOCAL search_path = public, pg_catalog;

-- 一次性清理相关表并重置自增（包含外键依赖）
TRUNCATE TABLE public.sys_org_units,
               public.sys_positions,
               public.sys_tasks,
               public.sys_login_policies,
               public.sys_dict_types,
               public.sys_dict_entries,
               public.internal_message_categories
RESTART IDENTITY CASCADE;

-- ----------------------------
-- 插入 sys_tenants 租户
-- ----------------------------
INSERT INTO public.sys_tenants(id, name, code, type, audit_status, status, admin_user_id, created_at)
VALUES (1, '测试租户', 'super', 'PAID', 'APPROVED', 'ON', 2, now())
;
SELECT setval('sys_tenants_id_seq', (SELECT MAX(id) FROM sys_tenants));

-- ----------------------------
-- 插入 sys_users 租户管理员用户
-- ----------------------------
INSERT INTO public.sys_users (id, tenant_id, username, nickname, realname, email, gender, created_at)
VALUES
    -- 2. 租户管理员（TENANT_ADMIN）
    (2, 1, 'tenant_admin', '租户管理', '张管理员', 'tenant@company.com', 'MALE', now())
;
SELECT setval('sys_users_id_seq', (SELECT MAX(id) FROM sys_users));

-- ----------------------------
-- 插入 sys_user_credentials 用户凭证（密码统一为admin，哈希值与原admin一致，方便测试）
-- ----------------------------
INSERT INTO public.sys_user_credentials (tenant_id, user_id, identity_type, identifier, credential_type, credential, status,
                                         is_primary, created_at)
VALUES
    -- 租户管理员（对应users表id=2，tenant_id=1）
    (1, 2, 'USERNAME', 'tenant_admin', 'PASSWORD_HASH', '$2a$10$yajZDX20Y40FkG0Bu4N19eXNqRizez/S9fK63.JxGkfLq.RoNKR/a', 'ENABLED', true, now()),
    (1, 2, 'EMAIL', 'tenant@company.com', 'PASSWORD_HASH', '$2a$10$yajZDX20Y40FkG0Bu4N19eXNqRizez/S9fK63.JxGkfLq.RoNKR/a', 'ENABLED', false, now())
;
SELECT setval('sys_user_credentials_id_seq', (SELECT MAX(id) FROM sys_user_credentials));

-- ----------------------------
-- 插入 sys_org_units 组织架构单元
-- ----------------------------
INSERT INTO public.sys_org_units (id, tenant_id, parent_id, type, name, code, description, path, sort_order, leader_id, status, created_at)
VALUES
    (1, 1, NULL, 'COMPANY', 'XX集团总部', 'HEADQUARTERS', '集团核心管理机构，统筹全集团战略规划、业务管控及资源调配', '/1', 1, 1, 'ON', now()),
    (2, 1, 1, 'DIVISION', '技术部', 'TECH', '负责集团整体技术架构规划、研发管理、系统运维及技术创新', '/1/2', 2, 5, 'ON', now()),
    (3, 1, 1, 'DIVISION', '财务部', 'FIN', '负责集团财务核算、资金管理、税务筹划、预算编制及财务风控', '/1/3', 3, 8, 'ON', now()),
    (4, 1, 1, 'DIVISION', '人事部', 'HR', '负责人力资源规划、招聘配置、薪酬绩效、员工培训及组织发展', '/1/4', 4, 9, 'ON', now()),
    (5, 1, 2, 'DEPARTMENT', '研发一部', 'DEV-1', '聚焦新能源领域产品研发、技术迭代及核心模块开发', '/1/2/5', 1, 6, 'ON', now()),
    (6, 1, 1, 'REGION', '华北大区', 'NORTH', '负责华北区域市场运营、客户维护、销售管理及本地化服务落地', '/1/6', 3, 12, 'ON', now()),
    (7, 1, 1, 'SUBSIDIARY', '广州分公司', 'GZ', '负责华南区域（广州及周边）业务拓展、客户服务及本地化运营', '/1/7', 5, 2, 'ON', now()),
    (8, 1, 1, 'SUBSIDIARY', '深圳子公司', 'SZ', '负责深圳区域市场开拓、科技创新业务落地及高端客户对接', '/1/8', 6, 4, 'ON', now()),
    (9, 1, 1, 'DIVISION', '销售部', 'SALES', '统筹集团整体销售策略制定、销售团队管理及业绩目标达成', '/1/9', 7, 16, 'ON', now()),
    (10, 1, 9, 'DEPARTMENT', '海外事业部', 'INTL', '负责海外市场拓展、国际客户合作、跨境业务管理及本地化运营', '/1/9/10', 1, 17, 'ON', now()),
    (11, 1, 10, 'TEAM', '海外销售组', 'INTL-SALES-1', '具体执行海外市场销售任务，跟进客户需求及订单落地', '/1/9/10/11', 1, 18, 'ON', now()),
    (12, 1, 5, 'PROJECT', '新能源项目组', 'NEO-PROJ', '专项负责新能源项目的研发、落地、运营及成果转化', '/1/2/5/12', 1, 6, 'ON', now()),
    (13, 1, 1, 'COMMITTEE', '审计委员会', 'AUDIT', '独立开展集团内部审计、风控检查、合规监督及问题整改跟进', '/1/13', 8, 12, 'ON', now()),
    (14, 1, 1, 'DEPARTMENT', '客服部', 'CS', '负责全集团客户咨询、投诉处理、售后服务及客户满意度提升', '/1/14', 9, 11, 'ON', now()),
    (15, 1, 14, 'TEAM', '客服一组', 'CS-1', '承接华南区域客户服务、售后问题处理及客户关系维护', '/1/14/15', 1, 20, 'ON', now())
;
SELECT setval('sys_org_units_id_seq', (SELECT MAX(id) FROM sys_org_units));

-- ----------------------------
-- 插入 sys_positions 岗位数据
-- ----------------------------
INSERT INTO public.sys_positions (id, tenant_id, type, name, code, org_unit_id, reports_to_position_id, description, job_family, job_grade, level, headcount, is_key_position, status, sort_order, created_at)
VALUES
    (1, 1, 'LEADER', '技术总监', 'TECH-DIRECTOR-001', 2, NULL, '负责公司整体技术战略规划、团队管理及核心技术决策', 'TECH', 1, 1, 1, true, 'ON', 1, now()),
    (2, 1, 'MANAGER', '技术部经理', 'TECH-MANAGER-001', 2, 1, '负责技术部日常管理、项目排期及团队协作', 'TECH', 2, 2, 1, true, 'ON', 2, now()),
    (3, 1, 'MANAGER', '前端主管', 'TECH-FE-LEADER-001', 2, 2, '负责前端团队开发管理、技术方案评审及需求落地', 'TECH', 3, 3, 3, false, 'ON', 3, now()),
    (4, 1, 'MANAGER', '后端主管', 'TECH-BE-LEADER-001', 2, 2, '负责后端服务架构设计、数据库优化及接口开发管理', 'TECH', 4, 3, 3, false, 'ON', 4, now()),
    (5, 1, 'REGULAR', '前端开发专员', 'TECH-FE-DEV-001', 2, 3, '负责Web/移动端前端页面开发、交互实现及兼容性优化', 'TECH', 5, 4, 5, false, 'ON', 5, now()),
    (6, 1, 'REGULAR', '后端开发专员', 'TECH-BE-DEV-001', 2, 4, '负责后端接口开发、业务逻辑实现及系统稳定性维护', 'TECH', 6, 4, 5, false, 'ON', 6, now()),
    (7, 1, 'REGULAR', '测试工程师', 'TECH-TEST-001', 2, 2, '负责项目功能测试、性能测试及自动化测试脚本开发', 'TECH', 3, 4, 3, false, 'ON', 7, now()),
    (8, 1, 'LEADER', '人力总监', 'HR-DIRECTOR-001', 2, NULL, '负责人力资源战略规划、组织架构设计及人才梯队建设', 'HR', 1, 1, 1, true, 'ON', 1, now()),
    (9, 1, 'MANAGER', '招聘主管', 'HR-RECRUIT-LEADER-001', 2, 8, '负责公司各部门招聘需求对接、简历筛选及面试安排', 'HR', 2, 2, 1, false, 'ON', 2, now()),
    (10, 1, 'REGULAR', '薪酬绩效专员', 'HR-C&P-001', 2, 8, '负责员工薪酬核算、绩效考核制度落地及社保公积金管理', 'HR', 3, 2, 1, false, 'ON', 3, now()),
    (11, 1, 'REGULAR', 'HRBP', 'HR-BP-001', 2, 8, '对接业务部门，提供人力资源支持（入离职、员工关系等）', 'HR', 4, 2, 1, false, 'ON', 4, now()),
    (12, 1, 'LEADER', '财务总监', 'FIN-DIRECTOR-001', 2, NULL, '负责公司财务战略、预算管理及财务风险控制', 'FIN', 1, 1, 1, true, 'ON', 1, now()),
    (13, 1, 'MANAGER', '会计主管', 'FIN-ACCOUNT-LEADER-001', 2, 12, '负责账务处理、财务报表编制及税务申报管理', 'FIN', 2, 2, 1, false, 'ON', 2, now()),
    (14, 1, 'REGULAR', '出纳专员', 'FIN-CASHIER-001', 2, 13, '负责日常资金收付、银行对账及票据管理', 'FIN', 3, 3, 1, false, 'ON', 3, now()),
    (15, 1, 'REGULAR', '成本会计', 'FIN-COST-001', 2, 13, '负责成本核算、成本分析及成本控制方案制定', 'FIN', 4, 3, 1, false, 'ON', 4, now()),
    (16, 1, 'LEADER', '市场总监', 'MKT-DIRECTOR-001', 4, NULL, '负责市场战略规划、品牌建设及营销活动策划', 'MKT', 1, 1, 1, true, 'ON', 1, now()),
    (17, 1, 'MANAGER', '新媒体运营主管', 'MKT-NEWS-LEADER-001', 4, 16, '负责新媒体平台内容运营及用户增长', 'MKT', 2, 2, 1, false, 'ON', 2, now()),
    (18, 1, 'REGULAR', '活动策划专员', 'MKT-EVENT-001', 4, 16, '负责线下活动策划、执行及效果复盘', 'MKT', 3, 3, 1, false, 'ON', 3, now()),
    (19, 1, 'REGULAR', '市场调研专员', 'MKT-RESEARCH-001', 4, 16, '负责行业动态调研、竞品分析及市场趋势报告撰写', 'MKT', 4, 3, 1, false, 'ON', 4, now()),
    (20, 1, 'REGULAR', '行政助理', 'ADMIN-ASSIST-001', 2, 8, '负责办公用品采购、会议安排等行政工作（已合并至HRBP）', 'ADMIN', 5, 5, 1, false, 'OFF', 5, now())
;
SELECT setval('sys_positions_id_seq', (SELECT COALESCE(MAX(id), 1) FROM sys_positions));

-- ----------------------------
-- 插入 sys_tasks 调度任务
-- ----------------------------
INSERT INTO public.sys_tasks(type, type_name, task_payload, cron_spec, enable, created_at)
VALUES
    ('PERIODIC', 'backup', '{ "name": "test"}', '0 * * * *', true, now())
;
SELECT setval('sys_tasks_id_seq', (SELECT MAX(id) FROM sys_tasks));

-- ----------------------------
-- 插入 sys_login_policies 登录策略
-- ----------------------------
INSERT INTO public.sys_login_policies(id, target_id, type, method, value, reason, created_at)
VALUES
    (1, 1, 'BLACKLIST', 'IP', '127.0.0.1', '无理由', now()),
    (2, 1, 'WHITELIST', 'MAC', '00:1B:44:11:3A:B7 ', '无理由', now())
;
SELECT setval('sys_login_policies_id_seq', (SELECT MAX(id) FROM sys_login_policies));

-- ----------------------------
-- 插入 sys_dict_types 字典类型
-- ----------------------------
INSERT INTO public.sys_dict_types (
    id, type_code, sort_order, is_enabled, created_at, updated_at
) VALUES
      (1, 'USER_STATUS', 10, true, now(), now()),
      (2, 'DEVICE_TYPE', 20, true, now(), now()),
      (3, 'ORDER_STATUS', 30, true, now(), now()),
      (4, 'GENDER', 40, true, now(), now()),
      (5, 'PAYMENT_METHOD', 50, true, now(), now())
;
SELECT setval('sys_dict_types_id_seq', (SELECT MAX(id) FROM sys_dict_types));

-- ----------------------------
-- 插入 sys_dict_entries 字典条目
-- ----------------------------
INSERT INTO public.sys_dict_entries (
    id, type_id, entry_value, numeric_value, sort_order, is_enabled, created_at, updated_at, tenant_id
) VALUES
      -- 用户状态
      (1, 1, 'NORMAL', 1, 1, true, now(), now(), 0),
      (2, 1, 'FROZEN', 2, 2, true, now(), now(), 0),
      (3, 1, 'CANCELED', 3, 3, true, now(), now(), 0),
      -- 设备类型
      (4, 2, 'TEMP_SENSOR', 101, 1, true, now(), now(), 0),
      (5, 2, 'CURRENT_METER', 102, 2, true, now(), now(), 0),
      (6, 2, 'GAS_DETECTOR', 103, 3, false, now(), now(), 0),
      -- 订单状态
      (7, 3, 'PENDING', 1, 1, true, now(), now(), 0),
      (8, 3, 'PAID', 2, 2, true, now(), now(), 0),
      (9, 3, 'SHIPPED', 3, 3, true, now(), now(), 0),
      (10, 3, 'COMPLETED', 4, 4, true, now(), now(), 0),
      (11, 3, 'CANCELED', 5, 5, true, now(), now(), 0),
      -- 性别
      (12, 4, 'MALE', 1, 1, true, now(), now(), 0),
      (13, 4, 'FEMALE', 2, 2, true, now(), now(), 0),
      (14, 4, 'UNKNOWN', 0, 3, true, now(), now(), 0),
      -- 支付方式
      (15, 5, 'ALIPAY', 1, 1, true, now(), now(), 0),
      (16, 5, 'WECHAT', 2, 2, true, now(), now(), 0),
      (17, 5, 'UNIONPAY', 3, 3, true, now(), now(), 0),
      (18, 5, 'CASH', 4, 4, false, now(), now(), 0)
;
SELECT setval('sys_dict_entries_id_seq', (SELECT MAX(id) FROM sys_dict_entries));

-- ----------------------------
-- 插入 sys_dict_entry_i18n 字典条目国际化
-- ----------------------------
INSERT INTO public.sys_dict_entry_i18n (
    entry_id, language_code, entry_label, description, sort_order, tenant_id, created_at, updated_at
) VALUES
      -- 用户状态
      (1, 'zh-CN', '正常', '用户可正常登录和操作', 1, 0, now(), now()),
      (2, 'zh-CN', '冻结', '因违规被临时冻结，需管理员解冻', 2, 0, now(), now()),
      (3, 'zh-CN', '注销', '用户主动注销，数据保留但不可登录', 3, 0, now(), now()),
      -- 设备类型
      (4, 'zh-CN', '温湿度传感器', '支持温度（-20~80℃）和湿度（0~100%RH）采集', 1, 0, now(), now()),
      (5, 'zh-CN', '电流仪表', '交流/直流电流测量，精度0.5级', 2, 0, now(), now()),
      (6, 'zh-CN', '气体探测器', '暂不支持，待硬件适配（2025Q4计划启用）', 3, 0, now(), now()),
      -- 订单状态
      (7, 'zh-CN', '待支付', '下单后未支付，超时自动取消', 1, 0, now(), now()),
      (8, 'zh-CN', '已支付', '支付成功，等待发货', 2, 0, now(), now()),
      (9, 'zh-CN', '已发货', '商品已出库，物流配送中', 3, 0, now(), now()),
      (10, 'zh-CN', '已完成', '用户确认收货，订单结束', 4, 0, now(), now()),
      (11, 'zh-CN', '已取消', '用户或系统取消订单', 5, 0, now(), now()),
      -- 性别
      (12, 'zh-CN', '男', '', 1, 0, now(), now()),
      (13, 'zh-CN', '女', '', 2, 0, now(), now()),
      (14, 'zh-CN', '未知', '用户未填写时默认值', 3, 0, now(), now()),
      -- 支付方式
      (15, 'zh-CN', '支付宝', '支持花呗、余额宝', 1, 0, now(), now()),
      (16, 'zh-CN', '微信支付', '需绑定微信', 2, 0, now(), now()),
      (17, 'zh-CN', '银联支付', '支持信用卡、储蓄卡', 3, 0, now(), now()),
      (18, 'zh-CN', '现金支付', '线下支付，已废弃（2025-01停用）', 4, 0, now(), now()),

      -- User Status
      (1, 'en-US', 'Normal', 'User can log in and operate normally', 1, 0, now(), now()),
      (2, 'en-US', 'Frozen', 'Temporarily frozen due to violation; requires admin to unfreeze', 2, 0, now(), now()),
      (3, 'en-US', 'Canceled', 'User voluntarily canceled; data retained but login disabled', 3, 0, now(), now()),

      -- Device Type
      (4, 'en-US', 'Temperature & Humidity Sensor', 'Supports temperature (-20~80°C) and humidity (0~100% RH) measurement', 1, 0, now(), now()),
      (5, 'en-US', 'Current Meter', 'Measures AC/DC current with 0.5-class accuracy', 2, 0, now(), now()),
      (6, 'en-US', 'Gas Detector', 'Not supported yet; hardware integration planned for Q4 2025', 3, 0, now(), now()),

      -- Order Status
      (7, 'en-US', 'Pending Payment', 'Order placed but not paid; auto-canceled if timeout', 1, 0, now(), now()),
      (8, 'en-US', 'Paid', 'Payment successful; awaiting shipment', 2, 0, now(), now()),
      (9, 'en-US', 'Shipped', 'Item has left warehouse; in transit', 3, 0, now(), now()),
      (10, 'en-US', 'Completed', 'User confirmed receipt; order closed', 4, 0, now(), now()),
      (11, 'en-US', 'Canceled', 'Order canceled by user or system', 5, 0, now(), now()),

      -- Gender
      (12, 'en-US', 'Male', '', 1, 0, now(), now()),
      (13, 'en-US', 'Female', '', 2, 0, now(), now()),
      (14, 'en-US', 'Unknown', 'Default value when user does not specify', 3, 0, now(), now()),

      -- Payment Method
      (15, 'en-US', 'Alipay', 'Supports Huabei and Yu’ebao', 1, 0, now(), now()),
      (16, 'en-US', 'WeChat Pay', 'Requires WeChat account binding', 2, 0, now(), now()),
      (17, 'en-US', 'UnionPay', 'Supports credit and debit cards', 3, 0, now(), now()),
      (18, 'en-US', 'Cash', 'Offline payment; deprecated as of Jan 2025', 4, 0, now(), now())
;
SELECT setval('sys_dict_entry_i18n_id_seq', (SELECT MAX(id) FROM sys_dict_entry_i18n));

-- ----------------------------
-- 插入 internal_message_categories 站内信分类
-- ----------------------------
INSERT INTO public.internal_message_categories (id, code, name, remark, sort_order, is_enabled, created_at)
VALUES
    -- 订单相关分类（原主分类+子分类平级展示）
    (1, 'order', '订单通知', '包含订单支付、发货、退款等全流程通知', 1, true, NOW()),
    (101, 'order_paid', '支付成功', '订单支付完成时触发的通知', 2, true, NOW()),
    (102, 'order_unpaid', '支付超时', '订单未在规定时间内支付的提醒', 3, true, NOW()),
    (103, 'order_shipped', '已发货', '商家发货后通知用户', 4, true, NOW()),
    (104, 'order_refunded', '已退款', '订单退款流程完成的通知', 5, true, NOW()),

    -- 系统相关分类
    (2, 'system', '系统通知', '系统公告、维护提醒、版本更新等平台级通知', 6, true, NOW()),
    (201, 'system_announcement', '系统公告', '平台规则更新、重要通知等', 7, true, NOW()),
    (202, 'system_maintenance', '维护通知', '系统计划内维护的时间提醒', 8, true, NOW()),
    (203, 'system_upgrade', '版本更新', '客户端或功能升级的提示', 9, true, NOW()),

    -- 活动相关分类
    (3, 'activity', '活动通知', '营销活动报名、开始、结束等提醒', 10, true, NOW()),
    (301, 'activity_signup', '报名成功', '用户报名活动后确认通知', 11, true, NOW()),
    (302, 'activity_start', '活动开始', '活动即将开始的倒计时提醒', 12, true, NOW()),
    (303, 'activity_end', '活动结束', '活动结束及结果公示通知', 13, true, NOW()),

    -- 用户相关分类
    (4, 'user', '用户通知', '账号安全、信息变更、权限调整等个人相关通知', 14, true, NOW()),
    (401, 'user_login_abnormal', '异地登录', '账号在陌生设备登录的安全提醒', 15, true, NOW()),
    (402, 'user_profile_updated', '资料变更', '用户手机号、邮箱等信息修改后通知', 16, true, NOW()),
    (403, 'user_permission_changed', '权限变更', '账号角色或功能权限调整通知', 17, true, NOW())
;
SELECT setval('internal_message_categories_id_seq', (SELECT MAX(id) FROM internal_message_categories));

-- ----------------------------
-- 看板域演示数据：看板/列/卡片/标签及卡片-标签关联
-- 仅用于本地联调与功能演示。rank 为 Lexorank 字典序字符串（base-36，
-- 字符表 0-9a-z），此处用单字符并拉开间隔，使后续 Between 插入有空间、
-- 不立即触发 rebalance。列 color 不参与当前 UI 渲染，留 NULL。
-- ----------------------------
TRUNCATE TABLE public.sys_kanban_boards,
               public.sys_kanban_columns,
               public.sys_kanban_cards,
               public.sys_kanban_labels,
               public.sys_kanban_card_labels
RESTART IDENTITY CASCADE;

-- 看板（tenant_id = 1）
INSERT INTO public.sys_kanban_boards (id, tenant_id, name, description, rank, created_at, updated_at)
VALUES
    (1, 1, '新产品研发看板', '研发一部新能源车型配套软件的迭代看板，按敏捷 Sprint 推进。', 'a', now(), now()),
    (2, 1, '市场推广活动看板', '市场部线上线下推广活动的策划、执行与复盘跟踪。', 'k', now(), now())
;
SELECT setval('sys_kanban_boards_id_seq', (SELECT MAX(id) FROM sys_kanban_boards));

-- 看板列
INSERT INTO public.sys_kanban_columns (id, tenant_id, board_id, name, rank, created_at, updated_at)
VALUES
    (1, 1, 1, '待办', 'a', now(), now()),
    (2, 1, 1, '进行中', 'k', now(), now()),
    (3, 1, 1, '已完成', 'u', now(), now()),
    (4, 1, 2, '策划中', 'a', now(), now()),
    (5, 1, 2, '执行中', 'k', now(), now()),
    (6, 1, 2, '已结束', 'u', now(), now())
;
SELECT setval('sys_kanban_columns_id_seq', (SELECT MAX(id) FROM sys_kanban_columns));

-- 卡片
INSERT INTO public.sys_kanban_cards (id, tenant_id, board_id, column_id, name, description, rank, created_at, updated_at)
VALUES
    (1, 1, 1, 1, '设计用户登录鉴权流程', '梳理 OAuth2 与短信验证码登录的合并方案，输出时序图与接口契约。', 'a', now(), now()),
    (2, 1, 1, 1, '数据库表结构评审', '对 sys_kanban_* 表的索引、外键与级联策略做一轮评审，产出优化清单。', 'k', now(), now()),
    (3, 1, 1, 1, '前端组件库接入评估', '评估自研表单组件替换 antd 的可行性，输出迁移成本矩阵。', 'u', now(), now()),
    (4, 1, 1, 2, 'WebSocket 实时推送联调', '看板拖拽的实时同步，调试一次性 ticket 握手与断线重连。', 'a', now(), now()),
    (5, 1, 1, 2, '乐观锁并发冲突修复', 'version 字段在多端并发编辑场景下的重试与回退策略。', 'k', now(), now()),
    (6, 1, 1, 3, 'RBAC 权限种子初始化', '租户管理员角色绑定看板域 13 个 API，修复新部署首启全员 403。', 'a', now(), now()),
    (7, 1, 1, 3, 'Flutter 看板移动端适配', '响应式布局在窄屏下的列折叠与拖拽手势适配。', 'k', now(), now()),
    (8, 1, 2, 4, 'Q3 新能源车型发布预热方案', '规划发布前两周的媒体矩阵与话题节奏。', 'a', now(), now()),
    (9, 1, 2, 4, '线下快闪店选址评估', '一线城市商圈人流量与成本测算。', 'k', now(), now()),
    (10, 1, 2, 5, '社交媒体投放素材制作', '短视频与信息流图文素材的批量产出。', 'k', now(), now()),
    (11, 1, 2, 6, '618 大促复盘报告', '汇总各渠道 GMV、ROI 与转化漏斗。', 'k', now(), now())
;
SELECT setval('sys_kanban_cards_id_seq', (SELECT MAX(id) FROM sys_kanban_cards));

-- 看板标签（label 表无 rank 列；color 取前端 _parseColor 命名色以便正确渲染）
INSERT INTO public.sys_kanban_labels (id, tenant_id, board_id, name, color, created_at, updated_at)
VALUES
    (1, 1, 1, '功能需求', 'blue', now(), now()),
    (2, 1, 1, '缺陷', 'red', now(), now()),
    (3, 1, 1, '紧急', 'orange', now(), now()),
    (4, 1, 1, '文档', 'gray', now(), now()),
    (5, 1, 2, '推广活动', 'purple', now(), now()),
    (6, 1, 2, '内容素材', 'green', now(), now())
;
SELECT setval('sys_kanban_labels_id_seq', (SELECT MAX(id) FROM sys_kanban_labels));

-- 卡片-标签关联（card_label 表无 tenant_id 列）
INSERT INTO public.sys_kanban_card_labels (card_id, label_id, created_at, updated_at)
VALUES
    (1, 1, now(), now()),
    (1, 4, now(), now()),
    (3, 2, now(), now()),
    (4, 3, now(), now()),
    (8, 5, now(), now()),
    (8, 6, now(), now()),
    (9, 5, now(), now())
;
SELECT setval('sys_kanban_card_labels_id_seq', (SELECT MAX(id) FROM sys_kanban_card_labels));

-- ----------------------------
-- 看板域 RBAC 种子：为租户管理员角色绑定看板相关权限
-- 没有这段，新部署环境首次启动全员 403（角色无任何权限绑定）。
-- ----------------------------

-- 角色 2 (template:tenant:manager) ← 权限 3 (sys:tenant_manager)
-- 权限 3 已通过 sys_permission_apis 覆盖 board/column/card/label 域的 13 个 API。
INSERT INTO public.sys_role_permissions (tenant_id, role_id, permission_id, created_at)
SELECT 1, r.id, p.id, now()
FROM public.sys_roles r, public.sys_permissions p
WHERE r.code = 'template:tenant:manager' AND p.code = 'sys:tenant_manager'
ON CONFLICT DO NOTHING;

-- 系统用户 2 (tenant_admin, 属租户 1) ← 角色 2 (template:tenant:manager)
INSERT INTO public.sys_user_roles (tenant_id, user_id, role_id, created_at)
SELECT 1, u.id, r.id, now()
FROM public.sys_users u, public.sys_roles r
WHERE u.username = 'tenant_admin' AND r.code = 'template:tenant:manager'
ON CONFLICT DO NOTHING;

COMMIT;
