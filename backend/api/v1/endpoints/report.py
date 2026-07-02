"""
报告接口 — AI 报告生成（带缓存）
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import get_db
from models.report import Report
from models.user import User
from schemas.report import ReportResponse
from services.ai_engine import generate_report
from core.deps import get_current_user
from core.response import ok

router = APIRouter(prefix="/report", tags=["报告"])


@router.get("/{city}")
async def get_report(
    city: str,
    year: int = Query(..., ge=2020, le=2035, description="报告年份"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取城市 AI 报告
    - 先查数据库缓存
    - 缓存未命中 → 调蓝心大模型生成 → 存入缓存
    """
    # 1. 查缓存
    result = await db.execute(
        select(Report).where(
            Report.city == city,
            Report.year == year,
            Report.role == user.role,
        )
    )
    cached = result.scalar_one_or_none()

    if cached:
        return ok(
            data=ReportResponse(
                city=cached.city,
                year=cached.year,
                content=cached.content,
                source=cached.source,
                cached=True,
            ).model_dump(),
            message="报告获取成功(缓存)",
        )

    # 2. 生成报告
    report = generate_report(city, year, role=user.role)
    if "error" in report:
        return ok(data=report, message=report["error"])

    # 3. 存缓存
    report_obj = Report(
        city=city,
        year=year,
        role=user.role,
        content=report["content"],
        source=report["source"],
    )
    db.add(report_obj)
    await db.commit()

    return ok(
        data=ReportResponse(
            city=city,
            year=year,
            content=report["content"],
            source=report["source"],
            cached=False,
        ).model_dump(),
        message="报告生成成功",
    )
