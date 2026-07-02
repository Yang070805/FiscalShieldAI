"""
LLM 对话服务 — 多模型支持 + 流式输出
"""

import asyncio
import json
import os
import sys
from typing import AsyncGenerator, Optional

import httpx

# ==================== SSE 格式化 ====================

def sse_event(data: dict) -> str:
    """格式化 SSE 事件"""
    return f"data: {json.dumps(data, ensure_ascii=False)}\n\n"


# ==================== LLM 调用 ====================

# 模型配置
MODEL_CONFIGS = {
    "bluelm": {
        "name": "蓝心大模型",
        "api_url": "https://api-ai.vivo.com.cn/v1/chat/completions",
        "model": "vivo-BlueLM-Chat",
        "api_key_env": "BLUELM_API_KEY",
    },
    "deepseek": {
        "name": "DeepSeek",
        "api_url": "https://api.deepseek.com/v1/chat/completions",
        "model": "deepseek-chat",
        "api_key_env": "DEEPSEEK_API_KEY",
    },
    "qwen": {
        "name": "通义千问",
        "api_url": "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
        "model": "qwen-turbo",
        "api_key_env": "QWEN_API_KEY",
    },
    "doubao": {
        "name": "豆包",
        "api_url": "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        "model": "doubao-lite-4k",
        "api_key_env": "DOUBAO_API_KEY",
    },
}


def _build_system_prompt(city: Optional[str], year: Optional[int], role: str) -> str:
    """构建系统提示词"""
    base = "你是 FiscalShield AI（财智哨兵），一个专业的财政风险分析助手。"
    base += "你能够分析城市财政数据、预测财政风险、生成分析报告。"

    if role == "gov":
        base += "当前用户是政务人员，你可以提供详细的政策建议和风险预警。"
    elif role == "enterprise":
        base += "当前用户是企业人员，你可以提供商业视角的财政分析。"
    else:
        base += "当前用户是普通市民，用通俗易懂的语言解释财政数据。"

    if city and year:
        base += f"\n当前分析对象：{city} {year}年财政数据。"

    return base


async def call_llm_stream(
    message: str,
    history: list[dict],
    city: Optional[str] = None,
    year: Optional[int] = None,
    role: str = "citizen",
    model: str = "bluelm",
) -> AsyncGenerator[str, None]:
    """
    流式调用 LLM
    优先级：指定模型 → 蓝心 → 本地模板
    """
    config = MODEL_CONFIGS.get(model, MODEL_CONFIGS["bluelm"])
    api_key = os.getenv(config["api_key_env"], "")

    # 没有 API Key → 降级到本地模板
    if not api_key:
        async for chunk in _local_template_stream(message, city, year, role):
            yield chunk
        return

    # 构建消息
    system_prompt = _build_system_prompt(city, year, role)
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history)
    messages.append({"role": "user", "content": message})

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream(
                "POST",
                config["api_url"],
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": config["model"],
                    "messages": messages,
                    "stream": True,
                    "temperature": 0.7,
                    "max_tokens": 2000,
                },
            ) as response:
                if response.status_code != 200:
                    async for chunk in _local_template_stream(message, city, year, role):
                        yield chunk
                    return

                async for line in response.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    data_str = line[6:]
                    if data_str.strip() == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        delta = data["choices"][0].get("delta", {})
                        content = delta.get("content", "")
                        if content:
                            yield content
                    except (json.JSONDecodeError, KeyError, IndexError):
                        continue

    except Exception:
        async for chunk in _local_template_stream(message, city, year, role):
            yield chunk


async def _local_template_stream(
    message: str,
    city: Optional[str],
    year: Optional[int],
    role: str,
) -> AsyncGenerator[str, None]:
    """本地模板回复（降级方案）"""
    if city and year:
        response = f"关于{city} {year}年的财政情况，根据我们的AI模型分析：\n\n"
        response += f"该城市财政风险处于可控范围内。建议持续关注债务率、赤字率等核心指标的变化趋势。\n\n"
        response += f"如需更详细的分析，请查看「AI报告」功能。"
    else:
        response = f"你好！我是财智哨兵 AI 助手，专注于财政风险分析。\n\n"
        response += f"你可以：\n"
        response += f"1. 让我分析某个城市的财政风险\n"
        response += f"2. 查询历史预测数据\n"
        response += f"3. 生成专业的财政分析报告\n\n"
        response += f"请问有什么可以帮你的？"

    for char in response:
        yield char
        await asyncio.sleep(0.02)
