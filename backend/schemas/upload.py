"""
Pydantic Schema — 上传相关
"""

from typing import List, Optional, Any
from pydantic import BaseModel, Field


class UploadPreview(BaseModel):
    """上传预览结果"""
    filename: str
    rows: int
    cols: int
    columns: List[dict] = Field(description="列信息 [{name, dtype}]")
    missing: dict = Field(description="缺失值统计")
    preview: List[dict] = Field(description="前20行预览")
    stats: dict = Field(default_factory=dict, description="数值列统计摘要")


class UploadConfirmRequest(BaseModel):
    """确认入库请求"""
    city: str = Field(..., description="城市名")
    year: int = Field(..., ge=2020, le=2035, description="数据年份")
    data: List[dict] = Field(..., description="数据行")
    permission: str = Field("internal", description="权限: public/internal/private")


class UploadHistoryItem(BaseModel):
    """上传历史项"""
    id: int
    city: str
    year: int
    filename: str
    rows: int
    cols: int
    status: str
    created_at: str

    model_config = {"from_attributes": True}
