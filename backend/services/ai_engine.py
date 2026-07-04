"""
AI 引擎服务层 — 包装 ai_engine 的推理和报告模块
"""

import json
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

import torch

logger = logging.getLogger(__name__)

# 将 ai_engine 目录加入 Python 路径
AI_ENGINE_DIR = Path(__file__).resolve().parent.parent.parent / "ai_engine"
if str(AI_ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(AI_ENGINE_DIR))

# 延迟导入，避免启动时就加载模型
_predictor = None
_available_cities = None


def _get_predictor():
    """延迟加载 RiskPredictor（首次调用时才加载模型）"""
    global _predictor
    if _predictor is None:
        try:
            from inference import RiskPredictor
            model_path = AI_ENGINE_DIR / "checkpoints" / "best_student_model.pth"
            scaler_path = AI_ENGINE_DIR / "checkpoints" / "data_scaler.joblib"
            _predictor = RiskPredictor(
                model_path=str(model_path),
                scaler_path=str(scaler_path) if scaler_path.exists() else None,
                device="cpu",
            )
            print("✅ RiskPredictor 模型加载成功")
        except Exception as e:
            print(f"⚠️ RiskPredictor 加载失败: {e}，将使用模拟数据")
            _predictor = "failed"
    return _predictor


def get_available_cities() -> list[str]:
    """获取可用城市列表"""
    global _available_cities
    if _available_cities is None:
        data_dir = AI_ENGINE_DIR / "data"
        _available_cities = []
        for f in data_dir.glob("*_data.xlsx"):
            city = f.stem.replace("_data", "")
            _available_cities.append(city)
        _available_cities.sort()
    return _available_cities


def _simulated_predict(city: str, year: int) -> dict:
    """模拟预测（模型不可用时的降级方案）"""
    import random
    risk_score = random.uniform(20, 80)
    if risk_score < 30:
        risk_level, trend = "low", "stable"
    elif risk_score < 50:
        risk_level, trend = "medium", "stable"
    elif risk_score < 70:
        risk_level, trend = "high", "rising"
    else:
        risk_level, trend = "critical", "rising"

    return {
        "city": city,
        "year": year,
        "risk_score": round(risk_score, 1),
        "risk_level": risk_level,
        "trend": trend,
        "detail": {
            "fiscal_risk": {"level": risk_level, "confidence": 0.85},
            "finance_risk": {"level": risk_level, "confidence": 0.80},
        },
        "source": "simulated",
    }


def _fallback_predict(city: str, year: int) -> dict:
    """
    陌生城市兜底预测：用5城均值作为输入
    
    对于没有历史数据的城市，使用已知5个城市的平均指标作为输入，
    让模型进行推理。这样至少能给出一个基于模型的预测结果，
    而不是返回错误。
    """
    predictor = _get_predictor()
    
    if predictor == "failed" or predictor is None:
        return _simulated_predict(city, year)
    
    try:
        import pandas as pd
        import numpy as np
        
        # 加载所有城市的平均数据
        data_dir = AI_ENGINE_DIR / "data"
        all_means = []
        
        for f in data_dir.glob("*_data.xlsx"):
            df = pd.read_excel(str(f))
            # 取最近3年的平均值
            numeric_cols = df.select_dtypes(include=[np.number]).columns
            recent = df.tail(3)
            means = recent[numeric_cols].mean()
            all_means.append(means)
        
        if not all_means:
            return _simulated_predict(city, year)
        
        # 计算5城均值
        avg_df = pd.DataFrame(all_means).mean()
        
        # 构造输入数据（模仿真实数据格式）
        # 9个核心指标
        indicators = ['负债率(%)', '债务率(%)', '赤字率(%)', '现金短期债务比', 
                      '短期债务占比(%)', '存贷比(%)', '不良贷款率(%)', '拨备覆盖率(%)', '资本充足率(%)']
        
        # 创建3年窗口（复制3次均值）
        input_data = []
        for _ in range(3):
            row = []
            for ind in indicators:
                if ind in avg_df.index:
                    row.append(float(avg_df[ind]))
                else:
                    row.append(0.0)
            input_data.append(row)
        
        input_tensor = np.array(input_data, dtype=np.float32)
        input_tensor = torch.FloatTensor(input_tensor).unsqueeze(0).to(predictor.device)
        
        # 预测
        with torch.no_grad():
            fiscal_logits, finance_logits = predictor.model(input_tensor)
            
            # 获取预测结果
            fiscal_probs = torch.softmax(fiscal_logits, dim=1)[0]
            finance_probs = torch.softmax(finance_logits, dim=1)[0]
            
            fiscal_level = fiscal_probs.argmax().item()
            finance_level = finance_probs.argmax().item()
            
            # 计算综合风险分数
            fiscal_conf = fiscal_probs[fiscal_level].item()
            finance_conf = finance_probs[finance_level].item()
            overall_conf = (fiscal_conf + finance_conf) / 2
            
            # 转换为风险等级
            level_names = ["低风险", "中等偏低", "中等", "中等偏高", "高风险"]
            fiscal_level_name = level_names[fiscal_level]
            finance_level_name = level_names[finance_level]
            
            # 计算风险评分（0-100）
            risk_score = overall_conf * 100
            
            # 判断趋势
            if fiscal_level >= 3 or finance_level >= 3:
                trend = "rising"
            elif fiscal_level <= 1 and finance_level <= 1:
                trend = "stable"
            else:
                trend = "stable"
            
            return {
                "city": city,
                "year": year,
                "risk_score": round(risk_score, 1),
                "risk_level": _level_to_en(fiscal_level_name),
                "trend": trend,
                "detail": {
                    "fiscal_risk": {
                        "level": fiscal_level_name,
                        "level_index": fiscal_level,
                        "confidence": round(fiscal_conf, 4),
                    },
                    "finance_risk": {
                        "level": finance_level_name,
                        "level_index": finance_level,
                        "confidence": round(finance_conf, 4),
                    },
                    "warning": {
                        "level": "陌生城市",
                        "color": "#FF9800",
                        "message": f"{city}为陌生城市，预测基于5城均值，仅供参考",
                        "threshold_met": False,
                    },
                    "explanation": f"【{city}预测说明】\n该城市不在模型训练数据中，预测基于南京、苏州、无锡、常州、镇江5个城市的平均指标。\n结果仅供参考，如需精确预测，请上传该城市的历史数据。",
                    "data_years": [],
                },
                "source": "fallback",
            }
    except Exception as e:
        logger.error(f"兜底预测失败: {e}", exc_info=True)
        return _simulated_predict(city, year)


