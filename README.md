# FiscalShieldAI 财智哨兵

> 🛡️ 地方财政风险智能预警系统 — 中国高校计算机大赛 · AIGC创新赛 · 应用赛道复赛作品

<p align="center">
  <img src="app/android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png" width="120" alt="Logo">
</p>

## 📋 项目简介

「财智哨兵」是一款面向**政务部门、企业机构、社会公众**三类用户的一体化智能财政风险预警系统。采用「**vivo蓝心大模型 + ST-GNN/LightTCN小模型**」双引擎架构，以全链路AIGC技术重构财政风险识别、分析与决策流程。

**核心亮点：**
- 🧠 **双引擎**：小模型6.2ms极速推理 + 大模型自然语言报告生成
- 🎯 **三角色**：政务版/企业版/民用版一键切换，功能自动适配
- 📊 **知识蒸馏**：118K参数 → 8K参数，压缩14.3倍，准确率100%
- 🔒 **数据安全**：按角色分级权限，数据不出域
- 📱 **多端支持**：Android手机/平板 + Web端

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────┐
│                    前端 Flutter                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ 政务版    │  │ 企业版    │  │ 民用版    │          │
│  │ 全功能    │  │ 全功能    │  │ 只读+搜索 │          │
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
│  │ JWT+RBAC │  │ AI Engine │  │ SSE流式  │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ 数据上传  │  │ 风险监控  │  │ 训练回流  │          │
│  │ 权限分级  │  │ 异常检测  │  │ 自动pipeline│         │
│  └──────────┘  └──────────┘  └──────────┘          │
└──────────────────────┬──────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────┐
│                   AI 引擎层                          │
│  ┌─────────────────┐  ┌────────────────────────┐    │
│  │ 小模型 (本地)    │  │ 大模型 (云端API)         │    │
│  │ ST-GNN→LightTCN │  │ vivo蓝心/DeepSeek/Qwen  │    │
│  │ 8K参数 6.2ms    │  │ 报告生成+智能问答        │    │
│  └─────────────────┘  └────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 环境要求
- Python 3.10+ (后端)
- Flutter 3.44+ (前端)
- Android SDK / NDK (移动端编译)

### 1. 启动后端
```bash
cd backend
pip install -r requirements.txt
python main.py
# 后端运行在 http://localhost:8000
# Swagger文档: http://localhost:8000/docs
```

### 2. 启动前端
```bash
cd app
flutter pub get
flutter run
# 选择连接的设备（手机/模拟器/平板）
```

### 3. 配置 LLM
1. 打开APP → 设置 → AI模配 → 模型配置
2. 选择 Provider（vivo蓝心/DeepSeek/Qwen等）
3. 填入 API Key → 测试连接
4. 开始对话

## 🎯 核心功能

### 三角色系统

| 角色 | 功能 | 安全策略 |
|------|------|----------|
| 🏛️ **政务版** | 上传数据+预测+报告+监控+训练回流 | 国密加密，数据不出域 |
| 🏢 **企业版** | 上传数据+预测+报告 | 权限分级，操作留痕 |
| 👤 **民用版** | 查看公开数据+搜索+收藏 | 一键清除，隐私保护 |

### AI 能力

| 功能 | 技术方案 | 说明 |
|------|----------|------|
| 📊 财政预测 | LightTCN (8K参数) | CPU 6.2ms，双任务100%准确率 |
| 📝 AI报告 | vivo蓝心/DeepSeek/Qwen | 三Tier策略：云API→本地模板→降级 |
| 💬 智能对话 | 多Provider SSE流式 | 支持7家大模型自由切换 |
| ⚠️ 风险监控 | 阈值+趋势异常检测 | 赤字率/债务率/负债率自动扫描 |
| 🔄 训练回流 | 自动pipeline | private数据 → 增量训练 → 模型更新 |
| 📁 数据上传 | 三级权限 | public/internal/private + 预览确认 |

### 多 Provider 支持

| Provider | 默认模型 | 说明 |
|----------|----------|------|
| vivo蓝心 | Doubao-Seed-2.0-mini | 🏆 比赛官方 |
| DeepSeek | deepseek-chat | 高性价比 |
| 通义千问 | qwen-turbo | 阿里云 |
| 豆包 | doubao-lite-4k | 字节跳动 |
| OpenAI | gpt-4o-mini | GPT-4o |
| Claude | claude-3-5-haiku | 推理能力强 |
| Kimi | moonshot-v1-8k | 长文本 |

