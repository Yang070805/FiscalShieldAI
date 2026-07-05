"""
Pydantic Schema — 用户相关
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ==================== 请求 Schema ====================

class RegisterRequest(BaseModel):
    """注册请求"""
    phone: str = Field(..., min_length=11, max_length=11, description="手机号")
    password: str = Field(..., min_length=6, max_length=50, description="密码")
    nickname: str = Field(..., min_length=1, max_length=50, description="昵称")
    role: Optional[str] = Field("citizen", description="角色: gov/enterprise/citizen")
    # 企业注册额外字段
    enterprise_name: Optional[str] = Field(None, description="企业名称（企业注册时必填）")
    credit_code: Optional[str] = Field(None, description="统一社会信用代码（企业注册时必填）")
    enterprise_phone: Optional[str] = Field(None, description="企业联系电话（企业注册时必填）")


class LoginRequest(BaseModel):
    """登录请求"""
    phone: str = Field(..., description="手机号")
    password: str = Field(..., description="密码")


class PasswordChangeRequest(BaseModel):
    """改密请求"""
    old_password: str = Field(..., description="旧密码")
    new_password: str = Field(..., min_length=6, max_length=50, description="新密码")


# ==================== 响应 Schema ====================

class UserResponse(BaseModel):
    """用户信息响应"""
    id: int
    phone: str
    nickname: str
    role: str
    avatar: str
    enterprise_id: Optional[int] = None
    enterprise_role: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    """Token 响应"""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
