"""
Enterprise 模型 — 企业信息
"""

from datetime import datetime

from sqlalchemy import String, Integer, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class Enterprise(Base):
    __tablename__ = "enterprises"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False, comment="企业名称")
    credit_code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, comment="统一社会信用代码")
    contact_phone: Mapped[str] = mapped_column(String(20), nullable=False, comment="联系电话")
    status: Mapped[str] = mapped_column(String(20), default="active", comment="状态: active/suspended")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
