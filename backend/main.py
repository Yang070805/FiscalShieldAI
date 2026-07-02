"""
FiscalShieldAI 后端 V2 — FastAPI 入口
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import get_settings
from db.session import init_db
from core.exceptions import register_exception_handlers
from middleware.logging import RequestLoggingMiddleware
from middleware.rate_limit import RateLimitMiddleware

settings = get_settings()


# ==================== 生命周期 ====================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """启动时建表，关闭时清理"""
    print(f"🚀 {settings.APP_NAME} v{settings.APP_VERSION} 启动中...")
    import models  # noqa: F401
    await init_db()
    print("✅ 数据库初始化完成")
    yield
    print("👋 服务关闭")


# ==================== 创建应用 ====================

app = FastAPI(
    title=settings.APP_NAME,
    description="财智哨兵 — 财政风险 AI 预测系统\n\n"
                "## 功能模块\n"
                "- **认证**：注册/登录/改密/角色权限\n"
                "- **预测**：城市财政风险预测（AI模型+缓存）\n"
                "- **报告**：AI生成财政分析报告（蓝心大模型）\n"
                "- **对话**：AI对话助手（SSE流式响应）\n"
                "- **搜索**：城市搜索/收藏/推荐\n"
                "- **上传**：政务/企业数据上传（Excel解析+入库）\n\n"
                "## 角色权限\n"
                "- `gov`：政务版，全部功能\n"
                "- `enterprise`：企业版，全部功能\n"
                "- `citizen`：民用版，只读+对话",
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# 中间件（顺序：后注册的先执行）
app.add_middleware(RateLimitMiddleware, max_requests=120, window_seconds=60)
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 异常处理
register_exception_handlers(app)


# ==================== 路由注册 ====================

@app.get("/health", tags=["系统"])
async def health():
    """健康检查"""
    return {
        "success": True,
        "message": "ok",
        "data": {
            "app": settings.APP_NAME,
            "version": settings.APP_VERSION,
        },
    }


# API v1 路由
from api.v1.api import api_router  # noqa: E402
app.include_router(api_router, prefix="/api/v1")


# ==================== 启动 ====================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
