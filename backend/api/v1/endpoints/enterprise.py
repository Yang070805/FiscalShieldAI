"""
企业接口 — 注册 / 信息 / 成员管理
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import get_db
from models.user import User
from models.enterprise import Enterprise
from schemas.enterprise import (
    EnterpriseRegisterRequest,
    MemberCreateRequest,
    MemberPasswordResetRequest,
    TransferAdminRequest,
    EnterpriseResponse,
    MemberResponse,
)
from core.security import hash_password, verify_password
from core.deps import get_current_user
from core.exceptions import ParamsError, PermissionError, NotFoundError
from core.response import ok

router = APIRouter(prefix="/enterprise", tags=["企业"])


# ==================== 企业注册 ====================

@router.post("/register")
async def enterprise_register(
    req: EnterpriseRegisterRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    企业注册 — 将当前用户升级为企业管理员
    前置条件：用户已注册个人账号（role=enterprise）
    """
    # 检查用户是否已经是企业管理员
    if user.enterprise_id:
        raise ParamsError("您已属于一家企业，无法重复注册")

    # 检查信用代码是否已被注册
    result = await db.execute(
        select(Enterprise).where(Enterprise.credit_code == req.credit_code)
    )
    if result.scalar_one_or_none():
        raise ParamsError("该统一社会信用代码已注册")

    # 创建企业
    enterprise = Enterprise(
        name=req.enterprise_name,
        credit_code=req.credit_code,
        contact_phone=req.enterprise_phone,
    )
    db.add(enterprise)
    await db.commit()
    await db.refresh(enterprise)

    # 将当前用户设为管理员
    user.enterprise_id = enterprise.id
    user.enterprise_role = "admin"
    await db.commit()

    return ok(
        data=EnterpriseResponse.model_validate(enterprise).model_dump(),
        message="企业注册成功，您已成为企业管理员",
    )


# ==================== 企业信息 ====================

@router.get("/info")
async def get_enterprise_info(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取当前企业信息"""
    if not user.enterprise_id:
        raise ParamsError("您未绑定企业")

    result = await db.execute(
        select(Enterprise).where(Enterprise.id == user.enterprise_id)
    )
    enterprise = result.scalar_one_or_none()
    if not enterprise:
        raise NotFoundError("企业不存在")

    return ok(data=EnterpriseResponse.model_validate(enterprise).model_dump())


# ==================== 成员管理 ====================

@router.post("/member/create")
async def create_member(
    req: MemberCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """创建成员（仅管理员）"""
    if not user.enterprise_id or user.enterprise_role != "admin":
        raise PermissionError("仅企业管理员可创建成员")

    # 检查手机号是否已注册
    result = await db.execute(select(User).where(User.phone == req.phone))
    if result.scalar_one_or_none():
        raise ParamsError("该手机号已注册")

    # 创建成员账号
    member = User(
        phone=req.phone,
        nickname=req.nickname,
        password_hash=hash_password(req.password),
        role="enterprise",
        enterprise_id=user.enterprise_id,
        enterprise_role=req.enterprise_role,
    )
    db.add(member)
    await db.commit()
    await db.refresh(member)

    return ok(
        data=MemberResponse.model_validate(member).model_dump(),
        message="成员创建成功",
    )


@router.get("/member/list")
async def list_members(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取成员列表"""
    if not user.enterprise_id:
        raise ParamsError("您未绑定企业")

    result = await db.execute(
        select(User).where(User.enterprise_id == user.enterprise_id)
    )
    members = result.scalars().all()

    return ok(
        data=[MemberResponse.model_validate(m).model_dump() for m in members]
    )


@router.delete("/member/{member_id}")
async def delete_member(
    member_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除成员（仅管理员）"""
    if not user.enterprise_id or user.enterprise_role != "admin":
        raise PermissionError("仅企业管理员可删除成员")

    if member_id == user.id:
        raise ParamsError("不能删除自己（管理员）")

    result = await db.execute(
        select(User).where(
            User.id == member_id,
            User.enterprise_id == user.enterprise_id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise NotFoundError("成员不存在")

    # 软删除：清空企业关联
    member.enterprise_id = None
    member.enterprise_role = None
    member.role = "citizen"  # 降级为普通用户
    await db.commit()

    return ok(message="成员已删除")


@router.post("/member/{member_id}/reset-password")
async def reset_member_password(
    member_id: int,
    req: MemberPasswordResetRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """重置成员密码（仅管理员）"""
    if not user.enterprise_id or user.enterprise_role != "admin":
        raise PermissionError("仅企业管理员可重置密码")

    result = await db.execute(
        select(User).where(
            User.id == member_id,
            User.enterprise_id == user.enterprise_id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise NotFoundError("成员不存在")

    member.password_hash = hash_password(req.new_password)
    await db.commit()

    return ok(message="密码已重置")


@router.post("/transfer-admin")
async def transfer_admin(
    req: TransferAdminRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """转让管理员角色"""
    if not user.enterprise_id or user.enterprise_role != "admin":
        raise PermissionError("仅企业管理员可转让")

    if req.member_id == user.id:
        raise ParamsError("不能转让给自己")

    result = await db.execute(
        select(User).where(
            User.id == req.member_id,
            User.enterprise_id == user.enterprise_id,
        )
    )
    target = result.scalar_one_or_none()
    if not target:
        raise NotFoundError("目标成员不存在")

    # 转让
    target.enterprise_role = "admin"
    user.enterprise_role = "member"
    await db.commit()

    return ok(message="管理员已转让")
