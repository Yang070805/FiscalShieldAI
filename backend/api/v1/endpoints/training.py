"""
训练接口 — 神经网络训练回流
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import get_db
from models.user import User
from core.deps import role_required
from core.response import ok
from services.training_pipeline import start_training, get_training_status, get_training_history

router = APIRouter(prefix="/training", tags=["训练"])


@router.post("/start")
async def start_model_training(
    epochs: int = Query(50, ge=10, le=200, description="训练轮数"),
    incremental: bool = Query(True, description="是否增量训练"),
    user: User = Depends(role_required("gov")),
):
    """
    触发模型训练
    权限：仅 gov

    - 读取数据库中 role='gov' 的上传数据
    - 训练 LightTCNCompact 模型
    - 训练完成后更新 checkpoints/best_student_model.pth
    """
    result = start_training(epochs=epochs, incremental=incremental)
    return ok(data=result, message=result.get("message", "训练已启动"))


@router.get("/status")
async def training_status(
    user: User = Depends(role_required("gov")),
):
    """
    查看训练状态
    权限：仅 gov
    """
    status = get_training_status()
    return ok(data=status)


@router.get("/history")
async def training_history(
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(role_required("gov")),
    db: AsyncSession = Depends(get_db),
):
    """
    训练历史
    权限：仅 gov
    """
    history = await get_training_history(db, limit=limit)
    return ok(data=history)
