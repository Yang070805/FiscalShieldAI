"""
Pydantic Schema — 预测相关
"""

from typing import Optional
from pydantic import BaseModel, Field


class PredictRequest(BaseModel):
    """预测请求"""
    city: str = Field(..., description="城市名")
    year: int = Field(..., ge=2020, le=2035, description="预测年份")


class PredictResponse(BaseModel):
    """预测结果"""
    city: str
    year: int
    risk_score: float = Field(..., description="综合风险分(0-100)")
    risk_level: str = Field(..., description="风险等级: low/medium/high/critical")
    trend: str = Field(..., description="趋势: rising/stable/declining")
    detail: dict = Field(default_factory=dict, description="详细指标")
    cached: bool = Field(False, description="是否来自缓存")

    model_config = {"from_attributes": True}
