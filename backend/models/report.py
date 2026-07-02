"""
Report 模型 — AI报告缓存
"""

from datetime import datetime

from sqlalchemy import String, Integer, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    city: Mapped[str] = mapped_column(String(50), index=True, comment="城市名")
    year: Mapped[int] = mapped_column(Integer, index=True, comment="报告年份")
    role: Mapped[str] = mapped_column(String(20), default="citizen", comment="请求角色")

    # 报告内容
    content: Mapped[str] = mapped_column(Text, comment="报告正文(Markdown)")
    source: Mapped[str] = mapped_column(String(20), comment="来源: bluelm/other/local")

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
