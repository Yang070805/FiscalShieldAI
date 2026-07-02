"""
认证接口 — 注册 / 登录 / 当前用户 / 改密
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import get_db
from models.user import User
from schemas.user import (
    RegisterRequest,
    LoginRequest,
    PasswordChangeRequest,
    UserResponse,
    TokenResponse,
)
from core.security import hash_password, verify_password, create_access_token
from core.deps import get_current_user
from core.exceptions import ParamsError, AuthError, NotFoundError
from core.response import ok

router = APIRouter(prefix="/auth", tags=["认证"])


@router.post("/register")
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """注册新用户"""
    # 检查手机号是否已注册
    result = await db.execute(select(User).where(User.phone == req.phone))
    if result.scalar_one_or_none():
        raise ParamsError("该手机号已注册")

    # 检查角色是否合法
    valid_roles = ("gov", "enterprise", "citizen")
    if req.role and req.role not in valid_roles:
        raise ParamsError(f"角色必须是: {', '.join(valid_roles)}")

    # 创建用户
    user = User(
        phone=req.phone,
        nickname=req.nickname,
        password_hash=hash_password(req.password),
        role=req.role or "citizen",
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    # 签发 Token
    token = create_access_token(user.id, user.role)

    return ok(
        data=TokenResponse(
            access_token=token,
            user=UserResponse.model_validate(user),
        ).model_dump(),
        message="注册成功",
    )


@router.post("/login")
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """登录"""
    result = await db.execute(select(User).where(User.phone == req.phone))
    user = result.scalar_one_or_none()

    if not user or not verify_password(req.password, user.password_hash):
        raise AuthError("手机号或密码错误")

    token = create_access_token(user.id, user.role)

    return ok(
        data=TokenResponse(
            access_token=token,
            user=UserResponse.model_validate(user),
        ).model_dump(),
        message="登录成功",
    )


@router.get("/me")
async def get_me(user: User = Depends(get_current_user)):
    """获取当前用户信息"""
    return ok(data=UserResponse.model_validate(user).model_dump())


@router.put("/password")
async def change_password(
    req: PasswordChangeRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """修改密码"""
    if not verify_password(req.old_password, user.password_hash):
        raise AuthError("旧密码错误")

    user.password_hash = hash_password(req.new_password)
    await db.commit()

    return ok(message="密码修改成功")
