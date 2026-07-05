# FiscalShieldAI 财智哨兵

> 🛡️ 地方财政风险智能预警系统 — 中国高校计算机大赛 · AIGC创新赛 · 应用赛道复赛作品

<p align="center">
  <img src="app/android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png" width="120" alt="Logo">
</p>

## 📋 项目简介

「财智哨兵」是一款面向**政务部门、企业机构、社会公众**三类用户的一体化智能财政风险预警系统。采用「**vivo蓝心大模型 + ST-GNN/LightTCN小模型**」双引擎架构，以全链路AIGC技术重构财政风险识别、分析与决策流程。

**核心亮点：**
- 🧠 **双引擎**：小模型0.2ms极速推理 + 大模型自然语言报告生成
- 🎯 **三角色**：政务版/企业版/民用版一键切换，功能自动适配
- 👥 **机构管理**：企业/政务机构注册 → 管理员派生成员 → 权限分级
- 🔐 **权限系统**：公开/内部互斥 + 训练回流附加选项 + 公民只看公开数据
- 📊 **知识蒸馏**：118K参数 → 2K参数，压缩59倍，准确率100%
- 📦 **数据管道**：智能字段映射 → 4维质量评分 → 可信度加权入库
- 💬 **AI对话**：自动注入城市多年数据，支持跨年份追问
- 🔄 **网络自适应**：设置页可动态修改后端地址，换网无压力
- 🛡️ **容错机制**：网络请求自动重试，APP生命周期管理
- 📱 **多端支持**：Android手机/平板 + Web端

---

## 🚀 本地复现指南

> **说明**：本项目无需云服务器，所有功能可在本地电脑上完整运行。以下是在 Windows 环境下的复现步骤。

### 环境要求

| 组件 | 最低版本 | 说明 |
|------|----------|------|
| Python | 3.10+ | 后端运行 |
| Flutter SDK | 3.44+ | 前端编译 |
| Android SDK | API 34+ | 移动端编译 |
| Git | 2.x | 克隆代码 |

### 第一步：克隆代码

```bash
git clone https://github.com/Yang070805/FiscalShieldAI.git
cd FiscalShieldAI
```

### 第二步：启动后端

```bash
cd backend
pip install -r requirements.txt
python main.py
```

后端启动后：
- API 服务：`http://localhost:8000`
- Swagger 文档：`http://localhost:8000/docs`

### 第三步：配置 LLM（可选）

1. 启动前端（第四步）
2. 打开 APP → 设置 → AI 模配 → 模型配置
3. 选择 Provider → 填入 API Key → 测试连接

### 第四步：启动前端

```bash
cd app
flutter pub get
flutter run -d <设备ID>
```

**真机调试：**
1. 手机开启 USB 调试
2. USB 连接电脑
3. `flutter devices` 确认设备
4. `flutter run -d <设备ID>`

**注意：** 真机需要修改 `lib/services/api_service.dart` 中的 `_baseUrl` 为电脑局域网 IP。

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────┐
│                    前端 Flutter                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ 政务版    │  │ 企业版    │  │ 民用版    │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       └──────────────┼──────────────┘                │
│                      ▼                               │
│              HTTP API (JWT认证)                       │
└──────────────────────┬──────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────┐
│                 后端 FastAPI                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ 认证模块  │  │ 预测引擎  │  │ LLM对话  │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ 数据管道  │  │ 风险监控  │  │ 训练回流  │          │
│  └──────────┘  └──────────┘  └──────────┘          │
└──────────────────────┬──────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────┐
│                   AI 引擎层                          │
│  ┌─────────────────┐  ┌────────────────────────┐    │
│  │ 小模型 (本地)    │  │ 大模型 (云端API)         │    │
│  │ ST-GNN→LightTCN │  │ vivo蓝心/DeepSeek/Qwen  │    │
│  │ 2K参数 0.2ms    │  │ 报告生成+智能问答        │    │
│  └─────────────────┘  └────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

---

## 📦 数据回流管道（核心创新）

### 处理流程

