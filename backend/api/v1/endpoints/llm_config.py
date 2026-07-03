"""
LLM 配置接口 — 多 Provider 支持 + API Key 管理
"""

from fastapi import APIRouter, Depends, Header
from pydantic import BaseModel
import json, os
from pathlib import Path

from models.user import User
from core.deps import get_current_user
from core.response import ok
from services.llm_providers import (
    get_provider,
    list_providers,
    resolve_api_key,
    resolve_base_url,
    build_headers,
)

router = APIRouter(prefix="/llm", tags=["LLM配置"])

# API Key 存储文件（跨进程共享）
API_KEYS_FILE = Path(__file__).parent.parent.parent.parent / "data" / "api_keys.json"

def _load_api_keys() -> dict:
    if API_KEYS_FILE.exists():
        return json.loads(API_KEYS_FILE.read_text())
    return {}

def _save_api_keys(keys: dict):
    API_KEYS_FILE.parent.mkdir(parents=True, exist_ok=True)
    API_KEYS_FILE.write_text(json.dumps(keys, ensure_ascii=False))


class SetApiKeyRequest(BaseModel):
    model: str
    api_key: str
    app_id: str = None


@router.post("/set-api-key")
async def set_api_key(
    req: SetApiKeyRequest,
    user: User = Depends(get_current_user),
):
    """设置 API Key（存储到文件，跨进程共享）"""
    keys = _load_api_keys()
    keys[req.model] = {"api_key": req.api_key, "app_id": req.app_id}
    _save_api_keys(keys)
    # 同时更新内存
    from config import get_settings
    settings = get_settings()
    settings._user_api_keys[req.model] = req.api_key
    return ok(message=f"{req.model} API Key 已保存")


@router.get("/providers")
async def get_providers(
    user: User = Depends(get_current_user),
):
    """获取所有支持的 LLM Provider 列表"""
    return ok(data=list_providers())


@router.get("/api-key-status")
async def api_key_status(
    user: User = Depends(get_current_user),
):
    """查看各模型 API Key 配置状态"""
    from config import get_settings
    settings = get_settings()
    providers = list_providers()
    status = {}
    for p in providers:
        name = p["name"]
        key = settings._user_api_keys.get(name, "")
        status[name] = {
            "display_name": p["display_name"],
            "configured": bool(key),
            "masked": f"{key[:8]}...{key[-4:]}" if len(key) > 12 else ("***" if key else "未配置"),
        }
    return ok(data=status)


@router.get("/test-connection")
async def test_llm_connection(
    user: User = Depends(get_current_user),
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
    x_ai_model: str = Header(None, alias="X-AI-Model"),
    x_ai_app_id: str = Header(None, alias="X-AI-App-ID"),
):
    """
    测试 LLM 连接 — 发一条测试消息看是否能收到回复
    支持多家 Provider，从前端 Header 获取配置
    """
    provider_name = x_ai_model or "bluelm"
    api_key = resolve_api_key(provider_name, x_ai_api_key)

    if not api_key:
        return ok(data={
            "status": "no_key",
            "message": f"未配置 {provider_name} 的 API Key",
            "provider": provider_name,
        })

    # 获取 Provider 配置
    try:
        config = get_provider(provider_name)
    except ValueError as e:
        return ok(data={"status": "error", "message": str(e)})

    resolved_url = resolve_base_url(provider_name, None)
    headers = build_headers(provider_name, api_key, app_id=x_ai_app_id)

    # 构建测试请求
    is_anthropic = provider_name == "anthropic"
    if is_anthropic:
        body = {
            "model": config.model,
            "max_tokens": 20,
            "messages": [{"role": "user", "content": "你好"}],
        }
    else:
        body = {
            "model": config.model,
            "messages": [{"role": "user", "content": "你好"}],
            "max_tokens": 20,
        }

    # 发送测试请求
    import httpx
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(resolved_url, headers=headers, json=body)
            if resp.status_code == 200:
                return ok(data={
                    "status": "ok",
                    "message": f"✅ {config.display_name} 连接成功！",
                    "provider": provider_name,
                    "model": config.model,
                })
            elif resp.status_code in (401, 403):
                return ok(data={
                    "status": "auth_error",
                    "message": f"❌ API Key 无效，请检查后重试",
                    "provider": provider_name,
                })
            else:
                return ok(data={
                    "status": "error",
                    "message": f"❌ {config.display_name} 返回错误: {resp.status_code}",
                    "provider": provider_name,
                })
    except httpx.TimeoutException:
        return ok(data={
            "status": "timeout",
            "message": "❌ 连接超时，请检查网络",
            "provider": provider_name,
        })
    except Exception as e:
        return ok(data={
            "status": "error",
            "message": f"❌ 连接失败: {str(e)}",
            "provider": provider_name,
        })
