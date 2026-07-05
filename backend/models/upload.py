"""
Upload 模型 — 上传记录
"""

from datetime import datetime

from sqlalchemy import String, Integer, DateTime, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class UploadRecord(Base):
    __tablename__ = "upload_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True, comment="上传者ID")
    city: Mapped[str] = mapped_column(String(50), comment="城市名")
    year: Mapped[int] = mapped_column(Integer, comment="数据年份")
    filename: Mapped[str] = mapped_column(String(200), comment="原始文件名")
    rows: Mapped[int] = mapped_column(Integer, comment="数据行数")
    cols: Mapped[int] = mapped_column(Integer, comment="数据列数")
    status: Mapped[str] = mapped_column(String(20), default="pending", comment="状态: pending/confirmed/rejected")
    permission: Mapped[str] = mapped_column(String(30), default="internal", comment="数据权限: public/internal/public+training/internal+training")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="上传时间")