```
用户上传 Excel/CSV
    ↓
[1] 字段映射（FuzzyWuzzy模糊匹配）
    ├─ 同义词表：负债率 ↔ 负债比率 ↔ debt_ratio
    ├─ 三级匹配：精确→子串→模糊（>80%阈值）
    ↓
[2] Schema验证（类型+范围+空值+唯一性）
    ↓
[3] 数据清洗（13种规则）
    ├─ 基础清洗：trim/lowercase/type_cast
    ├─ 缺失值：fill_null（mean/median/mode）
    ├─ 异常值：fix_categorical_outliers
    └─ 类型修复：自动推断数值列
    ↓
[4] 去重引擎（多级阻塞+模糊匹配）
    ├─ 阻塞索引：O(n*k)复杂度
    ├─ 早期终止：相似度<50%跳过
    ↓
[5] 时间序列预处理（tsmoothie）
    ├─ 平滑：移动平均滤波
    ├─ 异常检测：3σ法则
    └─ 缺失值插值：线性插值
    ↓
[6] 多维质量评分（4维加权）
    ├─ 完整性 35%
    ├─ 唯一性 25%
    ├─ 一致性 25%
    └─ 有效性 15%
    ↓
[7] 可信度加权（质量评分→训练权重）
    ├─ 政务数据 +15% 加成
    ├─ 内部数据 +5% 加成
    ├─ 公开+训练 +3% 加成
    ├─ 内部+训练 +8% 加成
    ├─ 验证错误 -2%/个
    ↓
[8] 入库 + 可选触发增量训练
```

### 性能基准

| 指标 | 数值 |
|------|------|
| 数据管道吞吐量 | 28,173行/秒 |
| 去重性能(1000行) | 18ms |
| 模型推理(缓存后) | 0.21ms |
| 内存使用 | 319MB |

### API接口

| 端点 | 方法 | 功能 |
|------|------|------|
| `/pipeline/upload` | POST | 带完整管道的数据上传 |
| `/pipeline/validate` | POST | 仅验证文件（不入库） |
| `/pipeline/contract` | GET | 获取数据契约 |
| `/pipeline/quality-report` | GET | 获取质量报告 |

---

## 🎯 核心功能

### 三角色系统

| 角色 | 功能 | 账号体系 | 安全策略 |
|------|------|----------|----------|
| 🏛️ **政务版** | 上传数据+预测+报告+监控+训练回流 | 机构注册→管理员派生成员 | 机构内数据共享，公民只看公开 |
| 🏢 **企业版** | 上传数据+预测+报告 | 企业注册→管理员派生成员 | 企业间数据隔离，权限分级 |
| 👤 **民用版** | 查看公开数据+搜索+收藏 | 个人注册 | 只能看permission=public的数据 |

### 权限模型

```
上传数据时选择权限：
├── 公开（public）         → 民用端可查看
├── 内部（internal）       → 仅政务/企业端可见
├── 公开+训练回流           → 公开 + 数据进入训练pipeline
└── 内部+训练回流           → 内部 + 数据进入训练pipeline

查询时自动过滤：
├── 民用端 → 只看 permission=public
└── 政务/企业端 → 看所有权限数据
```

### 机构管理

```
企业/政务注册（管理员）
├── 创建机构 + 绑定管理员
├── 管理员创建成员账号
└── 管理员可删除/重置成员

成员登录后：
├── 管理员 → 底部导航多「管理」tab
└── 普通成员 → 只有基础功能
```

### AI 能力

| 功能 | 技术方案 | 说明 |
|------|----------|------|
| 📊 财政预测 | LightTCN (2K参数) | CPU 0.2ms，双任务100%准确率 |
| 📝 AI报告 | vivo蓝心/DeepSeek/Qwen | 三Tier策略：云API→本地模板→降级 |
| 💬 智能对话 | 多Provider SSE流式 | 支持7家大模型，自动注入城市多年数据 |
| ⚠️ 风险监控 | 阈值+趋势异常检测 | 赤字率/债务率/负债率自动扫描 |
| 🔄 训练回流 | 自动pipeline | public+training/internal+training → 增量训练 |
| 📁 数据上传 | 智能管道 | 字段映射→验证→清洗→去重→评分→入库 |

---

## 🧠 AI 模型详情

### 小模型：知识蒸馏

```
教师模型 ST-GNN (118,341参数)
    ↓ 知识蒸馏 (温度T=3.0)
学生模型 LightTCN (2,026参数, 8KB)
    → CPU推理: 0.21ms
    → 双任务准确率: 100%
```

| 指标 | 教师(ST-GNN) | 学生(LightTCN) |
|------|-------------|----------------|
| 参数量 | 118,341 | 2,026 (8KB) |
| CPU推理耗时 | ~50-100ms | **0.21ms** |
| 财政风险准确率 | 100% | 100% |
| 金融风险准确率 | 100% | 100% |

### 陌生城市兜底

对于没有历史数据的城市，系统自动使用5城均值作为输入，让模型推理，返回带说明的预测结果。

---

## 📁 项目结构

