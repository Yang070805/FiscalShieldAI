"""
数据管道 API Schema
==================

Pydantic模型定义，用于API请求/响应验证。
"""

from __future__ import annotations

from pydantic import BaseModel, Field
from typing import Any


class PipelineConfig(BaseModel):
    """管道配置"""
    skip_dedup: bool = Field(False, description="是否跳过去重")
    skip_ts: bool = Field(False, description="是否跳过时间序列预处理")
    similarity_threshold: float = Field(85.0, ge=50, le=100, description="去重相似度阈值")
    sigma_threshold: float = Field(3.0, ge=1, le=5, description="异常检测σ阈值")
    max_null_rate: float = Field(0.3, ge=0, le=1, description="最大空值率阈值")


class PipelineResultResponse(BaseModel):
    """管道处理结果"""
    success: bool
    message: str
    original_rows: int = 0
    cleaned_rows: int = 0
    removed_rows: int = 0
    quality_score: float = 0.0
    confidence_weight: float = 0.0
    field_mappings: dict[str, str] = Field(default_factory=dict)
    validation_errors: list[str] = Field(default_factory=list)
    cleaning_stats: dict[str, Any] = Field(default_factory=dict)
    quality_report: dict[str, Any] = Field(default_factory=dict)
    dedup_stats: dict[str, Any] = Field(default_factory=dict)
    ts_stats: dict[str, Any] = Field(default_factory=dict)
    warnings: list[str] = Field(default_factory=list)


class UploadWithPipelineRequest(BaseModel):
    """带管道处理的上传请求"""
    city: str = Field(..., description="城市名称")
    year: int = Field(..., ge=2000, le=2100, description="年份")
    permission: str = Field("internal", description="数据权限: public/internal/private")
    config: PipelineConfig = Field(default_factory=PipelineConfig)


class UploadWithPipelineResponse(BaseModel):
    """带管道处理的上传响应"""
    filename: str
    rows: int
    cols: int
    pipeline_result: PipelineResultResponse
    inserted: int = 0
    training_triggered: bool = False
