"""
数据回流管道接口
===============

提供完整的数据清洗、验证、质量评分、去重、时间序列预处理功能。

流程：
    上传文件 → 字段映射 → Schema验证 → 清洗 → 去重 → 时间序列预处理 → 质量评分 → 入库

权限：gov / enterprise
"""

from __future__ import annotations

import io
import json
import os
import logging
from datetime import datetime

import pandas as pd
from fastapi import APIRouter, Depends, UploadFile, File, Query
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import get_db
from models.user import User
from models.prediction import Prediction
from models.upload import UploadRecord
from schemas.data_pipeline import (
    PipelineConfig,
    PipelineResultResponse,
    UploadWithPipelineResponse,
)
from core.deps import role_required
from core.response import ok
from core.exceptions import ParamsError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/pipeline", tags=["数据管道"])

ALLOWED_EXTENSIONS = {".xlsx", ".xls", ".csv"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB


@router.post("/upload")
async def upload_with_pipeline(
    file: UploadFile = File(...),
    city: str = Query(..., description="城市名称"),
    year: int = Query(..., ge=2000, le=2100, description="年份"),
    permission: str = Query("internal", description="数据权限: public/internal/private"),
    skip_dedup: bool = Query(False, description="是否跳过去重"),
    skip_ts: bool = Query(False, description="是否跳过时间序列预处理"),
    user: User = Depends(role_required("gov", "enterprise")),
    db: AsyncSession = Depends(get_db),
):
    """
    带完整管道的数据上传
    
    流程：
    1. 解析文件
    2. 字段映射（模糊匹配列名）
    3. Schema验证（类型/范围/空值）
    4. 数据清洗（13种规则）
    5. 去重（模糊匹配）
    6. 时间序列预处理（平滑+异常检测）
    7. 质量评分（4维加权）
    8. 可信度加权入库
    
    权限：gov / enterprise
    """
    # 1. 解析文件
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
    
    original_rows = len(df)
    
    # 2. 执行数据管道
    from services.data_pipeline import DataPipeline
    
    pipeline_config = {
        "max_null_rate": 0.3,
    }
    
    pipeline = DataPipeline(config=pipeline_config)
    result = pipeline.process(
        df=df,
        city=city,
        year=year,
        permission=permission,
        skip_dedup=skip_dedup,
        skip_ts=skip_ts,
    )
    
    if not result.success:
        raise ParamsError(result.message)
    
    processed_df = result.processed_data
    if processed_df is None or processed_df.empty:
        raise ParamsError("处理后数据为空")
    
    # 3. 入库
    inserted = 0
    for _, row in processed_df.iterrows():
        row_dict = row.to_dict()
        
        # 转换numpy类型为Python原生类型
        row_dict = {
            k: (v.item() if hasattr(v, 'item') else v)
            for k, v in row_dict.items()
        }
        
        # 提取风险评分（如果有）
        risk_score = _extract_float(row_dict, ["risk_score", "风险评分", "score"], 50.0)
        risk_level = _extract_str(row_dict, ["risk_level", "风险等级", "level"], "medium")
        trend = _extract_str(row_dict, ["trend", "趋势"], "stable")
        
        prediction = Prediction(
            city=city,
            year=year,
            role=user.role,
            risk_score=risk_score,
            risk_level=risk_level,
            trend=trend,
            detail_json=json.dumps(row_dict, ensure_ascii=False, default=str),
        )
        db.add(prediction)
        inserted += 1
    
    # 记录上传
    record = UploadRecord(
        user_id=user.id,
        city=city,
        year=year,
        filename=filename,
        rows=original_rows,
        cols=len(df.columns),
        status="confirmed",
    )
    db.add(record)
    
    await db.commit()
    
    # 4. 如果包含训练回流，触发训练
    training_triggered = False
    if '+training' in permission:
        try:
            from services.training_pipeline import start_training
            start_training(epochs=50, incremental=True)
            training_triggered = True
        except Exception as e:
            logger.warning(f"训练触发失败: {e}")
    
    # 5. 构建响应
    pipeline_response = PipelineResultResponse(
        success=result.success,
        message=result.message,
        original_rows=result.original_rows,
        cleaned_rows=result.cleaned_rows,
        removed_rows=result.removed_rows,
        quality_score=result.quality_score,
        confidence_weight=result.confidence_weight,
        field_mappings=result.field_mappings,
        validation_errors=result.validation_errors,
        cleaning_stats=result.cleaning_stats,
        quality_report=result.quality_report,
        dedup_stats=result.dedup_stats,
        ts_stats=result.ts_stats,
        warnings=result.warnings,
    )
    
    return ok(
        data=UploadWithPipelineResponse(
            filename=filename,
            rows=original_rows,
            cols=len(df.columns),
            pipeline_result=pipeline_response,
            inserted=inserted,
            training_triggered=training_triggered,
        ).model_dump(),
        message=f"数据处理完成，入库 {inserted} 条，质量评分 {result.quality_score:.2f}",
    )


@router.post("/validate")
async def validate_file(
    file: UploadFile = File(...),
    user: User = Depends(role_required("gov", "enterprise")),
):
    """
    仅验证文件（不入库）
    
    返回：字段映射、验证结果、质量评分、清洗统计
    """
    filename = file.filename or "unknown"
    ext = os.path.splitext(filename.lower())[1]
    if ext not in ALLOWED_EXTENSIONS:
        raise ParamsError(f"不支持的文件格式: {ext}")
    
    content = await file.read()
    if not content:
        raise ParamsError("文件为空")
    
    try:
        if ext in [".xlsx", ".xls"]:
            df = pd.read_excel(io.BytesIO(content))
        else:
            df = pd.read_csv(io.BytesIO(content))
    except Exception as e:
        raise ParamsError(f"文件解析失败: {str(e)}")
    
    from services.data_pipeline import DataPipeline
    
    pipeline = DataPipeline()
    
    # 字段映射
    df_mapped, mappings = pipeline.mapper.map_columns(df)
    
    # Schema验证
    is_valid, errors = pipeline.validator.validate(df_mapped)
    
    # 质量评分
    quality_report = pipeline.scorer.score(df_mapped, validation_errors=errors)
    
    # 映射报告
    mapping_report = pipeline.mapper.get_mapping_report(df)
    
    return ok(data={
        "filename": filename,
        "rows": len(df),
        "cols": len(df.columns),
        "is_valid": is_valid,
        "field_mappings": mappings,
        "mapping_report": mapping_report,
        "validation_errors": errors,
        "quality_score": quality_report.get("total_score", 0),
        "quality_report": quality_report,
    })


@router.get("/contract")
async def get_data_contract(
    user: User = Depends(role_required("gov", "enterprise")),
):
    """
    获取数据契约（YAML格式）
    
    定义标准字段、类型、范围、别名等。
    """
    from services.data_pipeline.validation import SchemaValidator
    
    validator = SchemaValidator()
    contract = validator.generate_contract()
    
    return ok(data=contract)


@router.get("/quality-report")
async def quality_report(
    city: str = Query(None, description="筛选城市"),
    year: int = Query(None, description="筛选年份"),
    user: User = Depends(role_required("gov")),
    db: AsyncSession = Depends(get_db),
):
    """
    获取已入库数据的质量报告
    
    权限：仅 gov
    """
    from sqlalchemy import select
    
    query = select(Prediction).where(Prediction.role == "gov")
    if city:
        query = query.where(Prediction.city == city)
    if year:
        query = query.where(Prediction.year == year)
    query = query.order_by(Prediction.created_at.desc()).limit(1000)
    
    result = await db.execute(query)
    predictions = result.scalars().all()
    
    if not predictions:
        return ok(data={"message": "暂无数据", "total": 0})
    
    # 转为DataFrame进行分析
    records = []
    for p in predictions:
        detail = json.loads(p.detail_json) if p.detail_json else {}
        records.append(detail)
    
    df = pd.DataFrame(records)
    
    from services.data_pipeline import DataPipeline
    
    pipeline = DataPipeline()
    quality_report = pipeline.scorer.score(df)
    
    return ok(data={
        "total_records": len(predictions),
        "quality_report": quality_report,
    })


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
