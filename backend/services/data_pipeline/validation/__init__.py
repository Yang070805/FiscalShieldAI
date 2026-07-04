"""
数据Schema验证
=============

使用 Pandera 风格的验证逻辑（不强制依赖pandera库）。
支持：
- 列存在性检查
- 数据类型检查
- 值范围检查
- 空值率检查
- 唯一性检查

参考项目：
- Pandera: DataFrameSchema + Column + Check
- Zero-defect-credit-risk-pipeline: YAML数据契约
- AIEDF: validation.py
"""

from __future__ import annotations

import logging
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


class SchemaValidator:
    """
    数据Schema验证器
    
    验证DataFrame是否符合FiscalShieldAI的数据契约。
    """

    def __init__(
        self,
        indicators: dict[str, dict[str, Any]] | None = None,
        max_null_rate: float = 0.3,
    ):
        """
        初始化验证器
        
        Args:
            indicators: 标准指标定义
            max_null_rate: 最大允许空值率（默认30%）
        """
        self.indicators = indicators or {}
        self.max_null_rate = max_null_rate

    def validate(self, df: pd.DataFrame) -> tuple[bool, list[str]]:
        """
        验证DataFrame
        
        Args:
            df: 待验证的DataFrame
            
        Returns:
            tuple: (是否通过, 错误列表)
        """
        errors = []
        
        # 1. 基本检查
        if df.empty:
            errors.append("数据为空")
            return False, errors
        
        # 2. 列存在性检查
        col_errors = self._check_columns(df)
        errors.extend(col_errors)
        
        # 3. 数据类型检查
        type_errors = self._check_dtypes(df)
        errors.extend(type_errors)
        
        # 4. 值范围检查
        range_errors = self._check_ranges(df)
        errors.extend(range_errors)
        
        # 5. 空值率检查
        null_errors = self._check_null_rates(df)
        errors.extend(null_errors)
        
        # 6. 重复行检查
        dup_errors = self._check_duplicates(df)
        errors.extend(dup_errors)
        
        is_valid = len(errors) == 0
        return is_valid, errors

    def _check_columns(self, df: pd.DataFrame) -> list[str]:
        """检查必需列是否存在"""
        errors = []
        
        # 至少需要有一个标准指标列
        standard_cols = set()
        for std_name, info in self.indicators.items():
            standard_cols.add(std_name)
            for alias in info.get("aliases", []):
                standard_cols.add(alias)
        
        # 精确匹配
        df_cols = {str(c).strip() for c in df.columns}
        found_exact = standard_cols & df_cols
        
        if len(found_exact) == 0:
            # 尝试模糊匹配
            from services.data_pipeline.mapping import _normalize_field_name, _similarity
            found_fuzzy = 0
            for col in df.columns:
                normalized = _normalize_field_name(str(col))
                for syn in standard_cols:
                    syn_normalized = _normalize_field_name(syn)
                    if _similarity(normalized, syn_normalized) >= 80:
                        found_fuzzy += 1
                        break
            
            if found_fuzzy == 0:
                errors.append(f"未找到任何标准指标列，期望至少一个: {list(self.indicators.keys())[:3]}...")
        
        return errors

    def _check_dtypes(self, df: pd.DataFrame) -> list[str]:
        """检查数据类型"""
        errors = []
        
        for col in df.columns:
            col_str = str(col)
            if col_str in self.indicators:
                expected_type = self.indicators[col_str].get("type", "float")
                if expected_type == "float":
                    try:
                        pd.to_numeric(df[col], errors='raise')
                    except (ValueError, TypeError):
                        # 尝试转换，记录警告而非错误
                        non_numeric = pd.to_numeric(df[col], errors='coerce').isna().sum()
                        if non_numeric > 0:
                            errors.append(f"列 '{col_str}' 包含 {non_numeric} 个非数值")
        
        return errors

    def _check_ranges(self, df: pd.DataFrame) -> list[str]:
        """检查值范围"""
        errors = []
        
        for col in df.columns:
            col_str = str(col)
            if col_str in self.indicators:
                value_range = self.indicators[col_str].get("range")
                if value_range and len(value_range) == 2:
                    min_val, max_val = value_range
                    numeric_col = pd.to_numeric(df[col], errors='coerce')
                    
                    below_min = (numeric_col < min_val).sum()
                    above_max = (numeric_col > max_val).sum()
                    
                    if below_min > 0:
                        errors.append(f"列 '{col_str}' 有 {below_min} 个值低于下限 {min_val}")
                    if above_max > 0:
                        errors.append(f"列 '{col_str}' 有 {above_max} 个值高于上限 {max_val}")
        
        return errors

    def _check_null_rates(self, df: pd.DataFrame) -> list[str]:
        """检查空值率"""
        errors = []
        
        for col in df.columns:
            null_rate = df[col].isna().mean()
            if null_rate > self.max_null_rate:
                errors.append(
                    f"列 '{col}' 空值率 {null_rate:.1%} 超过阈值 {self.max_null_rate:.1%}"
                )
        
        return errors

    def _check_duplicates(self, df: pd.DataFrame) -> list[str]:
        """检查重复行"""
        errors = []
        
        dup_count = df.duplicated().sum()
        if dup_count > 0:
            dup_rate = dup_count / len(df)
            if dup_rate > 0.1:  # 超过10%重复
                errors.append(f"数据包含 {dup_count} 行重复（{dup_rate:.1%}）")
            else:
                logger.info(f"数据包含 {dup_count} 行重复（{dup_rate:.1%}），将在去重阶段处理")
        
        return errors

    def generate_contract(self) -> dict[str, Any]:
        """
        生成YAML风格的数据契约（可序列化为YAML）
        
        Returns:
            dict: 数据契约
        """
        contract = {
            "dataset": "fiscal_city_data",
            "version": "1.0",
            "columns": {},
        }
        
        for std_name, info in self.indicators.items():
            contract["columns"][std_name] = {
                "type": info.get("type", "float"),
                "nullable": True,
                "range": {
                    "min": info.get("range", (0, None))[0],
                    "max": info.get("range", (None, 100))[1],
                },
                "aliases": info.get("aliases", []),
            }
        
        return contract
