"""
统一异常体系
"""

from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError


class AppException(Exception):
    """应用基础异常"""
    def __init__(self, message: str = "服务器错误", code: int = 500):
        self.message = message
        self.code = code


class AuthError(AppException):
    """认证错误"""
    def __init__(self, message: str = "未登录或 Token 已过期"):
        super().__init__(message=message, code=401)


class NotFoundError(AppException):
    """资源不存在"""
    def __init__(self, message: str = "资源不存在"):
        super().__init__(message=message, code=404)


class PermissionError(AppException):
    """权限不足"""
    def __init__(self, message: str = "权限不足"):
        super().__init__(message=message, code=403)


class ParamsError(AppException):
    """参数错误"""
    def __init__(self, message: str = "参数错误"):
        super().__init__(message=message, code=400)


# ==================== 全局异常处理器 ====================

async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.code,
        content={"success": False, "message": exc.message, "data": None},
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    detail = errors[0]["msg"] if errors else "参数验证失败"
    return JSONResponse(
        status_code=400,
        content={"success": False, "message": f"参数错误: {detail}", "data": None},
    )


async def general_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"success": False, "message": f"服务器内部错误: {str(exc)}", "data": None},
    )


def register_exception_handlers(app):
    """注册所有异常处理器"""
    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, general_exception_handler)