## 🧠 AI 模型详情

### 小模型：知识蒸馏

```
教师模型 ST-GNN (118,341参数)
    ↓ 知识蒸馏 (T=3.0, α=0.7, β=0.3)
学生模型 LightTCN (8,293参数, 55KB)
    → CPU推理: 6.2ms
    → 双任务准确率: 100%
```

| 指标 | 教师(ST-GNN) | 学生(LightTCN) |
|------|-------------|----------------|
| 参数量 | 118,341 | 8,293 (55KB) |
| 训练轮次 | 45 Epoch | 100 Epoch |
| 验证集Loss | 0.455 | 0.829 |
| 财政风险准确率 | 100% | 100% |
| 金融风险准确率 | 100% | 100% |
| CPU推理耗时 | ~50-100ms | **6.2ms** |

### 大模型：vivo蓝心

- **API**: `https://api-ai.vivo.com.cn/v1/chat/completions`
- **认证**: `Authorization: Bearer <AppKey>` + `app_id` header
- **流式响应**: SSE格式，支持 `reasoning_content`（思考）+ `content`（回复）
- **降级策略**: 云API → 本地模板 → 规则引擎

## 📁 项目结构

```
FiscalShieldAI/
├── ai_engine/               # AI引擎（模型训练+推理）
│   ├── train_compact.py     # LightTCN学生模型训练
│   ├── train_distill.py     # 知识蒸馏
│   ├── inference.py         # 推理接口
│   ├── bluelm_report.py     # vivo蓝心报告生成
│   └── checkpoints/         # 模型权重
├── backend/                 # FastAPI后端
│   ├── api/v1/endpoints/    # API路由（8个模块）
│   ├── services/            # 业务逻辑
│   │   ├── llm_providers.py # 多Provider配置
│   │   ├── llm_chat.py      # LLM对话（SSE流式）
│   │   ├── training_pipeline.py # 训练回流
│   │   └── risk_monitor.py  # 风险监控
│   ├── models/              # 数据模型（8个）
│   ├── schemas/             # Pydantic验证
│   └── data/api_keys.json   # API Key存储
├── app/                     # Flutter前端
│   ├── lib/
│   │   ├── screens/         # 页面（12个）
│   │   ├── services/        # API服务
│   │   ├── models/          # 数据模型
│   │   └── widgets/         # 通用组件
│   └── android/             # Android配置
└── README.md
```

## 🔧 API 接口

### 认证
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/auth/register` | 注册 |
| POST | `/api/v1/auth/login` | 登录（返回JWT） |
| GET | `/api/v1/auth/me` | 获取当前用户 |
| POST | `/api/v1/auth/change-password` | 修改密码 |

### 预测
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/predict/cities` | 城市列表 |
| GET | `/api/v1/predict/{city}` | 城市预测 |

### 报告
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/report/{city}` | AI分析报告 |

### 对话（SSE流式）
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/chat` | AI对话（SSE） |
| GET | `/api/v1/chat/list` | 对话列表 |
| GET | `/api/v1/chat/{id}` | 对话详情 |

### 搜索/收藏
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/search?q=` | 搜索 |
| POST | `/api/v1/search/favorite/{city}` | 收藏 |
| DELETE | `/api/v1/search/favorite/{city}` | 取消收藏 |
| GET | `/api/v1/search/recommend` | 推荐 |

### 数据上传
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/upload/preview` | 文件预览 |
| POST | `/api/v1/upload/confirm` | 确认入库 |
| GET | `/api/v1/upload/history` | 上传历史 |
| GET | `/api/v1/upload/public-data` | 公开数据 |

### 训练/监控
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/training/start` | 触发训练 |
| GET | `/api/v1/training/status` | 训练状态 |
| GET | `/api/v1/monitor/scan` | 风险扫描 |
| GET | `/api/v1/monitor/alerts` | 告警列表 |

### LLM配置
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/llm/set-api-key` | 设置API Key |
| GET | `/api/v1/llm/providers` | Provider列表 |
| GET | `/api/v1/llm/test-connection` | 测试连接 |

## 👥 团队

| 成员 | 学校 | 负责 |
|------|------|------|
| 杨文宇（队长）| 南开大学 | 模型训练、前端开发、策划方案 |
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
