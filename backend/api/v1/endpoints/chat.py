"""
对话接口 — AI 对话 + SSE 流式 + 对话历史
"""

import json
from datetime import datetime

from fastapi import APIRouter, Depends, Header
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import get_db
from models.user import User
from models.chat import Chat, ChatMessage
from schemas.chat import ChatRequest, ChatListItem, ChatDetail, ChatMessageItem
from services.llm_chat import call_llm_stream, sse_event
from core.deps import get_current_user
from core.response import ok

router = APIRouter(prefix="/chat", tags=["对话"])


@router.post("")
async def chat(
    req: ChatRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
    x_ai_model: str = Header(None, alias="X-AI-Model"),
    x_ai_app_id: str = Header(None, alias="X-AI-App-ID"),
):
    """
    AI 对话（SSE 流式响应）
    - 传 chat_id 继续已有对话
    - 不传 chat_id 自动新建对话
    - 返回 SSE 事件流：start → chunk... → done
    """
    # 1. 获取或创建对话
    if req.chat_id:
        result = await db.execute(
            select(Chat).where(Chat.id == req.chat_id, Chat.user_id == user.id)
        )
        chat_obj = result.scalar_one_or_none()
        if not chat_obj:
            return ok(message="对话不存在", data=None)
    else:
        chat_obj = Chat(
            user_id=user.id,
            title=req.message[:50],
        )
        db.add(chat_obj)
        await db.commit()
        await db.refresh(chat_obj)

    chat_id = chat_obj.id

    # 2. 保存用户消息
    user_msg = ChatMessage(
        chat_id=chat_id,
        role="user",
        content=req.message,
        model=req.model,
    )
    db.add(user_msg)
    await db.commit()

    # 3. 获取历史消息（最近10条）
    history_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.chat_id == chat_id)
        .order_by(ChatMessage.id.desc())
        .limit(10)
    )
    history_rows = history_result.scalars().all()
    history = [{"role": m.role, "content": m.content} for m in reversed(history_rows)]

    # 4. 保存当前城市/年份信息到对话标题
    if req.city and req.year and chat_obj.title == "新对话":
        chat_obj.title = f"{req.city} {req.year}年财政分析"
        await db.commit()

    # 5. 返回 SSE 流式响应
    return StreamingResponse(
        _chat_stream(chat_id, req.message, history, req.city, req.year, user.role, req.model, db,
                    api_key=x_ai_api_key, provider=x_ai_model, app_id=x_ai_app_id),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
    )


async def _chat_stream(
    chat_id: int,
    message: str,
    history: list,
    city: str,
    year: int,
    role: str,
    model: str,
    db: AsyncSession,
    api_key: str = None,
    provider: str = None,
    app_id: str = None,
):
    """SSE 流式生成器"""
    yield sse_event({"type": "start", "chat_id": chat_id})

    full_response = ""
    try:
        async for chunk in call_llm_stream(message, history, city, year, role, provider or model, api_key=api_key, app_id=app_id):
            full_response += chunk
            yield sse_event({"type": "chunk", "content": chunk})

        yield sse_event({"type": "done", "chat_id": chat_id})

    except Exception as e:
        yield sse_event({"type": "error", "message": str(e)})

    # 6. 保存 AI 回复
    if full_response:
        assistant_msg = ChatMessage(
            chat_id=chat_id,
            role="assistant",
            content=full_response,
            model=model,
        )
        db.add(assistant_msg)
        # 更新对话时间
        result = await db.execute(select(Chat).where(Chat.id == chat_id))
        chat_obj = result.scalar_one_or_none()
        if chat_obj:
            chat_obj.updated_at = datetime.now()
        await db.commit()


@router.get("/list")
async def chat_list(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取用户的对话列表"""
    result = await db.execute(
        select(Chat)
        .where(Chat.user_id == user.id)
        .order_by(Chat.updated_at.desc())
        .limit(50)
    )
    chats = result.scalars().all()
    return ok(data=[ChatListItem.model_validate(c).model_dump() for c in chats])


@router.get("/{chat_id}")
async def chat_detail(
    chat_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取对话详情（含消息历史）"""
    # 验证对话归属
    result = await db.execute(
        select(Chat).where(Chat.id == chat_id, Chat.user_id == user.id)
    )
    chat_obj = result.scalar_one_or_none()
    if not chat_obj:
        return ok(message="对话不存在", data=None)

    # 获取消息
    msg_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.chat_id == chat_id)
        .order_by(ChatMessage.id)
    )
    messages = msg_result.scalars().all()

    return ok(
        data=ChatDetail(
            id=chat_obj.id,
            title=chat_obj.title,
            messages=[ChatMessageItem.model_validate(m) for m in messages],
            created_at=chat_obj.created_at,
        ).model_dump()
    )


@router.delete("/{chat_id}")
async def chat_delete(
    chat_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除对话"""
    result = await db.execute(
        select(Chat).where(Chat.id == chat_id, Chat.user_id == user.id)
    )
    chat_obj = result.scalar_one_or_none()
    if not chat_obj:
        return ok(message="对话不存在", data=None)

    await db.delete(chat_obj)
    await db.commit()
    return ok(message="对话已删除")
