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

你拥有该城市多年的实际财政数据和模型预测数据。回答时要引用具体数据，
告诉用户你已经拥有哪些年份的数据。如果用户问的年份在数据范围内，
直接基于数据分析；如果超出范围，说明数据可用范围并给出最近可用年份的分析。"""


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

    # 添加上下文（含预测数据）
    context_parts = []
    if city:
        context_parts.append(f"当前分析城市：{city}")
    if year:
        context_parts.append(f"数据年份：{year}")
    if context_parts:
        messages.append({"role": "system", "content": "\n".join(context_parts)})

    # 如果有城市，自动查询预测数据注入上下文
    if city:
        try:
            from services.ai_engine import predict_by_city, AI_ENGINE_DIR
            import pandas as pd

            # 1. 查指定年份的预测数据
            target_year = year or 2026
            pred = predict_by_city(city, target_year)
            print(f"[llm_chat] city={city}, year={target_year}, pred_error={'error' in pred if isinstance(pred, dict) else 'N/A'}")
            if "error" not in pred:
                data_text = json.dumps(pred, ensure_ascii=False, indent=2)
                messages.append({
                    "role": "system",
                    "content": f"以下是{city} {target_year}年的财政风险预测数据，请基于此数据回答用户问题：\n{data_text}",
                })
                print(f"[llm_chat] 注入{target_year}年预测数据成功")

            # 2. 读取该城市所有可用年份的实际数据（最近5年摘要）
            data_file = AI_ENGINE_DIR / "data" / f"{city}_data.xlsx"
            if data_file.exists():
                df = pd.read_excel(str(data_file))
                available_years = sorted(df["年份"].unique())
                recent_years = available_years[-5:]  # 最近5年
                summary_lines = [f"{city}可用数据年份: {', '.join(str(y) for y in available_years)}"]
                for y in recent_years:
                    row = df[df["年份"] == y]
                    if not row.empty:
                        vals = row.iloc[0].to_dict()
                        # 只保留数值列，去掉年份本身
                        numeric = {k: round(v, 2) if isinstance(v, (int, float)) else v for k, v in vals.items() if k != "年份" and isinstance(v, (int, float))}
                        summary_lines.append(f"{y}年: {json.dumps(numeric, ensure_ascii=False)}")
                summary = "\n".join(summary_lines)
                messages.append({
                    "role": "system",
                    "content": f"以下是{city}的历史财政数据摘要，请结合数据回答用户关于各年份的问题：\n{summary}",
                })
                print(f"[llm_chat] 注入{city}历史数据成功，年份={recent_years}")
        except Exception as e:
            print(f"[llm_chat] 查询数据失败: {e}")
    else:
        print(f"[llm_chat] 未注入数据: city={city}, year={year}")

    # 添加历史对话
    if history:
        for msg in history[-8:]:  # 最近8条
            messages.append({"role": msg["role"], "content": msg["content"]})

    # 添加当前消息
    messages.append({"role": "user", "content": message})

    # 调试日志：打印发给LLM的消息数和每条role
    print(f"[llm_chat] 发给LLM {len(messages)} 条消息: {[m['role'] for m in messages]}")
    for i, m in enumerate(messages):
        content_preview = m['content'][:80] if len(m['content']) > 80 else m['content']
        print(f"  [{i}] {m['role']}: {content_preview}")

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
