"""
数据回流管道核心编排器
====================

负责协调整个数据处理流程：
1. 字段映射（同义词表 + 模糊匹配）
2. Schema验证（Pandera DataContract）
3. 数据清洗（13种规则）
4. 去重（ML分类器）
5. 时间序列预处理（平滑 + 异常检测）
6. 多维质量评分
7. 可信度加权
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

import pandas as pd

from .mapping import FieldMapper
from .validation import SchemaValidator
from .cleaning import DataCleaner
from .quality import QualityScorer
from .dedup import DataDeduplicator
from .timeseries import TimeSeriesPreprocessor

logger = logging.getLogger(__name__)


# ==================== 数据契约 ====================

# FiscalShieldAI 的9项核心指标
CORE_INDICATORS = {
    "负债率": {"aliases": ["负债比率", "debt_ratio", "debt-to-asset", "资产负债率"], "type": "float", "range": (0, 200)},
    "债务率": {"aliases": ["债务比率", "debt_service_ratio", "偿债率"], "type": "float", "range": (0, 500)},
    "赤字率": {"aliases": ["赤字比率", "deficit_ratio", "fiscal_deficit"], "type": "float", "range": (-50, 100)},
    "现金短期债务比": {"aliases": ["现金短债比", "cash_short_debt_ratio", "cash_ratio"], "type": "float", "range": (0, 100)},
    "短期债务占比": {"aliases": ["短期负债占比", "short_debt_ratio", "short_term_debt_pct"], "type": "float", "range": (0, 100)},
    "存贷比": {"aliases": ["贷存比", "loan_deposit_ratio", "ld_ratio"], "type": "float", "range": (0, 300)},
    "不良贷款率": {"aliases": ["不良率", "npl_ratio", "non_performing_loan"], "type": "float", "range": (0, 100)},
    "拨备覆盖率": {"aliases": ["拨备率", "provision_coverage", "pcr"], "type": "float", "range": (0, 1000)},
    "资本充足率": {"aliases": ["资本比率", "capital_adequacy", "car"], "type": "float", "range": (0, 100)},
}


@dataclass
class PipelineResult:
    """管道处理结果"""
    success: bool
    message: str
    original_rows: int = 0
    cleaned_rows: int = 0
    removed_rows: int = 0
    quality_score: float = 0.0
    confidence_weight: float = 0.0
    field_mappings: dict[str, str] = field(default_factory=dict)
    validation_errors: list[str] = field(default_factory=list)
    cleaning_stats: dict[str, Any] = field(default_factory=dict)
    quality_report: dict[str, Any] = field(default_factory=dict)
    dedup_stats: dict[str, Any] = field(default_factory=dict)
    ts_stats: dict[str, Any] = field(default_factory=dict)
    processed_data: pd.DataFrame | None = None
    warnings: list[str] = field(default_factory=list)


class DataPipeline:
    """
    FiscalShieldAI 数据回流管道
    
    完整流程：
    用户上传 → 字段映射 → Schema验证 → 清洗 → 去重 → 时间序列预处理 → 质量评分 → 可信度加权
    """

    def __init__(self, config: dict[str, Any] | None = None):
        """
        初始化管道
        
        Args:
            config: 可选配置，覆盖默认参数
        """
        self.config = config or {}
        
        # 初始化各模块
        self.mapper = FieldMapper(indicators=CORE_INDICATORS)
        self.validator = SchemaValidator(indicators=CORE_INDICATORS)
        self.cleaner = DataCleaner()
        self.scorer = QualityScorer()
        self.deduplicator = DataDeduplicator()
        self.ts_preprocessor = TimeSeriesPreprocessor()

    def process(
        self,
        df: pd.DataFrame,
        city: str = "",
        year: int = 0,
        permission: str = "internal",
        skip_dedup: bool = False,
        skip_ts: bool = False,
    ) -> PipelineResult:
        """
        执行完整的数据处理管道
        
        Args:
            df: 原始数据DataFrame
            city: 城市名称
            year: 年份
            permission: 数据权限（public/internal/private）
            skip_dedup: 是否跳过去重
            skip_ts: 是否跳过时间序列预处理
            
        Returns:
            PipelineResult: 处理结果
        """
        result = PipelineResult(success=False, message="", original_rows=len(df))
        
        try:
            # ========== Step 1: 字段映射 ==========
            logger.info("Step 1: 字段映射")
            df, mappings = self.mapper.map_columns(df)
            result.field_mappings = mappings
            logger.info(f"字段映射完成: {len(mappings)} 个字段已映射")
            
            # ========== Step 2: Schema验证 ==========
            logger.info("Step 2: Schema验证")
            is_valid, errors = self.validator.validate(df)
            result.validation_errors = errors
            if not is_valid:
                logger.warning(f"Schema验证发现 {len(errors)} 个问题")
                # 不直接失败，继续处理，但降低可信度
            
            # ========== Step 3: 数据清洗 ==========
            logger.info("Step 3: 数据清洗")
            df, cleaning_stats = self.cleaner.clean(df)
            result.cleaning_stats = cleaning_stats
            result.cleaned_rows = len(df)
            result.removed_rows = result.original_rows - result.cleaned_rows
            logger.info(f"清洗完成: {result.original_rows} → {result.cleaned_rows} 行")
            
            # ========== Step 4: 去重 ==========
            if not skip_dedup and len(df) > 1:
                logger.info("Step 4: 去重")
                df, dedup_stats = self.deduplicator.deduplicate(df)
                result.dedup_stats = dedup_stats
                logger.info(f"去重完成: 去除 {dedup_stats.get('removed', 0)} 条重复")
            
            # ========== Step 5: 时间序列预处理 ==========
            if not skip_ts and len(df) > 2:
                logger.info("Step 5: 时间序列预处理")
                df, ts_stats = self.ts_preprocessor.preprocess(df)
                result.ts_stats = ts_stats
                logger.info("时间序列预处理完成")
            
            # ========== Step 6: 多维质量评分 ==========
            logger.info("Step 6: 质量评分")
            quality_report = self.scorer.score(df, validation_errors=errors)
            result.quality_report = quality_report
            result.quality_score = quality_report.get("total_score", 0.0)
            logger.info(f"质量评分: {result.quality_score:.2f}")
            
            # ========== Step 7: 可信度加权 ==========
            result.confidence_weight = self._compute_confidence(
                quality_score=result.quality_score,
                permission=permission,
                validation_errors=errors,
            )
            logger.info(f"可信度权重: {result.confidence_weight:.2f}")
            
            result.processed_data = df
            result.success = True
            result.message = f"数据处理完成: {result.cleaned_rows} 行有效数据，质量评分 {result.quality_score:.2f}"
            
        except Exception as e:
            logger.error(f"管道处理失败: {e}", exc_info=True)
            result.success = False
            result.message = f"处理失败: {str(e)}"
        
        return result

    def _compute_confidence(
        self,
        quality_score: float,
        permission: str,
        validation_errors: list[str],
    ) -> float:
        """
        计算可信度权重
        
        规则：
        - 质量评分直接作为基础权重
        - 政务数据额外加成（权威性）
        - 企业数据正常权重
        - 验证错误扣分
        
        Returns:
            float: 0.0 ~ 1.0 的可信度权重
        """
        weight = quality_score
        
        # 权限加成
        permission_bonus = {
            "gov": 0.15,        # 政务数据权威性加成
            "enterprise": 0.0,  # 企业数据正常
            "internal": 0.05,   # 内部数据小加成
        }
        weight += permission_bonus.get(permission, 0.0)
        
        # 验证错误扣分（每个错误扣2%，最多扣20%）
        error_penalty = min(len(validation_errors) * 0.02, 0.20)
        weight -= error_penalty
        
        # 归一化到 [0, 1]
        return max(0.0, min(1.0, weight))
