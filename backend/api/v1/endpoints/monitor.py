"""
风险监控接口 — 扫描、告警、概览
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from db.session import get_db
from models.user import User
from core.deps import role_required, get_current_user
from core.response import ok
from services.risk_monitor import scan_city, scan_all, get_alerts, get_overview, save_alerts

router = APIRouter(prefix="/monitor", tags=["风险监控"])


@router.get("/scan")
async def trigger_scan(
    city: Optional[str] = Query(None, description="指定城市（为空则扫描全部）"),
    user: User = Depends(role_required("gov")),
    db: AsyncSession = Depends(get_db),
):
    """
    触发风险扫描
    权限：仅 gov
    """
    if city:
        result = await scan_city(city, db)
        # 保存告警
        if result["alerts"]:
            await save_alerts(result["alerts"], db)
        return ok(data=result, message=f"扫描完成: {city} ({result['status']})")
    else:
        result = await scan_all(db)
        # 保存所有告警
        all_alerts = []
        for r in result["results"]:
            all_alerts.extend(r["alerts"])
        if all_alerts:
            await save_alerts(all_alerts, db)
        return ok(data=result, message=f"批量扫描完成: {result['summary']}")


@router.get("/alerts")
async def list_alerts(
    city: Optional[str] = Query(None, description="筛选城市"),
    level: Optional[str] = Query(None, description="筛选级别: info/warning/critical"),
    resolved: Optional[bool] = Query(None, description="是否已处理"),
    limit: int = Query(50, ge=1, le=200),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取告警列表
    权限：所有登录用户
    """
    alerts = await get_alerts(db, city=city, level=level, resolved=resolved, limit=limit)
    return ok(data=alerts)


@router.get("/overview")
async def monitor_overview(
    user: User = Depends(role_required("gov")),
    db: AsyncSession = Depends(get_db),
):
    """
    监控概览
    权限：仅 gov
    """
    overview = await get_overview(db)
    return ok(data=overview)
