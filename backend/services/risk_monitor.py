"""
风险监控服务 — 扫描城市风险指标，异常检测

功能：
- scan_city(city) — 扫描单个城市的风险指标
- scan_all() — 批量扫描所有城市
- detect_anomaly(data) — 异常检测（基于阈值+趋势突变）
- 阈值：赤字率>3%, 债务率>100%, 风险评分>80 为异常
"""

import json
from datetime import datetime
from typing import List, Dict, Any, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from db.session import async_session
from models.prediction import Prediction
from models.monitor import Alert


# ==================== 阈值配置 ====================

THRESHOLDS = {
    "deficit_rate": {"warning": 2.5, "critical": 3.0, "unit": "%", "name": "赤字率"},
    "debt_ratio": {"warning": 80, "critical": 100, "unit": "%", "name": "债务率"},
    "risk_score": {"warning": 60, "critical": 80, "unit": "", "name": "风险评分"},
    "liability_ratio": {"warning": 50, "critical": 60, "unit": "%", "name": "负债率"},
    "cash_debt_ratio": {"warning": 1.0, "critical": 0.5, "unit": "", "name": "现金短期债务比", "lower_is_better": False},
    "npl_ratio": {"warning": 3.0, "critical": 5.0, "unit": "%", "name": "不良贷款率"},
}


# ==================== 异常检测 ====================

