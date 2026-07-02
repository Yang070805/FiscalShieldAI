"""
数据上传接口 — 政务/企业上传城市数据
"""

import io
import json
import os
from datetime import datetime

import pandas as pd
from fastapi import APIRouter, Depends, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import get_db
from models.user import User
from models.prediction import Prediction
from models.upload import UploadRecord
from schemas.upload import UploadPreview, UploadConfirmRequest, UploadHistoryItem
from core.deps import role_required
from core.response import ok
from core.exceptions import ParamsError

router = APIRouter(prefix="/upload", tags=["数据上传"])

ALLOWED_EXTENSIONS = {".xlsx", ".xls", ".csv"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB


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
    # 验证文件格式
    filename = file.filename or "unknown"
    ext = os.path.splitext(filename.lower())[1]
    if ext not in ALLOWED_EXTENSIONS:
        raise ParamsError(f"不支持的文件格式: {ext}，仅支持 {', '.join(ALLOWED_EXTENSIONS)}")

    # 读取文件
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


@router.post("/confirm")
async def upload_confirm(
    req: UploadConfirmRequest,
    user: User = Depends(role_required("gov", "enterprise")),
    db: AsyncSession = Depends(get_db),
):
    """
    确认数据入库
    权限：gov / enterprise
    """
    if not req.data:
        raise ParamsError("数据为空")

    # 验证权限值
    valid_permissions = ("public", "internal", "private")
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
        # 尝试从行数据中提取风险指标
        risk_score = _extract_float(row, ["risk_score", "风险评分", "score"], 50.0)
        risk_level = _extract_str(row, ["risk_level", "风险等级", "level"], "medium")
        trend = _extract_str(row, ["trend", "趋势"], "stable")

        prediction = Prediction(
            city=req.city,
            year=req.year,
            role=user.role,
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
        record.status = "confirmed"

    await db.commit()

    return ok(
        data={"inserted": inserted, "city": req.city, "year": req.year},
        message=f"成功入库 {inserted} 条数据",
    )


@router.get("/history")
async def upload_history(
    user: User = Depends(role_required("gov", "enterprise")),
    db: AsyncSession = Depends(get_db),
):
    """获取上传历史"""
    result = await db.execute(
        select(UploadRecord)
        .where(UploadRecord.user_id == user.id)
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
            "created_at": r.created_at.isoformat(),
        }
        for r in records
    ])


# ==================== 工具函数 ====================

def _extract_float(row: dict, keys: list, default: float) -> float:
    """从行数据中提取浮点值"""
    for key in keys:
        if key in row:
            try:
                return float(row[key])
            except (ValueError, TypeError):
                continue
    return default


def _extract_str(row: dict, keys: list, default: str) -> str:
    """从行数据中提取字符串值"""
    for key in keys:
        if key in row:
            return str(row[key])
    return default
