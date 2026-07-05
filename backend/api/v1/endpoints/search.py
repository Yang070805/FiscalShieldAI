"""
搜索 / 收藏 / 推荐接口
"""

import json
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_

from db.session import get_db
from models.user import User
from models.prediction import Prediction
from models.favorite import Favorite
from services.ai_engine import get_available_cities
from core.deps import get_current_user
from core.response import ok
from core.exceptions import ParamsError

router = APIRouter(prefix="/search", tags=["搜索收藏推荐"])


# ==================== 搜索 ====================

@router.get("")
async def search(
    q: str = Query(..., min_length=1, description="搜索关键词"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    搜索城市/预测记录
    - 匹配城市名
    - 匹配风险等级
    """
    # 搜索可用城市
    cities = get_available_cities()
    matched_cities = [c for c in cities if q in c]

    # 搜索预测记录
    query = select(Prediction).where(
        or_(
            Prediction.city.ilike(f"%{q}%"),
            Prediction.risk_level.ilike(f"%{q}%"),
        )
    )
    # 公民只看公开数据
    if user.role == "citizen":
        query = query.where(Prediction.permission == "public")
    query = query.order_by(Prediction.created_at.desc()).limit(20)
    result = await db.execute(query)
    predictions = result.scalars().all()

    return ok(data={
        "cities": matched_cities,
        "predictions": [
            {
                "id": p.id,
                "city": p.city,
                "year": p.year,
                "risk_score": p.risk_score,
                "risk_level": p.risk_level,
                "trend": p.trend,
            }
            for p in predictions
        ],
    })


# ==================== 收藏 ====================

@router.post("/favorite/{city}")
async def add_favorite(
    city: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """收藏城市"""
    # 检查城市是否存在
    cities = get_available_cities()
    if city not in cities:
        raise ParamsError(f"城市 {city} 不在可用列表中")

    # 检查是否已收藏
    result = await db.execute(
        select(Favorite).where(Favorite.user_id == user.id, Favorite.city == city)
    )
    if result.scalar_one_or_none():
        raise ParamsError("已收藏该城市")

    fav = Favorite(user_id=user.id, city=city)
    db.add(fav)
    await db.commit()
    return ok(message=f"已收藏 {city}")


@router.delete("/favorite/{city}")
async def remove_favorite(
    city: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """取消收藏"""
    result = await db.execute(
        select(Favorite).where(Favorite.user_id == user.id, Favorite.city == city)
    )
    fav = result.scalar_one_or_none()
    if not fav:
        raise ParamsError("未收藏该城市")

    await db.delete(fav)
    await db.commit()
    return ok(message=f"已取消收藏 {city}")


@router.get("/favorites")
async def list_favorites(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取收藏列表（含关注数）"""
    result = await db.execute(
        select(Favorite)
        .where(Favorite.user_id == user.id)
        .order_by(Favorite.created_at.desc())
    )
    favorites = result.scalars().all()

    # 统计每个城市的关注数
    fav_cities = [f.city for f in favorites]
    city_counts = {}
    if fav_cities:
        count_result = await db.execute(
            select(Favorite.city, func.count(Favorite.id).label("count"))
            .where(Favorite.city.in_(fav_cities))
            .group_by(Favorite.city)
        )
        for row in count_result.all():
            city_counts[row[0]] = row[1]

    return ok(data=[{"city": f.city, "count": city_counts.get(f.city, 0), "created_at": f.created_at.isoformat()} for f in favorites])


# ==================== 推荐 ====================

@router.get("/recommend")
async def recommend(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    推荐城市
    - 热度排行：预测次数最多的城市
    - 地区推荐：基于用户角色
    """
    # 热度排行：按预测次数降序
    result = await db.execute(
        select(Prediction.city, func.count(Prediction.id).label("count"))
        .group_by(Prediction.city)
        .order_by(func.count(Prediction.id).desc())
        .limit(10)
    )
    hot_cities = [{"city": row[0], "count": row[1]} for row in result.all()]

    # 所有可用城市
    all_cities = get_available_cities()

    # 推荐：热度城市 + 未预测过的城市
    predicted_cities = {h["city"] for h in hot_cities}
    new_cities = [c for c in all_cities if c not in predicted_cities][:5]

    return ok(data={
        "hot": hot_cities,
        "new": new_cities,
        "all": all_cities,
    })
