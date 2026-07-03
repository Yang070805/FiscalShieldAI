"""
安全工具 — JWT 签发/验证 + bcrypt 密码哈希
"""

from datetime import datetime, timedelta, timezone

from jose import jwt, JWTError
import bcrypt

from config import get_settings

settings = get_settings()


def hash_password(password: str) -> str:
    """明文密码 → bcrypt 哈希"""
    pwd_bytes = password.encode('utf-8')[:72]  # bcrypt 限制72字节
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(pwd_bytes, salt).decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证明文密码与哈希是否匹配"""
    return bcrypt.checkpw(
        plain_password.encode('utf-8')[:72],
        hashed_password.encode('utf-8'),
    )


def create_access_token(user_id: int, role: str) -> str:
    """签发 JWT Access Token"""
    expire = datetime.now(timezone.utc) + timedelta(hours=settings.JWT_EXPIRE_HOURS)
    payload = {
        "sub": str(user_id),      # 用户ID
        "role": role,              # 角色
        "exp": expire,             # 过期时间
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    """
    解码 JWT Token
    成功返回 payload dict，失败抛 JWTError
    """
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
