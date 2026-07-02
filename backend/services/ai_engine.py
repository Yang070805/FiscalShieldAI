"""
AI 引擎服务层 — 包装 ai_engine 的推理和报告模块
"""

import json
import sys
from pathlib import Path
from typing import Optional

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
            model_path = AI_ENGINE_DIR / "checkpoints" / "student_model.pth"
            scaler_path = AI_ENGINE_DIR / "checkpoints" / "scaler.pkl"
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
            return {"error": f"未找到 {city} 的历史数据", "available_cities": get_available_cities()}

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
    AI 报告生成
    返回: {city, year, content, source}
    """
    try:
        from bluelm_report import ReportGenerator
        gen = ReportGenerator(api_key="")

        # 先获取预测数据作为报告输入
        predict_result = predict_by_city(city, year)
        if "error" in predict_result:
            return {"error": predict_result["error"]}

        report_text = gen.generate_report(
            city=city,
            year=year,
            prediction_data=predict_result,
            role=role,
        )
        return {
            "city": city,
            "year": year,
            "content": report_text,
            "source": "bluelm",
        }
    except Exception as e:
        # 降级到本地模板
        return _local_report(city, year, predict_by_city(city, year))


def _local_report(city: str, year: int, pred: dict) -> dict:
    """本地模板报告（降级方案）"""
    risk_level = pred.get("risk_level", "unknown")
    risk_score = pred.get("risk_score", 0)
    content = f"""# {city} {year}年 财政风险分析报告

## 综合评估
- **风险评分**: {risk_score}/100
- **风险等级**: {risk_level}
- **趋势**: {pred.get('trend', 'unknown')}

## 建议
根据模型预测，{city}当前财政风险等级为{risk_level}，建议持续关注相关指标变化。

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
