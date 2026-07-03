"""
Alert 模型 — 风险监控告警
"""

from datetime import datetime

from sqlalchemy import String, Integer, DateTime, Boolean, Text
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class Alert(Base):
    __tablename__ = "alerts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    city: Mapped[str] = mapped_column(String(50), index=True, comment="城市名")
    type: Mapped[str] = mapped_column(String(50), comment="告警类型: deficit/debt/risk_score/trend")
    level: Mapped[str] = mapped_column(String(20), comment="告警级别: info/warning/critical")
    message: Mapped[str] = mapped_column(Text, comment="告警描述")
    metric_value: Mapped[float] = mapped_column(default=0, comment="触发告警的指标值")
    threshold: Mapped[float] = mapped_column(default=0, comment="告警阈值")
    resolved: Mapped[bool] = mapped_column(Boolean, default=False, comment="是否已处理")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
