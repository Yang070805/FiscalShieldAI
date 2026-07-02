"""
Pydantic Schema — 报告相关
"""

from pydantic import BaseModel, Field


class ReportResponse(BaseModel):
    """AI报告"""
    city: str
    year: int
    content: str = Field(..., description="报告正文(Markdown)")
    source: str = Field(..., description="来源: bluelm/other/local")
    cached: bool = Field(False, description="是否来自缓存")

    model_config = {"from_attributes": True}