def predict_by_city(city: str, year: int) -> dict:
    """
    城市预测接口
    返回: {city, year, risk_score, risk_level, trend, detail, source}
    """
    predictor = _get_predictor()

    # 模型不可用 → 模拟数据
    if predictor == "failed" or predictor is None:
        return _simulated_predict(city, year)

    try:
        import pandas as pd

        data_file = AI_ENGINE_DIR / "data" / f"{city}_data.xlsx"
        if not data_file.exists():
            # 陌生城市：使用5城均值作为兜底输入
            logger.info(f"{city} 无历史数据，使用5城均值兜底")
            return _fallback_predict(city, year)

        df = pd.read_excel(str(data_file))
        available_years = sorted(df["年份"].unique())
        if len(available_years) < 3:
            return {"error": f"{city} 数据不足3年"}

        recent_years = available_years[-3:]
        df_recent = df[df["年份"].isin(recent_years)].copy()

        input_tensor = predictor.preprocess_single_city_data(df_recent, city_name=city)
        result = predictor.predict(input_tensor)

        # 统一输出格式
        overall = result["overall_risk"]
        return {
            "city": city,
            "year": year,
            "risk_score": round(overall["confidence"] * 100, 1),
            "risk_level": _level_to_en(overall["level"]),
            "trend": "rising" if overall["level_index"] >= 3 else "stable",
            "detail": {
                "fiscal_risk": result["fiscal_risk"],
                "finance_risk": result["finance_risk"],
                "warning": result["warning"],
                "explanation": result["explanation"],
                "metrics": result.get("metrics", {}),
                "data_years": result.get("data_years", []),
            },
            "source": "model",
        }
    except Exception as e:
        return _simulated_predict(city, year)


def generate_report(city: str, year: int, role: str = "citizen") -> dict:
    """
    AI 报告生成（三-tier 策略）
    1. 尝试调用 bluelm_report.py（有 API Key 时）
    2. 无 API Key / 调用失败 → 用本地模板 + 数据填充
    返回: {city, year, content, source}
    """
    # 先获取预测数据作为报告输入
    predict_result = predict_by_city(city, year)
    if "error" in predict_result:
        return {"error": predict_result["error"]}

    # Tier 1: 尝试调用蓝心大模型
    try:
        from bluelm_report import ReportGenerator
        gen = ReportGenerator(api_key="")

        report_text = gen.generate_report(predict_result)
        if report_text:
            return {
                "city": city,
                "year": year,
                "content": report_text,
                "source": "bluelm",
            }
    except Exception as e:
        print(f"[ai_engine] bluelm 调用失败: {e}")

    # Tier 2: 本地模板报告
    return _local_report(city, year, predict_result)


