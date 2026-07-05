"""
User 模型 — SQLAlchemy 2.0 风格
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True, comment="手机号")
    nickname: Mapped[str] = mapped_column(String(50), comment="昵称")
    password_hash: Mapped[str] = mapped_column(String(128), comment="密码哈希")
    role: Mapped[str] = mapped_column(String(20), default="citizen", comment="角色: gov/enterprise/citizen")
    avatar: Mapped[str] = mapped_column(String(100), default="default", comment="头像")
    enterprise_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("enterprises.id"), nullable=True, comment="所属企业ID")
    enterprise_role: Mapped[Optional[str]] = mapped_column(String(20), nullable=True, comment="企业内角色: admin/member")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
