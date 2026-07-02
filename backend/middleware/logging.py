"""
请求日志中间件
"""

import time
from loguru import logger
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """记录每个请求的方法、路径、状态码、耗时"""

    async def dispatch(self, request: Request, call_next):
        start = time.time()
        response = await call_next(request)
        duration = time.time() - start

        # 跳过健康检查和docs的日志
        path = request.url.path
        if path in ("/health", "/docs", "/redoc", "/openapi.json"):
            return response

        logger.info(
            f"{request.method} {path} → {response.status_code} ({duration:.3f}s)"
        )
        return response
