"""
Prediction 模型 — 预测结果缓存
"""

from datetime import datetime

from sqlalchemy import String, Integer, Float, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class Prediction(Base):
    __tablename__ = "predictions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    city: Mapped[str] = mapped_column(String(50), index=True, comment="城市名")
    year: Mapped[int] = mapped_column(Integer, index=True, comment="预测年份")
    role: Mapped[str] = mapped_column(String(20), default="citizen", comment="请求角色")

    # 预测结果
    risk_score: Mapped[float] = mapped_column(Float, comment="综合风险分(0-100)")
    risk_level: Mapped[str] = mapped_column(String(20), comment="风险等级: low/medium/high/critical")
    trend: Mapped[str] = mapped_column(String(20), comment="趋势: rising/stable/declining")
    detail_json: Mapped[str] = mapped_column(Text, default="{}", comment="详细指标JSON")

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
