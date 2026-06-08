# FiscalShieldAI 接口协议 v1.0

> Qt前端 ↔ Python后端 通信协议（TCP Socket，端口 9527）
>
> 最后更新：2026-06-08

---

## 一、通信方式

- **协议**：TCP Socket
- **地址**：`127.0.0.1:9527`
- **格式**：JSON（UTF-8 编码）
- **流程**：Qt 发送 JSON 请求 → Python 返回 JSON 响应

### 请求格式
```json
{
    "action": "接口名",
    ...其他参数
}
```

### 响应格式
```json
{
    "status": "ok" 或 "error",
    ...返回数据
}
```

---

## 二、接口列表

### 1. health — 健康检查

**用途**：测试后端服务是否正常运行

**请求：**
```json
{
    "action": "health"
}
```

**响应：**
```json
{
    "status": "ok",
    "timestamp": "2026-06-08T16:00:00",
    "server": "FiscalShield AI Bridge v1.0",
    "python_version": "3.12.0",
    "models_loaded": {
        "predictor": true,
        "report_generator": true
    }
}
```

---

### 2. predict_by_city — 便捷城市预测 ⭐推荐

**用途**：传城市名+年份，自动加载数据并预测

**请求：**
```json
{
    "action": "predict_by_city",
    "city": "南京",
    "year": 2026,
    "report": false
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| city | string | ✅ | 城市名称 |
| year | int | ✅ | 预测年份 |
| report | bool | ❌ | 是否生成大模型报告，默认false |

**响应（成功）：**
```json
{
    "status": "ok",
    "city": "南京",
    "year": 2026,
    "source": "model",
    "data_years": [2023, 2024, 2025],
    "fiscal_risk": {
        "level": "中等偏低",
        "level_index": 1,
        "confidence": 0.72,
        "probability_distribution": [0.05, 0.72, 0.20, 0.03, 0.00]
    },
    "finance_risk": {
        "level": "低风险",
        "level_index": 0,
        "confidence": 0.85,
        "probability_distribution": [0.85, 0.12, 0.03, 0.00, 0.00]
    },
    "overall_risk": {
        "level": "中等偏低",
        "level_index": 1,
        "confidence": 0.72
    },
    "warning": {
        "level": "蓝色预警",
        "color": "#8BC34A",
        "message": "ℹ️ 蓝色预警！检测到中等偏低风险（置信度72.0%），定期监测。",
        "threshold_met": true
    },
    "metrics": {
        "负债率(%)": 15.1,
        "债务率(%)": 71.0,
        "赤字率(%)": 2.8,
        "现金短期债务比": 1.07,
        "短期债务占比(%)": 25.8,
        "存贷比(%)": 99.3,
        "不良贷款率(%)": 0.80,
        "拨备覆盖率(%)": 330.0,
        "资本充足率(%)": 16.9
    },
    "explanation": "【财政风险分析】\n等级：中等偏低...",
    "performance": {
        "inference_time_ms": 6.2,
        "device": "cpu"
    }
}
```

**响应（成功+报告）：**
```json
{
    "status": "ok",
    ...（同上）,
    "ai_report": "### 📊 风险概况\n...",
    "report_generator": "bluelm"
}
```

**响应（城市无数据）：**
```json
{
    "status": "error",
    "message": "未找到 某某城市 的历史数据文件，请使用 predict_custom 接口传入指标数据",
    "available_cities": ["南京", "常州", "无锡", "苏州", "镇江"],
    "hint": "可用 predict_custom 传入9个指标值进行预测"
}
```

---

### 3. predict_batch — 批量预测

**用途**：一次预测多个城市

**请求：**
```json
{
    "action": "predict_batch",
    "cities": ["南京", "苏州", "无锡"],
    "year": 2026,
    "report": false
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| cities | string[] | ✅ | 城市名称列表 |
| year | int | ✅ | 预测年份 |
| report | bool | ❌ | 是否生成报告 |

**响应：**
```json
{
    "status": "ok",
    "count": 3,
    "success_count": 3,
    "fail_count": 0,
    "results": [
        { "status": "ok", "city": "南京", ... },
        { "status": "ok", "city": "苏州", ... },
        { "status": "ok", "city": "无锡", ... }
    ]
}
```

---

### 4. predict_custom — 自定义指标预测

**用途**：用户手动输入9个指标值进行预测（适用于无历史数据的新城市）

**请求：**
```json
{
    "action": "predict_custom",
    "city": "自定义城市",
    "year": 2026,
    "indicators": {
        "负债率": 45.0,
        "债务率": 120.0,
        "赤字率": 3.2,
        "现金短期债务比": 0.9,
        "短期债务占比": 28.0,
        "存贷比": 95.0,
        "不良贷款率": 1.5,
        "拨备覆盖率": 180.0,
        "资本充足率": 12.0
    }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| city | string | ✅ | 城市名称（任意） |
| year | int | ✅ | 预测年份 |
| indicators | object | ✅ | 9个指标值 |

**9个指标说明：**

| 指标名 | 类型 | 安全线 | 说明 |
|--------|------|--------|------|
| 负债率 | float | < 60% | 政府负债/GDP |
| 债务率 | float | < 100% | 债务/综合财力 |
| 赤字率 | float | < 3% | 财政赤字/GDP |
| 现金短期债务比 | float | > 1.0 | 现金/短期债务 |
| 短期债务占比 | float | < 30% | 短期债务/总债务 |
| 存贷比 | float | < 100% | 贷款/存款 |
| 不良贷款率 | float | < 2% | 不良贷款/总贷款 |
| 拨备覆盖率 | float | > 150% | 拨备/不良贷款 |
| 资本充足率 | float | > 10.5% | 资本/风险资产 |

**响应：** 同 `predict_by_city` 格式

---

### 5. report — 生成大模型报告

**用途**：对已有预测结果调用蓝心大模型生成分析报告

**请求：**
```json
{
    "action": "report",
    "prediction": {
        "city": "南京",
        "year": 2026,
        "fiscal_risk": { ... },
        "metrics": { ... }
    }
}
```

**响应：**
```json
{
    "status": "ok",
    "report": "### 📊 风险概况\n...",
    "generator": "bluelm",
    "timestamp": "2026-06-08T16:00:00"
}
```

---

### 6. models — 模型信息

**用途**：查看当前加载的模型状态

**请求：**
```json
{
    "action": "models"
}
```

**响应：**
```json
{
    "status": "ok",
    "models": {
        "predictor": {
            "loaded": true,
            "type": "RiskPredictor",
            "device": "cpu"
        },
        "report_generator": {
            "loaded": true,
            "type": "ReportGenerator",
            "api_configured": true
        }
    }
}
```

---

## 三、风险等级说明

| 等级 | index | 颜色 | 预警级别 |
|------|-------|------|----------|
| 低风险 | 0 | #4CAF50 (绿) | ✅ 正常 |
| 中等偏低 | 1 | #8BC34A (浅绿) | 🔵 蓝色预警 |
| 中等 | 2 | #FFEB3B (黄) | 🟡 黄色预警 |
| 中等偏高 | 3 | #FF9800 (橙) | 🟠 橙色预警 |
| 高风险 | 4 | #F44336 (红) | 🔴 红色预警 |

---

## 四、可用城市列表

目前支持直接预测的城市（有历史数据）：

| 城市 | 数据范围 | 文件 |
|------|---------|------|
| 南京 | 2006-2025 | 南京_data.xlsx |
| 苏州 | 2006-2025 | 苏州_data.xlsx |
| 无锡 | 2006-2025 | 无锡_data.xlsx |
| 常州 | 2006-2025 | 常州_data.xlsx |
| 镇江 | 2006-2025 | 镇江_data.xlsx |

其他城市：使用 `predict_custom` 接口手动输入指标。

---

## 五、Qt前端调用示例

```cpp
// 1. 连接后端
QTcpSocket socket;
socket.connectToHost("127.0.0.1", 9527);

// 2. 发送预测请求
QJsonObject request;
request["action"] = "predict_by_city";
request["city"] = "南京";
request["year"] = 2026;
request["report"] = true;

QJsonDocument doc(request);
socket.write(doc.toJson());
socket.waitForBytesWritten(1000);

// 3. 读取响应
socket.waitForReadyRead(5000);
QByteArray response = socket.readAll();
QJsonDocument responseDoc = QJsonDocument::fromJson(response);
QJsonObject result = responseDoc.object();

// 4. 使用结果
QString riskLevel = result["overall_risk"].toObject()["level"].toString();
double confidence = result["overall_risk"].toObject()["confidence"].toDouble();
```

---

## 六、错误码

| status | 含义 | 处理建议 |
|--------|------|---------|
| ok | 成功 | 正常处理数据 |
| error | 失败 | 显示 message 字段的错误信息 |

常见错误：
- `缺少 city 字段` → 检查请求JSON
- `未找到 xxx 的历史数据文件` → 使用 predict_custom 或检查城市名
- `数据不足3年` → 该城市数据不够，无法预测
- `模型未加载` → 后端启动失败，检查模型文件路径
