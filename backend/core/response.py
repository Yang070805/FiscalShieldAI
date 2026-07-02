"""
统一响应格式
"""

from typing import Any
from pydantic import BaseModel, field_validator


class ApiResponse(BaseModel):
    """统一 API 响应格式"""
    success: bool = True
    message: str = "ok"
    data: Any | None = None

    @field_validator("data", mode="before")
    @classmethod
    def dump_models(cls, v: Any) -> Any:
        """自动序列化 Pydantic 模型"""
        if isinstance(v, BaseModel):
            return v.model_dump()
        if isinstance(v, list):
            return [item.model_dump() if isinstance(item, BaseModel) else item for item in v]
        return v


def ok(data: Any = None, message: str = "ok") -> dict:
    """成功响应"""
    return ApiResponse(success=True, message=message, data=data).model_dump()


def fail(message: str = "error", data: Any = None) -> dict:
    """失败响应"""
    return ApiResponse(success=False, message=message, data=data).model_dump()
