"""
FastAPI 依赖注入 — 认证 + 权限
"""

from typing import Tuple

from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import get_db
from models.user import User
from core.security import decode_access_token
from core.exceptions import AuthError, PermissionError

# HTTPBearer 自动从 Header 提取 Bearer Token
bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    从 JWT Token 解析当前用户
    用法：user = Depends(get_current_user)
    """
    try:
        payload = decode_access_token(credentials.credentials)
        user_id = int(payload.get("sub"))
        if user_id is None:
            raise AuthError("Token 无效：缺少用户ID")
    except (JWTError, ValueError):
        raise AuthError("Token 无效或已过期")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise AuthError("用户不存在")

    return user


def role_required(*allowed_roles: str):
    """
    角色权限检查
    用法：user = role_required("gov", "enterprise")
    """
    async def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in allowed_roles:
            raise PermissionError(f"需要角色: {', '.join(allowed_roles)}")
        return user
    return checker
