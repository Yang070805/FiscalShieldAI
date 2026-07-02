"""
User 模型 — SQLAlchemy 2.0 风格
"""

from datetime import datetime

from sqlalchemy import String, Integer, DateTime
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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
