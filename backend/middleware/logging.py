"""
请求日志中间件（增强版）
========================

功能：
- 记录每个请求的方法、路径、状态码、耗时
- 自动生成请求ID用于追踪
- 记录异常请求的详细信息
- 支持结构化日志输出
"""

import time
import uuid
from loguru import logger
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """记录每个请求的方法、路径、状态码、耗时（增强版）"""

    async def dispatch(self, request: Request, call_next):
        # 生成请求ID
        request_id = str(uuid.uuid4())[:8]
        request.state.request_id = request_id
        
        start = time.time()
        
        try:
            response = await call_next(request)
            duration = time.time() - start
            
            # 跳过健康检查和docs的日志
            path = request.url.path
            if path in ("/health", "/docs", "/redoc", "/openapi.json"):
                return response
            
            # 结构化日志
            log_data = {
                "request_id": request_id,
                "method": request.method,
                "path": path,
                "status": response.status_code,
                "duration_ms": round(duration * 1000, 2),
                "client": request.client.host if request.client else "unknown",
            }
            
            # 根据状态码选择日志级别
            if response.status_code >= 500:
                logger.error(f"请求失败: {log_data}")
            elif response.status_code >= 400:
                logger.warning(f"客户端错误: {log_data}")
            elif duration > 1.0:  # 慢请求
                logger.warning(f"慢请求: {log_data}")
            else:
                logger.info(f"请求完成: {log_data}")
            
            # 添加响应头
            response.headers["X-Request-ID"] = request_id
            response.headers["X-Response-Time"] = f"{duration:.3f}s"
            
            return response
            
        except Exception as e:
            duration = time.time() - start
            logger.error(f"请求异常: {request.method} {request.url.path} - {str(e)} ({duration:.3f}s)")
            raise


class ExceptionLoggingMiddleware(BaseHTTPMiddleware):
    """异常日志中间件 - 捕获未处理的异常"""

    async def dispatch(self, request: Request, call_next):
        try:
            return await call_next(request)
        except Exception as e:
            logger.exception(f"未处理异常: {request.method} {request.url.path}")
            raise
