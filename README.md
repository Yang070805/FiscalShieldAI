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

---

## 🚀 本地复现指南

> **说明**：本项目无需云服务器，所有功能可在本地电脑上完整运行。以下是在 Windows 环境下的复现步骤。

### 环境要求

| 组件 | 最低版本 | 说明 |
|------|----------|------|
| Python | 3.10+ | 后端运行 |
| Flutter SDK | 3.44+ | 前端编译 |
| Android SDK | API 34+ | 移动端编译 |
| Android NDK | 28.x | 模型推理 |
| Git | 2.x | 克隆代码 |

### 第一步：克隆代码

```bash
git clone https://github.com/Yang070805/FiscalShieldAI.git
cd FiscalShieldAI
```

### 第二步：启动后端

```bash
# 进入后端目录
cd backend

# 创建虚拟环境（推荐）
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Linux/Mac

# 安装依赖
pip install -r requirements.txt

# 启动后端服务
python main.py
```

后端启动后：
- API 服务地址：`http://localhost:8000`
- Swagger 文档：`http://localhost:8000/docs`
- 健康检查：`http://localhost:8000/health`

### 第三步：配置 LLM（可选但推荐）

后端支持两种方式配置大模型 API Key：

**方式一：通过前端设置页（推荐）**
1. 先启动前端（第四步）
2. 打开 APP → 设置 → AI 模配 → 模型配置
3. 选择 Provider（如 vivo 蓝心）
4. 填入 API Key → 测试连接

**方式二：通过环境变量**
```bash
# 在 backend 目录下创建 .env 文件
echo "BLUELM_API_KEY=你的AppKey" > .env
echo "DEEPSEEK_API_KEY=你的Key" >> .env
# 其他 Provider 同理
```

**获取 vivo 蓝心 API Key（比赛推荐）：**
1. 访问 https://aigc.vivo.com.cn
2. 注册账号 → 创建应用
3. 获取 AppID 和 AppKey
4. 在前端设置页填入

### 第四步：启动前端

```bash
# 新开一个终端，进入前端目录
cd app

# 安装依赖
flutter pub get

# 查看可用设备
flutter devices

# 启动（选择设备ID）
flutter run -d <设备ID>

# 或者启动 Android 模拟器后
flutter run
```

**真机调试（推荐）：**
1. 手机开启 USB 调试（设置 → 关于手机 → 连点版本号7次 → 开发者选项 → USB调试）
2. USB 连接电脑
3. 手机弹窗点「允许调试」
4. `flutter devices` 确认看到设备
5. `flutter run -d <设备ID>`

**注意事项：**
- 真机需要修改 API 地址：编辑 `lib/main.dart`，将 `10.0.2.2` 改为电脑的局域网 IP
- 查看电脑 IP：`ipconfig`（Windows）或 `ifconfig`（Linux/Mac）
- 手机和电脑必须在同一局域网

### 第五步：测试功能

1. **注册**：打开 APP → 选择角色（政务版/企业版/民用版）→ 输入手机号+密码 → 注册
2. **登录**：输入手机号+密码 → 登录
3. **配置 LLM**：设置 → AI 模配 → 模型配置 → 填入 API Key → 测试连接
4. **预测**：仪表盘 → 选城市+年份 → 点「预测」
5. **对话**：点右下角聊天气泡 → 发消息

### 常见问题

**Q: 后端启动报错 `ModuleNotFoundError`**
```bash
cd backend
pip install -r requirements.txt
```

**Q: 前端编译报错 `SDK location not found`**
```bash
# 设置 Android SDK 路径
export ANDROID_HOME=C:\Users\你的用户名\AppData\Local\Android\Sdk
```

**Q: 真机安装报 `INSTALL_FAILED_USER_RESTRICTED`**
手机设置 → 开发者选项 → 打开「USB 安装」

**Q: LLM 对话无回复**
1. 检查后端是否在运行（`http://localhost:8000/health`）
2. 检查 API Key 是否正确配置
3. 检查手机和电脑是否在同一网络

**Q: Gradle 下载超时**
在 `android/build.gradle.kts` 中添加国内镜像（已配置好）

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
│  │ 数据上传  │  │ 风险监控  │  │ 训练回流  │          │
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

---

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

---

## 🧠 AI 模型详情

### 小模型：知识蒸馏

```
教师模型 ST-GNN (118,341参数)
    ↓ 知识蒸馏 (温度T=3.0, α=0.7, β=0.3)
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

### 大模型：多Provider支持

| Provider | 默认模型 | 说明 |
|----------|----------|------|
| vivo蓝心 | Doubao-Seed-2.0-mini | 🏆 比赛官方 |
| DeepSeek | deepseek-chat | 高性价比 |
| 通义千问 | qwen-turbo | 阿里云 |
| 豆包 | doubao-lite-4k | 字节跳动 |
| OpenAI | gpt-4o-mini | GPT-4o |
| Claude | claude-3-5-haiku | 推理能力强 |
| Kimi | moonshot-v1-8k | 长文本 |

---

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

---

## 🔧 API 接口

### 认证（4个）
- `POST /api/v1/auth/register` — 注册
- `POST /api/v1/auth/login` — 登录（JWT）
- `GET /api/v1/auth/me` — 当前用户
- `POST /api/v1/auth/change-password` — 改密

### 预测（2个）
- `GET /api/v1/predict/cities` — 城市列表
- `GET /api/v1/predict/{city}` — 城市预测

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

### 训练/监控（6个）
- `POST /api/v1/training/start` — 触发训练
- `GET /api/v1/training/status` — 训练状态
- `GET /api/v1/training/history` — 训练历史
- `GET /api/v1/monitor/scan` — 风险扫描
- `GET /api/v1/monitor/alerts` — 告警列表
- `GET /api/v1/monitor/overview` — 监控概览

### LLM配置（3个）
- `POST /api/v1/llm/set-api-key` — 设置API Key
- `GET /api/v1/llm/providers` — Provider列表
- `GET /api/v1/llm/test-connection` — 测试连接

---

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
