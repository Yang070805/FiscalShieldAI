"""
LLM 对话服务 — 多 Provider 支持 + SSE 流式
参考 next-ai-draw-io 的 chat/route.ts 模式
"""

import json
import httpx
from typing import AsyncGenerator

from services.llm_providers import (
    get_provider,
    resolve_api_key,
    get_app_id,
    resolve_base_url,
    build_headers,
)


# 系统提示词
SYSTEM_PROMPT = """你是 FiscalShield AI 财政风险分析助手。你的职责是：
1. 分析城市/企业的财政风险数据
2. 解读赤字率、债务率、负债率等关键指标
3. 提供风险预警和政策建议
4. 基于历史数据给出趋势预测

回答要简洁、专业、有数据支撑。如果用户询问的是具体城市数据，请说明你需要先查询数据库。"""


async def call_llm_stream(
    message: str,
    history: list = None,
    city: str = None,
    year: int = None,
    role: str = "citizen",
    model: str = "bluelm",
    api_key: str = None,
    base_url: str = None,
    app_id: str = None,
) -> AsyncGenerator[str, None]:
    """
    SSE 流式调用 LLM
    支持多家 Provider，从前端 Header 获取配置
    """
    # 解析 Provider 配置
    provider_config = get_provider(model)
    resolved_key = resolve_api_key(model, api_key)
    resolved_url = resolve_base_url(model, base_url)
    # 优先用传入的 app_id，其次从文件读取
    resolved_app_id = app_id or get_app_id(model)
    headers = build_headers(model, resolved_key, app_id=resolved_app_id)

    # 构建消息
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    # 添加上下文
    context_parts = []
    if city:
        context_parts.append(f"当前分析城市：{city}")
    if year:
        context_parts.append(f"数据年份：{year}")
    if context_parts:
        messages.append({"role": "system", "content": "\n".join(context_parts)})

    # 添加历史对话
    if history:
        for msg in history[-8:]:  # 最近8条
            messages.append({"role": msg["role"], "content": msg["content"]})

    # 添加当前消息
    messages.append({"role": "user", "content": message})

    # 构建请求体
    is_anthropic = model == "anthropic"
    if is_anthropic:
        # Anthropic Messages API 格式
        system_msg = messages[0]["content"]
        api_messages = messages[1:]
        body = {
            "model": provider_config.model,
            "max_tokens": 2048,
            "system": system_msg,
            "messages": api_messages,
            "stream": True,
        }
    else:
        # OpenAI 兼容格式
        body = {
            "model": provider_config.model,
            "messages": messages,
            "max_tokens": 2048,
            "stream": True,
            "temperature": 0.7,
        }

    # vivo 蓝心需要 request_id 查询参数
    import uuid
    request_id = str(uuid.uuid4())
    request_url = resolved_url
    if model == "bluelm":
        separator = "&" if "?" in resolved_url else "?"
        request_url = f"{resolved_url}{separator}request_id={request_id}"

    # 流式请求
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream(
                "POST",
                request_url,
                headers=headers,
                json=body,
            ) as resp:
                if resp.status_code != 200:
                    error_body = ""
                    async for chunk in resp.aiter_text():
                        error_body += chunk
                    yield f"[错误] {provider_config.display_name} 返回 {resp.status_code}: {error_body[:200]}"
                    return

                async for line in resp.aiter_lines():
                    if not line.startswith("data:"):
                        continue
                    data_str = line[5:].strip()
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        if is_anthropic:
                            if data.get("type") == "content_block_delta":
                                yield data.get("delta", {}).get("text", "")
                        else:
                            choices = data.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                # vivo 蓝心: 先返回 reasoning_content（思考），再返回 content（回复）
                                content = delta.get("content", "")
                                reasoning = delta.get("reasoning_content", "")
                                if content:
                                    yield content
                                # reasoning_content 不输出给用户（思考过程）
                    except json.JSONDecodeError:
                        continue

    except httpx.TimeoutException:
        yield "[错误] 请求超时，请稍后重试"
    except Exception as e:
        yield f"[错误] {str(e)}"


def sse_event(data: dict) -> str:
    """格式化 SSE 事件"""
    return f"data: {json.dumps(data, ensure_ascii=False)}\n\n"
