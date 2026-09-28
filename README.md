# 生活助手（LifeKit / ToDoKits）

一个面向个人生活的多功能应用：**待办管理、完成统计、名言警句、读后感、好习惯、电子日记**。前后端分离，后端使用数据库持久化，前端所有数据支持一键导出下载。

> **当前进度**：静态预览已定稿（v1 暖纸色）；**FrontEnd Vue 工程已建成并可测试**；**BackEnd .NET 工程已建成并编译通过**（运行需本地 PostgreSQL）；前后端已各自初始化 Git 仓库并以子模块纳入本仓库；已写好 GitHub Actions 打包工作流（推送 GitHub 后打 tag 即自动出可运行版本）；Android 应用为后续计划（本机无 Java/Android SDK，暂交付方案说明）。

## 技术栈

| 层 | 技术 | 说明 |
|---|---|---|
| 前端 | Vue 3 + Element Plus（最新）+ Vue Router + Pinia | 图表用 ECharts；深/浅主题；多尺寸响应式 |
| 后端 | .NET 10 + ASP.NET Core Web API | Autofac 属性注入（无需构造函数赋值）、Serilog 日志 |
| 数据库 | PostgreSQL + SqlSugar ORM | CodeFirst 自动建表 |
| 交付 | README + 变更记录 | 每次改动同步更新本文件 |

## 功能清单

| 模块 | 关键能力 |
|---|---|
| 待办事项 | 属性：所属类别（可新增/删除）、开始时间（默认=创建时间，可改）、预计完成时间、完成状态、超期天数；按状态/类别筛选；增删改查；周期重复（每天/每周/每月/每年）；一周记录，本周完成事项单独呈现；勾选框未点击时为空心正方形 |
| 数据统计 | 指定时间范围统计（日期区间选择，某一天=起止同日）；「今天/本周/本月/今年」快捷按钮；环形图=类别占比、堆叠柱状图=趋势（按范围自动切 按日/按月/按年）、类别明细表 |
| 名言警句 | 内容、作者、来源、标签；标签筛选、搜索 |
| 读后感 | 以文件夹组织，文件夹下创建笔记记录读后感；支持新建文件夹/笔记 |
| 好习惯 | 名称、类别（独立维护，与待办分开）、目标、提醒时间；每日打卡、累计连续天数 |
| 电子日记 | 每天写感悟；记录星期几、地点（城市）、天气；按日期归档，编辑/删除 |
| 数据下载 | 各模块及「导出全部数据」，前端一键导出 CSV |

## 架构思路

```
┌────────────── 前端（Vue 3 + Element Plus）──────────────┐
│ views/ 工作台 · 待办 · 统计 · 名言 · 读后感 · 习惯 · 日记 │
│ store/ Pinia（状态 + 导出 + 统计 getters）                │
│ api/   后端 REST 客户端（USE_BACKEND 开关）               │
└─────────────────────┬───────────────────────────────────┘
                      │ REST /api/*
┌─────────────────────▼───────────────────────────────────┐
│ 后端 ToDoKits.Controllers（Web API 入口）                 │
│  Controllers（对外开放接口，Autofac 属性注入服务）         │
├─────────────────────────────────────────────────────────┤
│ ToDoKits.Services（Interfaces / Implements 业务实现）     │
├─────────────────────────────────────────────────────────┤
│ ToDoKits.Models（PostgreSQL 实体 + DTO + 建表）          │
├─────────────────────────────────────────────────────────┤
│ ToDoKits.Command（依赖基座：SqlSugar/Serilog/Autofac 注册、│
│  AppService 属性注入基类、ServiceLocator、CSV 导出辅助）  │
└─────────────────────┬───────────────────────────────────┘
                      │ SqlSugar ORM
┌─────────────────────▼───────────────────────────────────┐
│ PostgreSQL（todos·categories·habits·quotes·folders·notes·diaries）│
└─────────────────────────────────────────────────────────┘
```

## 目录结构（Git 子模块）

```
ToDoKits/                     # 父仓库（本文件 + 静态预览 + 子模块）
├── README.md
├── 静态预览/
│   └── 个人生活助手-静态预览.html      # 定稿静态原型
├── FrontEnd/                 # 子模块：Vue 前端工程
│   └── src/{views,store,api,router,styles,App.vue,main.js}
└── BackEnd/                  # 子模块：.NET 后端工程
    ├── ToDoKits.Backend.slnx
    ├── ToDoKits.Command/
    ├── ToDoKits.Models/
    ├── ToDoKits.Services/
    └── ToDoKits.Controllers/
```

> 前后端各自独立 Git 仓库，本父仓库以子模块方式管理（见 `.gitmodules`）。

## 后端实体统计（Models）

