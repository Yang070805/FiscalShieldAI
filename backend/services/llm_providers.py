"""
LLM Provider 配置 — 支持多家大模型，客户端可自由切换
参考 next-ai-draw-io 的 ai-providers 模式

支持的 Provider：
- bluelm (vivo蓝心) — 默认
- deepseek
- qwen (通义千问)
- doubao (豆包)
- openai (ChatGPT)
- anthropic (Claude)
- kimi (Moonshot)
"""

from typing import Optional, Dict, Any
from dataclasses import dataclass
import os


@dataclass
class ProviderConfig:
    """单个 Provider 的配置"""
    name: str              # 内部标识
    display_name: str      # 显示名称
    api_url: str           # API 端点
    model: str             # 默认模型 ID
    header_key: str        # API Key Header 名（默认 Authorization Bearer）
    extra_headers: dict    # 额外 Header


# Provider 注册表
PROVIDERS: Dict[str, ProviderConfig] = {
    "bluelm": ProviderConfig(
        name="bluelm",
        display_name="vivo 蓝心大模型",
        api_url="https://api-ai.vivo.com.cn/v1/chat/completions",
        model="Doubao-Seed-2.0-mini",
        header_key="Authorization",
        extra_headers={},
    ),
    "deepseek": ProviderConfig(
        name="deepseek",
        display_name="DeepSeek",
        api_url="https://api.deepseek.com/v1/chat/completions",
        model="deepseek-chat",
        header_key="Authorization",
        extra_headers={},
    ),
    "qwen": ProviderConfig(
        name="qwen",
        display_name="通义千问",
        api_url="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
        model="qwen-turbo",
        header_key="Authorization",
        extra_headers={},
    ),
    "doubao": ProviderConfig(
        name="doubao",
        display_name="豆包",
        api_url="https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        model="doubao-lite-4k",
        header_key="Authorization",
        extra_headers={},
    ),
    "openai": ProviderConfig(
        name="openai",
        display_name="ChatGPT (OpenAI)",
        api_url="https://api.openai.com/v1/chat/completions",
        model="gpt-4o-mini",
        header_key="Authorization",
        extra_headers={},
    ),
    "anthropic": ProviderConfig(
        name="anthropic",
        display_name="Claude (Anthropic)",
        api_url="https://api.anthropic.com/v1/messages",
        model="claude-3-5-haiku-20241022",
        header_key="x-api-key",
        extra_headers={"anthropic-version": "2023-06-01"},
    ),
    "kimi": ProviderConfig(
        name="kimi",
        display_name="Kimi (Moonshot)",
        api_url="https://api.moonshot.cn/v1/chat/completions",
        model="moonshot-v1-8k",
        header_key="Authorization",
        extra_headers={},
    ),
}


def get_provider(name: str) -> ProviderConfig:
    """获取 Provider 配置"""
    if name not in PROVIDERS:
        raise ValueError(f"不支持的 Provider: {name}，可选: {', '.join(PROVIDERS.keys())}")
    return PROVIDERS[name]


def list_providers() -> list:
    """列出所有 Provider"""
    return [
        {
            "name": p.name,
            "display_name": p.display_name,
            "model": p.model,
            "default_api_url": p.api_url,
        }
        for p in PROVIDERS.values()
    ]


def resolve_api_key(
    provider_name: str,
    client_api_key: Optional[str] = None,
) -> Optional[str]:
    """
    解析 API Key
    优先级: 客户端 Header > 文件存储 > 环境变量
    """
    # 1. 客户端传入的 Key
    if client_api_key:
        return client_api_key

    # 2. 文件存储（跨进程共享）
    try:
        from pathlib import Path
        import json
        keys_file = Path(__file__).parent.parent / "data" / "api_keys.json"
        if keys_file.exists():
            keys = json.loads(keys_file.read_text())
            if provider_name in keys:
                return keys[provider_name].get("api_key")
    except Exception:
        pass

    # 3. 内存存储
    try:
        from config import get_settings
        settings = get_settings()
        return settings._user_api_keys.get(provider_name)
    except Exception:
        return None


def get_app_id(
    provider_name: str,
    client_app_id: Optional[str] = None,
) -> Optional[str]:
    """获取 AppID（仅 vivo 蓝心需要）"""
    if client_app_id:
        return client_app_id
    try:
        from pathlib import Path
        import json
        keys_file = Path(__file__).parent.parent / "data" / "api_keys.json"
        if keys_file.exists():
            keys = json.loads(keys_file.read_text())
            if provider_name in keys:
                return keys[provider_name].get("app_id")
    except Exception:
        pass
    return None


def resolve_base_url(
    provider_name: str,
    client_base_url: Optional[str] = None,
) -> str:
    """
    解析 API URL
    优先级: 客户端传入 > Provider 默认
    """
    if client_base_url:
        return client_base_url
    config = get_provider(provider_name)
    return config.api_url


def build_headers(
    provider_name: str,
    api_key: Optional[str],
    app_id: Optional[str] = None,
) -> dict:
    """构建 API 请求 Headers"""
    config = get_provider(provider_name)
    headers = {"Content-Type": "application/json; charset=utf-8"}
    headers.update(config.extra_headers)

    if provider_name == "bluelm":
        # vivo 蓝心: AppKey 放 Authorization，AppID 放 app_id header
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        if app_id:
            headers["app_id"] = app_id
    elif api_key:
        if config.header_key == "Authorization":
            headers["Authorization"] = f"Bearer {api_key}"
        else:
            headers[config.header_key] = api_key

    return headers
