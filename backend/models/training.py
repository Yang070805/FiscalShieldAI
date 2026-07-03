"""
TrainingRecord 模型 — 训练记录
"""

from datetime import datetime

from sqlalchemy import String, Integer, Float, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class TrainingRecord(Base):
    __tablename__ = "training_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    status: Mapped[str] = mapped_column(String(20), default="pending", comment="状态: pending/training/completed/failed")
    epochs: Mapped[int] = mapped_column(Integer, default=0, comment="训练轮数")
    best_loss: Mapped[float] = mapped_column(Float, default=0, comment="最佳loss")
    best_accuracy: Mapped[float] = mapped_column(Float, default=0, comment="最佳准确率")
    data_count: Mapped[int] = mapped_column(Integer, default=0, comment="训练数据量")
    log: Mapped[str] = mapped_column(Text, default="", comment="训练日志JSON")
    model_path: Mapped[str] = mapped_column(String(200), default="", comment="模型文件路径")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
