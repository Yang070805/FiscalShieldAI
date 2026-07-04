"""
预测接口 — 城市风险预测（带缓存）
"""

import json

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import get_db
from models.prediction import Prediction
from models.user import User
from schemas.prediction import PredictResponse
from services.ai_engine import predict_by_city, get_available_cities
from core.deps import get_current_user
from core.response import ok
from core.exceptions import ParamsError

router = APIRouter(prefix="/predict", tags=["预测"])


@router.get("/cities")
async def list_cities():
    """获取可用城市列表"""
    cities = get_available_cities()
    return ok(data=cities)


@router.get("/{city}")
async def predict_city(
    city: str,
    year: int = Query(..., ge=2020, le=2035, description="预测年份"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    城市风险预测
    - 先查数据库缓存（24小时内有效）
    - 缓存未命中 → 调 AI 引擎推理 → 结果存入缓存
    """
    # 输入验证
    if not city or not city.strip():
        raise ParamsError("城市名不能为空")
    city = city.strip()
    
    # 1. 查缓存
    result = await db.execute(
        select(Prediction).where(
            Prediction.city == city,
            Prediction.year == year,
            Prediction.role == user.role,
        )
    )
    cached = result.scalar_one_or_none()

    if cached:
        return ok(
            data=PredictResponse(
                city=cached.city,
                year=cached.year,
                risk_score=cached.risk_score,
                risk_level=cached.risk_level,
                trend=cached.trend,
                detail=json.loads(cached.detail_json),
                cached=True,
            ).model_dump(),
            message="预测成功(缓存)",
        )

    # 2. 调 AI 引擎
    pred = predict_by_city(city, year)
    if "error" in pred:
        return ok(data=pred, message=pred["error"])

    # 3. 存缓存
    prediction = Prediction(
        city=city,
        year=year,
        role=user.role,
        risk_score=pred["risk_score"],
        risk_level=pred["risk_level"],
        trend=pred["trend"],
        detail_json=json.dumps(pred.get("detail", {}), ensure_ascii=False),
    )
    db.add(prediction)
    await db.commit()

    return ok(
        data=PredictResponse(
            city=city,
            year=year,
            risk_score=pred["risk_score"],
            risk_level=pred["risk_level"],
            trend=pred["trend"],
            detail=pred.get("detail", {}),
            cached=False,
        ).model_dump(),
        message="预测成功",
    )