```
FiscalShieldAI/
├── ai_engine/                    # AI引擎
│   ├── train_compact.py          # LightTCN训练
│   ├── inference.py              # 推理接口
│   ├── data/                     # 5城市数据
│   └── checkpoints/              # 模型权重
├── backend/                      # FastAPI后端
│   ├── api/v1/endpoints/         # 10个API模块
│   ├── services/
│   │   ├── data_pipeline/        # 数据回流管道
│   │   │   ├── core.py           # 管道编排器
│   │   │   ├── mapping/          # 字段映射
│   │   │   ├── validation/       # Schema验证
│   │   │   ├── cleaning/         # 数据清洗
│   │   │   ├── quality/          # 质量评分
│   │   │   ├── dedup/            # 去重引擎
│   │   │   └── timeseries/       # 时间序列预处理
│   │   ├── training_pipeline.py  # 训练回流
│   │   └── risk_monitor.py       # 风险监控
│   └── tests/                    # 测试套件
├── app/                          # Flutter前端
│   ├── lib/screens/              # 16个页面
│   │   ├── enterprise_admin_tab.dart  # 机构管理（企业/政务）
│   │   └── ...
│   └── lib/services/             # API服务
└── README.md
```

---

## 🔧 API 接口（43个）

### 认证（4个）
- `POST /api/v1/auth/register` — 注册
- `POST /api/v1/auth/login` — 登录
- `GET /api/v1/auth/me` — 当前用户
- `PUT /api/v1/auth/password` — 改密

### 预测（2个）
- `GET /api/v1/predict/cities` — 城市列表
- `GET /api/v1/predict/{city}` — 城市预测（支持陌生城市兜底）

### 报告（1个）
- `GET /api/v1/report/{city}` — AI分析报告

### 对话（4个，SSE流式）
- `POST /api/v1/chat` — AI对话
- `GET /api/v1/chat/list` — 对话列表
- `GET /api/v1/chat/{id}` — 对话详情
- `DELETE /api/v1/chat/{id}` — 删除对话

### 搜索/收藏（5个）
- `GET /api/v1/search?q=` — 搜索
- `POST /api/v1/search/favorite/{city}` — 收藏
- `DELETE /api/v1/search/favorite/{city}` — 取消收藏
- `GET /api/v1/search/favorites` — 收藏列表
- `GET /api/v1/search/recommend` — 推荐

### 数据上传（6个）
- `POST /api/v1/upload/preview` — 文件预览
- `POST /api/v1/upload/confirm` — 确认入库
- `GET /api/v1/upload/history` — 上传历史
- `GET /api/v1/upload/public-data` — 公开数据
- `GET /api/v1/upload/training-data` — 训练数据
- `GET /api/v1/upload/city-stats` — 城市统计

### 数据管道（4个）
- `POST /api/v1/pipeline/upload` — 带管道的数据上传
- `POST /api/v1/pipeline/validate` — 仅验证文件
- `GET /api/v1/pipeline/contract` — 数据契约
- `GET /api/v1/pipeline/quality-report` — 质量报告

### 训练/监控（6个）
- `POST /api/v1/training/start` — 触发训练
- `GET /api/v1/training/status` — 训练状态
- `GET /api/v1/training/history` — 训练历史
- `GET /api/v1/monitor/scan` — 风险扫描
- `GET /api/v1/monitor/alerts` — 告警列表
- `GET /api/v1/monitor/overview` — 监控概览

### LLM配置（4个）
- `POST /api/v1/llm/set-api-key` — 设置API Key
- `GET /api/v1/llm/providers` — Provider列表
- `GET /api/v1/llm/api-key-status` — API Key状态
- `GET /api/v1/llm/test-connection` — 测试连接

### 企业/政务机构（7个）
- `POST /api/v1/enterprise/register` — 机构注册（创建管理员）
- `GET /api/v1/enterprise/info` — 获取机构信息
- `POST /api/v1/enterprise/member/create` — 创建成员
- `GET /api/v1/enterprise/member/list` — 成员列表
- `DELETE /api/v1/enterprise/member/{id}` — 删除成员
- `POST /api/v1/enterprise/member/{id}/reset-password` — 重置成员密码
- `POST /api/v1/enterprise/transfer-admin` — 转让管理员

---

## 👥 团队

| 成员 | 学校 | 负责 |
|------|------|------|
| 杨文宇（队长）| 南开大学 | 模型训练、全栈开发、策划方案 |
| 金紫茹 | 南京审计大学 | 数据收集、产品设计 |
| 周泠亦 | 北京航空航天大学 | UI设计、前端开发 |
| 伍奕行 | 四川农业大学 | 后端开发 |

## 📜 比赛信息

- **赛事**：中国高校计算机大赛 · AIGC创新赛 · 应用赛道
- **阶段**：复赛
- **团队**：泥很航事堆布队
- **数据基础**：苏南五市（南京/苏州/无锡/常州/镇江）2006-2025年财政金融数据

## 📄 License

MIT License

---

*Built with ❤️ by 泥很航事堆布队*