| 实体 | 表 | 说明 |
|---|---|---|
| Todo | todos | 待办（名称/类别/开始/预计完成/状态/周期/备注/完成时间） |
| TodoCategory / HabitCategory | todo_categories / habit_categories | 待办与习惯两类分类，分开维护 |
| Habit | habits | 好习惯（名称/类别/目标/连续天数/提醒时间/今日打卡） |
| Quote | quotes | 名言（内容/作者/出处/标签/日期） |
| Folder / Note | folders / notes | 读后感文件夹 + 笔记 |
| Diary | diaries | 电子日记（日期/星期/地点/天气/正文） |

## 如何运行

### 前端
```bash
cd FrontEnd
npm install
npm run dev        # http://localhost:5173（Vite，代理 /api → localhost:5000）
npm run build      # 产出 dist/
```

### 后端
```bash
# 1. 准备 PostgreSQL，并创建数据库 todokits
# 2. 在 appsettings.json 的 ConnectionStrings:Default 填入连接串
#    或设置环境变量 ConnectionStrings__Default
cd BackEnd
dotnet restore
dotnet run --project ToDoKits.Controllers   # http://localhost:5000
```
- 后端启动会自动 CodeFirst 建表；`src/api/index.js` 的 `USE_BACKEND` 置 `true` 即接入后端（默认 `false` 本地内存，便于单独跑前端）。
- 后端同时托管 `FrontEnd/dist`（若已构建），访问 http://localhost:5000 可直接用完整应用。

## GitHub Actions 打包

工作流位于 `.github/workflows/release.yml`：打 `v*` 标签触发，递归检出子模块 → 构建前端（npm）与后端（dotnet publish，linux/win 自包含）→ 打包成可运行产物并生成 GitHub Release。

> **推送前请先**：① 在 GitHub 分别创建 FrontEnd、BackEnd、ToDoKits 三个仓库；② 给子模块添加远端并推送；③ 将 `.gitmodules` 中的 `url` 改为对应的 GitHub 仓库地址；④ 为本仓库添加远端并推送，再打 tag 触发 CI。

## 变更记录

| 日期 | 变更内容 |
|---|---|
| 2026-09-27 | 新建项目 ToDoKits；依据需求文档撰写 README。 |
| 2026-09-27 | 交付静态预览页 v1（原生 JS 复刻 Element UI 视觉）→ v2（Vue 3 + Element Plus 默认主题）→ v3（深色/抽屉/可点击统计卡/移除本周完成卡）→ 统计支持时间范围（快捷今天/本周/本月/今年 + 自适应粒度）。 |
| 2026-09-27 | 主题经 **Soft UI** 尝试后，定稿为 **v1 暖纸色定制风**（暖纸底 #F6F4EF / 墨绿主色 #2E7D6B / 衬线名言 / 深色暖调）；移动端修复「新建记录」与「读后感新建文件夹」弹窗自适应（640px 断点对话框自适应）。 |
| 2026-09-27 | **FrontEnd 工程完成**：Vue3 + Element Plus + Pinia + ECharts + Vue Router；7 视图（工作台/待办/统计/名言/读后感/习惯/日记）；store 含全部数据与增删改查/周期/导出/主题/统计 getters；api 客户端契约与后端一致（USE_BACKEND 开关）；`npm install`/`npm run build` 通过、dev 服务器验证 HTTP 200。 |
| 2026-09-27 | **BackEnd 工程完成**：`ToDoKits.Backend.slnx`；四个项目 Command（依赖基座：SqlSugar/Serilog/Autofac 注册、AppService 属性注入、ServiceLocator、CSV 导出）/ Models（PostgreSQL 实体 + DTO + DbInitializer 建表）/ Services（Interfaces + Implements）/ Controllers（8 个对外接口 + Program）；Autofac 属性注入（无需构造函数赋值）+ SqlSugar + Serilog；编译 0 警告 0 错误。 |
| 2026-09-27 | **Git 仓库与子模块**：FrontEnd、BackEnd 各自 `git init`；父仓库 ToDoKits 以子模块管理二者（`.gitmodules`）。 |
| 2026-09-27 | **CI 工作流**：参考 NetworkKits release.yml 编写 `.github/workflows/release.yml`（tag 触发 / checkout submodules / 前端 npm build / 后端 dotnet publish linux+win / 打包 Release）。 |
| 2026-09-27 | **Android**：本机无 Java/Android SDK，未本地构建；后续可将前端界面以 WebView 嵌入安卓应用，数据库可选本地 SQLite 或复用后端 API，待接入 Android 工具链后再交付工程。 |
| 2026-09-28 | **FrontEnd 移动端 UI 优化**：顶栏导出改图标（去拥挤）、正文/表单字号加大（≥15/16px 防 iOS 聚焦缩放）、筛选控件堆叠全宽、表格横向滚动不截断；移除侧栏「生活助手」品牌标识。 |
