"""
API 限流中间件 — 内存实现（比赛阶段，正式产品换Redis）
"""

import time
from collections import defaultdict

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    基于IP的滑动窗口限流
    默认：60次/分钟
    """

    def __init__(self, app, max_requests: int = 60, window_seconds: int = 60):
        super().__init__(app)
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        # 跳过健康检查
        if request.url.path == "/health":
            return await call_next(request)

        client_ip = request.client.host if request.client else "unknown"
        now = time.time()

        # 清理过期记录
        self.requests[client_ip] = [
            t for t in self.requests[client_ip]
            if now - t < self.window_seconds
        ]

        # 检查是否超限
        if len(self.requests[client_ip]) >= self.max_requests:
            return JSONResponse(
                status_code=429,
                content={
                    "success": False,
                    "message": f"请求过于频繁，限制 {self.max_requests} 次/{self.window_seconds}秒",
                    "data": None,
                },
            )

        # 记录请求
        self.requests[client_ip].append(now)

        return await call_next(request)
