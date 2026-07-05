"""
Pydantic Schema — 企业相关
"""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, Field


# ==================== 请求 Schema ====================

class EnterpriseRegisterRequest(BaseModel):
    """企业注册请求"""
    enterprise_name: str = Field(..., min_length=1, max_length=100, description="企业名称")
    credit_code: str = Field(..., min_length=15, max_length=20, description="统一社会信用代码")
    contact_phone: str = Field(..., min_length=11, max_length=11, description="联系电话")


class MemberCreateRequest(BaseModel):
    """创建成员请求"""
    phone: str = Field(..., min_length=11, max_length=11, description="成员手机号")
    nickname: str = Field(..., min_length=1, max_length=50, description="成员昵称")
    password: str = Field(..., min_length=6, max_length=50, description="初始密码")
    enterprise_role: str = Field("member", description="企业内角色: admin/member")


class MemberPasswordResetRequest(BaseModel):
    """重置成员密码"""
    new_password: str = Field(..., min_length=6, max_length=50, description="新密码")


class TransferAdminRequest(BaseModel):
    """转让管理员"""
    member_id: int = Field(..., description="目标成员ID")


# ==================== 响应 Schema ====================

class EnterpriseResponse(BaseModel):
    """企业信息响应"""
    id: int
    name: str
    credit_code: str
    contact_phone: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class MemberResponse(BaseModel):
    """成员信息响应"""
    id: int
    phone: str
    nickname: str
    enterprise_role: str
    created_at: datetime

    model_config = {"from_attributes": True}