def detect_anomaly(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    基于阈值的异常检测

    Args:
        data: 城市指标数据 {metric_name: value, ...}
    Returns:
        异常列表 [{type, level, message, metric_value, threshold}]
    """
    alerts = []

    for metric_key, config in THRESHOLDS.items():
        value = data.get(metric_key)
        if value is None:
            continue

        try:
            value = float(value)
        except (ValueError, TypeError):
            continue

        lower_is_better = config.get("lower_is_better", True)
        critical_threshold = config["critical"]
        warning_threshold = config["warning"]
        name = config["name"]

        if lower_is_better:
            if value > critical_threshold:
                alerts.append({
                    "type": metric_key,
                    "level": "critical",
                    "message": f"{name} {value}{config['unit']} 超过警戒线 {critical_threshold}{config['unit']}",
                    "metric_value": value,
                    "threshold": critical_threshold,
                })
            elif value > warning_threshold:
                alerts.append({
                    "type": metric_key,
                    "level": "warning",
                    "message": f"{name} {value}{config['unit']} 接近警戒线（预警值 {warning_threshold}{config['unit']}）",
                    "metric_value": value,
                    "threshold": warning_threshold,
                })
        else:
            # lower_is_better=False: 值越低越危险（如现金短期债务比）
            if value < critical_threshold:
                alerts.append({
                    "type": metric_key,
                    "level": "critical",
                    "message": f"{name} {value}{config['unit']} 低于安全线 {critical_threshold}{config['unit']}",
                    "metric_value": value,
                    "threshold": critical_threshold,
                })
            elif value < warning_threshold:
                alerts.append({
                    "type": metric_key,
                    "level": "warning",
                    "message": f"{name} {value}{config['unit']} 接近安全线（预警值 {warning_threshold}{config['unit']}）",
                    "metric_value": value,
                    "threshold": warning_threshold,
                })

    return alerts


def _extract_metrics(detail_json: str) -> Dict[str, Any]:
    """从 detail_json 中提取关键指标"""
    try:
        detail = json.loads(detail_json) if detail_json else {}
    except (json.JSONDecodeError, TypeError):
        detail = {}

    metrics = {}

    # 尝试从嵌套结构中提取
    if "metrics" in detail:
        metrics.update(detail["metrics"])

    # 直接从 detail 中提取
    key_mapping = {
        "赤字率(%)": "deficit_rate",
        "债务率(%)": "debt_ratio",
        "负债率(%)": "liability_ratio",
        "现金短期债务比": "cash_debt_ratio",
        "不良贷款率(%)": "npl_ratio",
        "风险评分": "risk_score",
    }

    for cn_key, en_key in key_mapping.items():
        if cn_key in detail:
            try:
                metrics[en_key] = float(detail[cn_key])
            except (ValueError, TypeError):
                pass

    return metrics


# ==================== 扫描功能 ====================

async def scan_city(city: str, db: AsyncSession) -> Dict[str, Any]:
    """
    扫描单个城市的风险指标

    Returns:
        {city, status, alerts: [...]}
    """
    # 获取该城市最新的预测数据
    result = await db.execute(
        select(Prediction)
        .where(Prediction.city == city)
        .order_by(Prediction.created_at.desc())
        .limit(5)
    )
    predictions = result.scalars().all()

    if not predictions:
        return {"city": city, "status": "no_data", "alerts": []}

    all_alerts = []
    latest = predictions[0]

    # 从风险评分检测
    if latest.risk_score:
        score_alerts = detect_anomaly({"risk_score": latest.risk_score})
        for alert in score_alerts:
            alert["city"] = city
            all_alerts.append(alert)

    # 从 detail_json 检测
    metrics = _extract_metrics(latest.detail_json)
    if metrics:
        metric_alerts = detect_anomaly(metrics)
        for alert in metric_alerts:
            alert["city"] = city
            all_alerts.append(alert)

    # 趋势突变检测：对比最近两条数据
    if len(predictions) >= 2:
        prev = predictions[1]
        score_change = (latest.risk_score or 0) - (prev.risk_score or 0)
        if score_change > 10:
            all_alerts.append({
                "city": city,
                "type": "trend",
                "level": "warning",
                "message": f"风险评分较上次上升 {score_change:.1f} 分，趋势异常",
                "metric_value": score_change,
                "threshold": 10,
            })

    # 判定城市整体状态
    status = "normal"
    if any(a["level"] == "critical" for a in all_alerts):
        status = "critical"
    elif any(a["level"] == "warning" for a in all_alerts):
        status = "warning"

    return {"city": city, "status": status, "alerts": all_alerts}


async def scan_all(db: AsyncSession) -> Dict[str, Any]:
    """
    批量扫描所有城市

    Returns:
        {results: [...], summary: {total, normal, warning, critical}}
    """
    # 获取所有有数据的城市
    from services.ai_engine import get_available_cities
    cities = get_available_cities()

    # 如果没有城市数据，从数据库中获取
    if not cities:
        from sqlalchemy import func
        result = await db.execute(
            select(Prediction.city).distinct()
        )
        cities = [row[0] for row in result.all()]

    results = []
    summary = {"total": 0, "normal": 0, "warning": 0, "critical": 0}

    for city in cities:
        city_result = await scan_city(city, db)
        results.append(city_result)
        summary["total"] += 1
        status = city_result["status"]
        if status in summary:
            summary[status] += 1

    return {"results": results, "summary": summary}


async def save_alerts(alerts: List[Dict[str, Any]], db: AsyncSession):
    """保存告警到数据库"""
    for alert_data in alerts:
        alert = Alert(
            city=alert_data.get("city", ""),
            type=alert_data.get("type", "unknown"),
            level=alert_data.get("level", "info"),
            message=alert_data.get("message", ""),
            metric_value=alert_data.get("metric_value", 0),
            threshold=alert_data.get("threshold", 0),
            resolved=False,
        )
        db.add(alert)
    await db.commit()


async def get_alerts(
    db: AsyncSession,
    city: Optional[str] = None,
    level: Optional[str] = None,
    resolved: Optional[bool] = None,
    limit: int = 50,
) -> List[Dict[str, Any]]:
    """获取告警列表"""
    query = select(Alert)

    if city:
        query = query.where(Alert.city == city)
    if level:
        query = query.where(Alert.level == level)
    if resolved is not None:
        query = query.where(Alert.resolved == resolved)

    query = query.order_by(Alert.created_at.desc()).limit(limit)
    result = await db.execute(query)
    alerts = result.scalars().all()

    return [
        {
            "id": a.id,
            "city": a.city,
            "type": a.type,
            "level": a.level,
            "message": a.message,
            "metric_value": a.metric_value,
            "threshold": a.threshold,
            "resolved": a.resolved,
            "created_at": a.created_at.isoformat() if a.created_at else "",
        }
        for a in alerts
    ]


async def get_overview(db: AsyncSession) -> Dict[str, Any]:
    """获取监控概览"""
    from sqlalchemy import func

    # 城市统计
    city_result = await db.execute(
        select(Prediction.city).distinct()
    )
    all_cities = [row[0] for row in city_result.all()]

    total_cities = len(all_cities)
    normal = 0
    warning = 0
    critical = 0

    for city in all_cities:
        city_result = await scan_city(city, db)
        status = city_result["status"]
        if status == "critical":
            critical += 1
        elif status == "warning":
            warning += 1
        else:
            normal += 1

    # 告警统计
    alert_result = await db.execute(
        select(func.count(Alert.id)).where(Alert.resolved == False)
    )
    unresolved_alerts = alert_result.scalar() or 0

    total_alert_result = await db.execute(select(func.count(Alert.id)))
    total_alerts = total_alert_result.scalar() or 0

    return {
        "total_cities": total_cities,
        "normal": normal,
        "warning": warning,
        "critical": critical,
        "total_alerts": total_alerts,
        "unresolved_alerts": unresolved_alerts,
    }
