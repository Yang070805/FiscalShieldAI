"""
数据上传接口 — 政务/企业上传城市数据 + 权限分级 + 训练回流
"""

import io
import json
import os
from datetime import datetime

import pandas as pd
from fastapi import APIRouter, Depends, UploadFile, File, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from db.session import get_db
from models.user import User
from models.prediction import Prediction
from models.upload import UploadRecord
from schemas.upload import UploadPreview, UploadConfirmRequest, UploadHistoryItem
from core.deps import role_required, get_current_user
from core.response import ok
from core.exceptions import ParamsError

router = APIRouter(prefix="/upload", tags=["数据上传"])

ALLOWED_EXTENSIONS = {".xlsx", ".xls", ".csv"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB


# ==================== 上传预览 ====================

@router.post("/preview")
async def upload_preview(
    file: UploadFile = File(...),
    user: User = Depends(role_required("gov", "enterprise")),
    db: AsyncSession = Depends(get_db),
):
    """
    上传 Excel/CSV 文件，返回数据分析预览（不入库）
    权限：gov / enterprise
    """
    filename = file.filename or "unknown"
    ext = os.path.splitext(filename.lower())[1]
    if ext not in ALLOWED_EXTENSIONS:
        raise ParamsError(f"不支持的文件格式: {ext}，仅支持 {', '.join(ALLOWED_EXTENSIONS)}")

    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise ParamsError(f"文件过大，最大 {MAX_FILE_SIZE // 1024 // 1024}MB")
    if not content:
        raise ParamsError("文件为空")

    try:
        if ext in [".xlsx", ".xls"]:
            df = pd.read_excel(io.BytesIO(content))
        else:
            df = pd.read_csv(io.BytesIO(content))
    except Exception as e:
        raise ParamsError(f"文件解析失败: {str(e)}")

    # 数据分析
    columns = [{"name": str(c), "dtype": str(df[c].dtype)} for c in df.columns]
    missing = {str(k): int(v) for k, v in df.isna().sum().items() if v > 0}

    # 数值列统计
    numeric_cols = df.select_dtypes(include=["number"]).columns.tolist()
    stats = {}
    if numeric_cols:
        desc = df[numeric_cols].describe()
        for col in numeric_cols:
            stats[col] = {
                "mean": round(float(desc[col]["mean"]), 2) if not pd.isna(desc[col]["mean"]) else None,
                "min": round(float(desc[col]["min"]), 2) if not pd.isna(desc[col]["min"]) else None,
                "max": round(float(desc[col]["max"]), 2) if not pd.isna(desc[col]["max"]) else None,
                "std": round(float(desc[col]["std"]), 2) if not pd.isna(desc[col]["std"]) else None,
            }

    # 预览前20行
    preview = df.head(20).fillna("").astype(str).to_dict(orient="records")

    # 记录上传记录
    record = UploadRecord(
        user_id=user.id,
        city="",
        year=0,
        filename=filename,
        rows=len(df),
        cols=len(df.columns),
        status="pending",
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    return ok(
        data=UploadPreview(
            filename=filename,
            rows=len(df),
            cols=len(df.columns),
            columns=columns,
            missing=missing,
            preview=preview,
            stats=stats,
        ).model_dump(),
        message="数据分析完成，请确认后入库",
    )


# ==================== 确认入库 ====================

@router.post("/confirm")
async def upload_confirm(
    req: UploadConfirmRequest,
    user: User = Depends(role_required("gov", "enterprise")),
    db: AsyncSession = Depends(get_db),
):
    """
    确认数据入库
    权限：gov / enterprise
    
    permission 说明：
    - public:   公开，民用端可在仪表盘查看
    - internal: 内部使用，仅政务/企业端可见
    - public+training:   公开 + 训练回流
    - internal+training: 内部 + 训练回流
    """
    if not req.data:
        raise ParamsError("数据为空")

    valid_permissions = ("public", "internal", "public+training", "internal+training")
    if req.permission not in valid_permissions:
        raise ParamsError(f"权限必须是: {', '.join(valid_permissions)}")

    # 查找最近的 pending 上传记录
    result = await db.execute(
        select(UploadRecord)
        .where(UploadRecord.user_id == user.id, UploadRecord.status == "pending")
        .order_by(UploadRecord.created_at.desc())
        .limit(1)
    )
    record = result.scalar_one_or_none()

    # 批量写入预测数据
    inserted = 0
    for row in req.data:
        risk_score = _extract_float(row, ["risk_score", "风险评分", "score"], 50.0)
        risk_level = _extract_str(row, ["risk_level", "风险等级", "level"], "medium")
        trend = _extract_str(row, ["trend", "趋势"], "stable")

        prediction = Prediction(
            city=req.city,
            year=req.year,
            role=user.role,
            permission=req.permission.split('+')[0],  # 存基础权限
            risk_score=risk_score,
            risk_level=risk_level,
            trend=trend,
            detail_json=json.dumps(row, ensure_ascii=False),
        )
        db.add(prediction)
        inserted += 1

    # 更新上传记录
    if record:
        record.city = req.city
        record.year = req.year
        record.permission = req.permission
        record.status = "confirmed"

    await db.commit()

    # 如果包含训练回流，自动触发训练
    training_needed = '+training' in req.permission
    training_result = None
    if training_needed:
        try:
            from services.training_pipeline import start_training
            training_result = start_training(epochs=50, incremental=True)
        except Exception as e:
            training_result = {"error": str(e)}

    return ok(
        data={
            "inserted": inserted,
            "city": req.city,
            "year": req.year,
            "permission": req.permission,
            "training_needed": training_needed,
            "training_result": training_result,
        },
        message=f"成功入库 {inserted} 条数据" + ("，训练已自动触发" if training_needed else ""),
    )


# ==================== 上传历史 ====================

@router.get("/history")
async def upload_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取上传历史 — gov/enterprise看自己的，citizen看所有公开的"""
    if user.role in ("gov", "enterprise"):
        result = await db.execute(
            select(UploadRecord)
            .where(UploadRecord.user_id == user.id)
            .order_by(UploadRecord.created_at.desc())
            .limit(50)
        )
    else:
        # citizen 只能看已确认的记录
        result = await db.execute(
            select(UploadRecord)
            .where(UploadRecord.status == "confirmed")
            .order_by(UploadRecord.created_at.desc())
            .limit(50)
        )
    records = result.scalars().all()
    return ok(data=[
        {
            "id": r.id,
            "city": r.city,
            "year": r.year,
            "filename": r.filename,
            "rows": r.rows,
            "cols": r.cols,
            "status": r.status,
            "created_at": r.created_at.isoformat() if r.created_at else "",
        }
        for r in records
    ])


# ==================== 公开数据（民用端） ====================

@router.get("/public-data")
async def public_data(
    city: str = Query(None, description="筛选城市"),
    year: int = Query(None, description="筛选年份"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取公开数据 — 民用端仪表盘展示
    只返回 role='gov' 上传的、risk_score 非默认值的数据
    """
    query = select(Prediction).where(
        Prediction.role == "gov",
        Prediction.permission == "public",
    )

    if city:
        query = query.where(Prediction.city == city)
    if year:
        query = query.where(Prediction.year == year)

    query = query.order_by(Prediction.created_at.desc()).limit(100)
    result = await db.execute(query)
    predictions = result.scalars().all()

    return ok(data=[
        {
            "city": p.city,
            "year": p.year,
            "risk_score": p.risk_score,
            "risk_level": p.risk_level,
            "trend": p.trend,
            "created_at": p.created_at.isoformat() if p.created_at else "",
        }
        for p in predictions
    ])


# ==================== 训练数据（内部） ====================

@router.get("/training-data")
async def training_data(
    user: User = Depends(role_required("gov")),
    db: AsyncSession = Depends(get_db),
):
    """
    获取训练回流数据 — 用于优化 ST-GNN→LightTCN 模型
    权限：仅 gov
    """
    result = await db.execute(
        select(Prediction)
        .where(Prediction.role == "gov")
        .order_by(Prediction.created_at.desc())
        .limit(1000)
    )
    predictions = result.scalars().all()

    # 统计信息
    total = len(predictions)
    cities = list(set(p.city for p in predictions))
    years = list(set(p.year for p in predictions))

    return ok(data={
        "total": total,
        "cities": cities,
        "years": sorted(years),
        "records": [
            {
                "city": p.city,
                "year": p.year,
                "risk_score": p.risk_score,
                "risk_level": p.risk_level,
                "trend": p.trend,
                "detail": json.loads(p.detail_json) if p.detail_json else {},
            }
            for p in predictions
        ],
    })


# ==================== 城市统计数据 ====================

@router.get("/city-stats")
async def city_stats(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取各城市的上传统计"""
    result = await db.execute(
        select(
            Prediction.city,
            func.count(Prediction.id).label("count"),
            func.avg(Prediction.risk_score).label("avg_score"),
        )
        .group_by(Prediction.city)
        .order_by(func.count(Prediction.id).desc())
    )
    rows = result.all()

    return ok(data=[
        {
            "city": row[0],
            "count": row[1],
            "avg_score": round(float(row[2]), 1) if row[2] else None,
        }
        for row in rows
    ])


# ==================== 工具函数 ====================

def _extract_float(row: dict, keys: list, default: float) -> float:
    for key in keys:
        if key in row:
            try:
                return float(row[key])
            except (ValueError, TypeError):
                continue
    return default


def _extract_str(row: dict, keys: list, default: str) -> str:
    for key in keys:
        if key in row:
            return str(row[key])
    return default
