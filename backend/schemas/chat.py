"""
Pydantic Schema — 对话相关
"""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    """对话请求"""
    message: str = Field(..., min_length=1, description="用户消息")
    chat_id: Optional[int] = Field(None, description="对话ID（为空则新建对话）")
    city: Optional[str] = Field(None, description="关联城市")
    year: Optional[int] = Field(None, description="关联年份")
    model: str = Field("bluelm", description="模型选择: bluelm/deepseek/qwen/doubao")


class ChatListItem(BaseModel):
    """对话列表项"""
    id: int
    title: str
    updated_at: datetime

    model_config = {"from_attributes": True}


class ChatMessageItem(BaseModel):
    """对话消息项"""
    id: int
    role: str
    content: str
    model: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatDetail(BaseModel):
    """对话详情"""
    id: int
    title: str
    messages: List[ChatMessageItem]
    created_at: datetime

    model_config = {"from_attributes": True}
