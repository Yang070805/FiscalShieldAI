"""
Pydantic Schema — 训练相关
"""

from typing import Optional, List
from pydantic import BaseModel, Field


class TrainingStatus(BaseModel):
    """训练状态"""
    status: str  # idle/training/completed/failed
    current_epoch: int = 0
    total_epochs: int = 0
    loss: Optional[float] = None
    accuracy: Optional[float] = None
    started_at: Optional[str] = None
    message: str = ""


class TrainingHistoryItem(BaseModel):
    """训练历史项"""
    id: int
    status: str
    epochs: int
    best_loss: Optional[float] = None
    best_accuracy: Optional[float] = None
    data_count: int = 0
    created_at: str

    model_config = {"from_attributes": True}
