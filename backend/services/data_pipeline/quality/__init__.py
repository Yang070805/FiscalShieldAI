"""
多维质量评分引擎
===============

四维加权评分体系：
1. 完整性（Completeness）35% - 缺失值率
2. 唯一性（Uniqueness）25% - 重复率
3. 一致性（Consistency）25% - 类型一致性
4. 有效性（Validity）15% - 范围规则

参考项目：
- AIEDF: quality_engine.py - 4维加权评分
- Financial-Data-Pipeline: EnhancedDataValidator - 质量评分
- clean_data_etl: 数据质量报告
"""

from __future__ import annotations

import logging
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


class QualityScorer:
    """
    多维质量评分器
    
    对DataFrame进行四维质量评估，输出0-1的综合评分。
    """

    # 维度权重
    WEIGHTS = {
        "completeness": 0.35,  # 完整性
        "uniqueness": 0.25,    # 唯一性
        "consistency": 0.25,   # 一致性
        "validity": 0.15,      # 有效性
    }

    def __init__(self, weights: dict[str, float] | None = None):
        """
        初始化评分器
        
        Args:
            weights: 自定义权重（会自动归一化）
        """
        if weights:
            self.weights = weights
            total = sum(self.weights.values())
            if total > 0:
                self.weights = {k: v / total for k, v in self.weights.items()}
        else:
            self.weights = self.WEIGHTS.copy()

    def score(
        self,
        df: pd.DataFrame,
        validation_errors: list[str] | None = None,
    ) -> dict[str, Any]:
        """
        计算多维质量评分
        
        Args:
            df: 待评分的DataFrame
            validation_errors: 验证阶段发现的错误列表
            
        Returns:
            dict: 质量报告
        """
        report = {
            "total_score": 0.0,
            "dimensions": {},
            "details": {},
            "warnings": [],
        }
        
        if df.empty:
            report["warnings"].append("数据为空，无法评分")
            return report
        
        # 1. 完整性评分
        completeness = self._score_completeness(df)
        report["dimensions"]["completeness"] = completeness
        report["details"]["completeness"] = {
            "null_rate": completeness.get("null_rate", 0),
            "score": completeness.get("score", 0),
        }
        
        # 2. 唯一性评分
        uniqueness = self._score_uniqueness(df)
        report["dimensions"]["uniqueness"] = uniqueness
        report["details"]["uniqueness"] = {
            "duplicate_rate": uniqueness.get("duplicate_rate", 0),
            "score": uniqueness.get("score", 0),
        }
        
        # 3. 一致性评分
        consistency = self._score_consistency(df)
        report["dimensions"]["consistency"] = consistency
        report["details"]["consistency"] = {
            "type_issues": consistency.get("type_issues", 0),
            "score": consistency.get("score", 0),
        }
        
        # 4. 有效性评分
        validity = self._score_validity(df, validation_errors)
        report["dimensions"]["validity"] = validity
        report["details"]["validity"] = {
            "range_violations": validity.get("range_violations", 0),
            "score": validity.get("score", 0),
        }
        
        # 计算加权总分
        total = 0.0
        for dim, weight in self.weights.items():
            dim_score = report["dimensions"].get(dim, {}).get("score", 0)
            total += dim_score * weight
        
        report["total_score"] = round(total, 4)
        
        # 生成警告
        if report["total_score"] < 0.5:
            report["warnings"].append(f"数据质量较低（{report['total_score']:.2f}），建议人工审核")
        if completeness.get("score", 1) < 0.7:
            report["warnings"].append("数据完整性不足，缺失值较多")
        if uniqueness.get("score", 1) < 0.8:
            report["warnings"].append("数据存在较多重复")
        
        return report

    def _score_completeness(self, df: pd.DataFrame) -> dict[str, Any]:
        """
        完整性评分
        
        计算非空值比例，越高越好。
        """
        # 每列的非空率
        col_rates = {}
        for col in df.columns:
            non_null_rate = 1 - df[col].isna().mean()
            col_rates[str(col)] = round(non_null_rate, 4)
        
        # 整体非空率
        overall_rate = 1 - df.isna().mean().mean()
        
        # 分数：非空率直接作为分数
        score = overall_rate
        
        return {
            "score": round(score, 4),
            "null_rate": round(1 - overall_rate, 4),
            "column_rates": col_rates,
        }

    def _score_uniqueness(self, df: pd.DataFrame) -> dict[str, Any]:
        """
        唯一性评分
        
        计算非重复行比例，越高越好。
        """
        total_rows = len(df)
        if total_rows == 0:
            return {"score": 1.0, "duplicate_rate": 0.0}
        
        duplicate_count = df.duplicated().sum()
        unique_count = total_rows - duplicate_count
        unique_rate = unique_count / total_rows
        
        return {
            "score": round(unique_rate, 4),
            "duplicate_rate": round(duplicate_count / total_rows, 4),
            "total_rows": total_rows,
            "duplicate_rows": int(duplicate_count),
        }

    def _score_consistency(self, df: pd.DataFrame) -> dict[str, Any]:
        """
        一致性评分
        
        检查数据类型的一致性（数值列是否真的都是数值）。
        """
        type_issues = 0
        total_cells = 0
        
        for col in df.columns:
            non_null = df[col].dropna()
            if len(non_null) == 0:
                continue
            
            total_cells += len(non_null)
            
            # 检查是否应该为数值
            if non_null.dtype == object:
                numeric_ratio = pd.to_numeric(non_null, errors='coerce').notna().mean()
                if numeric_ratio > 0.8:  # 80%以上是数值，说明类型不一致
                    type_issues += int(len(non_null) * (1 - numeric_ratio))
        
        if total_cells == 0:
            return {"score": 1.0, "type_issues": 0}
        
        consistency_rate = 1 - (type_issues / total_cells)
        
        return {
            "score": round(max(0, consistency_rate), 4),
            "type_issues": type_issues,
        }

    def _score_validity(
        self,
        df: pd.DataFrame,
        validation_errors: list[str] | None = None,
    ) -> dict[str, Any]:
        """
        有效性评分
        
        基于验证错误数量计算。
        """
        error_count = len(validation_errors) if validation_errors else 0
        
        # 每个错误扣5%，最低0分
        penalty = error_count * 0.05
        score = max(0.0, 1.0 - penalty)
        
        return {
            "score": round(score, 4),
            "range_violations": error_count,
        }
