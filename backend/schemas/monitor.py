"""
Pydantic Schema — 监控相关
"""

from typing import Optional, List
from pydantic import BaseModel, Field


class AlertItem(BaseModel):
    """告警项"""
    id: int
    city: str
    type: str
    level: str
    message: str
    metric_value: float = 0
    threshold: float = 0
    resolved: bool = False
    created_at: str

    model_config = {"from_attributes": True}


class ScanResult(BaseModel):
    """扫描结果"""
    city: str
    scanned: bool
    alerts_generated: int
    status: str  # normal/warning/critical


class MonitorOverview(BaseModel):
    """监控概览"""
    total_cities: int
    normal: int
    warning: int
    critical: int
    total_alerts: int
    unresolved_alerts: int
