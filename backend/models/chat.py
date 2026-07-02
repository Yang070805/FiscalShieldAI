"""
Chat 模型 — 对话历史存储
"""

from datetime import datetime

from sqlalchemy import String, Integer, DateTime, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from db.session import Base


class Chat(Base):
    """对话会话"""
    __tablename__ = "chats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True, comment="用户ID")
    title: Mapped[str] = mapped_column(String(200), default="新对话", comment="对话标题")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="更新时间")


class ChatMessage(Base):
    """对话消息"""
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    chat_id: Mapped[int] = mapped_column(Integer, ForeignKey("chats.id", ondelete="CASCADE"), index=True, comment="对话ID")
    role: Mapped[str] = mapped_column(String(20), comment="角色: user/assistant")
    content: Mapped[str] = mapped_column(Text, comment="消息内容")
    model: Mapped[str] = mapped_column(String(50), default="bluelm", comment="使用的模型")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, comment="创建时间")