def _local_report(city: str, year: int, pred: dict) -> dict:
    """本地模板报告 — 使用 report_template.md + 数据填充"""
    from datetime import datetime
    risk_level = pred.get("risk_level", "unknown")
    risk_score = pred.get("risk_score", 0)
    trend = pred.get("trend", "unknown")
    detail = pred.get("detail", {})

    # 风险等级中文
    level_cn = {
        "low": "低风险",
        "medium": "中等风险",
        "high": "高风险",
        "critical": "极高风险",
    }.get(risk_level, risk_level)

    trend_cn = {
        "rising": "上升",
        "declining": "下降",
        "stable": "稳定",
    }.get(trend, trend)

    # 综合评估
    risk_overview = (
        f"**{city}**当前财政风险等级为**{level_cn}**（评分 {risk_score}/100），"
        f"风险趋势呈{trend_cn}态势。"
    )

    # 核心指标分析
    metrics_lines = []
    if "metrics" in detail:
        for k, v in detail["metrics"].items():
            metrics_lines.append(f"- **{k}**: {v}")
    if "fiscal_risk" in detail:
        fr = detail["fiscal_risk"]
        metrics_lines.append(f"- **财政风险等级**: {fr.get('level', '-')}（置信度 {fr.get('confidence', 0):.1%}）")
    if "finance_risk" in detail:
        fir = detail["finance_risk"]
        metrics_lines.append(f"- **金融风险等级**: {fir.get('level', '-')}（置信度 {fir.get('confidence', 0):.1%}）")
    metrics_analysis = "\n".join(metrics_lines) if metrics_lines else "暂无详细指标数据。"

    # 趋势研判
    trend_analysis = (
        f"基于历史数据和模型预测，{city}财政风险呈{trend_cn}趋势。"
    )
    if trend == "rising":
        trend_analysis += "风险上升需要重点关注相关指标变化，建议加强监控。"
    elif trend == "declining":
        trend_analysis += "风险下降表明当前政策措施效果良好，建议保持现有策略。"
    else:
        trend_analysis += "风险保持稳定，建议持续关注宏观经济环境变化。"

    # 政策建议
    suggestions = {
        "low": [
            "继续保持审慎的财政管理策略",
            "利用当前窗口期推进结构性改革",
            "建立常态化的风险监测机制",
        ],
        "medium": [
            "加强财政与金融数据的联动监测",
            "对高风险领域进行压力测试",
            "适度收紧财政支出，优先保障重点领域",
        ],
        "high": [
            "立即召开财政风险研判会议",
            "严格控制新增政府债务",
            "加快存量债务置换和化解",
            "建立跨部门风险应对机制",
        ],
        "critical": [
            "立即启动财政应急响应机制",
            "暂停非必要的财政支出项目",
            "向上级财政部门报告并寻求支持",
            "制定专项债务化解方案",
            "建立每日风险监测和报告制度",
        ],
    }
    advice_list = suggestions.get(risk_level, suggestions["medium"])
    policy_suggestions = "\n".join(f"{i+1}. {a}" for i, a in enumerate(advice_list))

    # 重点关注
    key_warnings = []
    if risk_score > 70:
        key_warnings.append(f"风险评分 {risk_score} 处于较高水平，需持续监控")
    if trend == "rising":
        key_warnings.append("风险呈上升趋势，建议密切关注")
    if not key_warnings:
        key_warnings.append("当前无特别需要关注的风险点")
    key_warnings_text = "\n".join(f"- {w}" for w in key_warnings)

    # 读取模板并填充
    template_path = Path(__file__).parent.parent / "templates" / "report_template.md"
    try:
        template = template_path.read_text(encoding="utf-8")
        content = template.format(
            city=city,
            year=year,
            risk_overview=risk_overview,
            metrics_analysis=metrics_analysis,
            trend_analysis=trend_analysis,
            policy_suggestions=policy_suggestions,
            key_warnings=key_warnings_text,
            data_source="AI模型预测数据",
            generated_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
        )
    except Exception:
        # 模板读取失败，用内联模板
        content = f"""# {city} {year}年 财政风险分析报告

## 📊 风险概况
{risk_overview}

## 📈 核心指标分析
{metrics_analysis}

## 🔮 趋势研判
{trend_analysis}

## 💡 政策建议
{policy_suggestions}

## ⚠️ 重点关注
{key_warnings_text}

---
*本报告由本地模板生成，仅供参考。*
"""

    return {"city": city, "year": year, "content": content, "source": "local"}


def _level_to_en(cn_level: str) -> str:
    """中文风险等级 → 英文"""
    mapping = {
        "低风险": "low",
        "中等偏低": "low",
        "中等": "medium",
        "中等偏高": "high",
        "高风险": "critical",
    }
    return mapping.get(cn_level, "medium")
