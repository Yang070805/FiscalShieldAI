"""
Favorite 模型 — 收藏
"""

from datetime import datetime

from sqlalchemy import String, Integer, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class Favorite(Base):
    __tablename__ = "favorites"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True, comment="用户ID")
    city: Mapped[str] = mapped_column(String(50), comment="收藏城市")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="收藏时间")

    __table_args__ = (
        UniqueConstraint("user_id", "city", name="uq_user_city"),
    )
