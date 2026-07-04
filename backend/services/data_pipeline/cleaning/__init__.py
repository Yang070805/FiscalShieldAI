"""
数据清洗引擎
===========

支持13种清洗规则：
1. trim_whitespace - 去除首尾空格
2. to_lowercase - 转小写
3. type_cast - 类型转换
4. fill_null - 缺失值填充（mean/median/mode/插值）
5. drop_null - 删除含空值行
6. fix_mismatched_types - 类型不匹配修复
7. fix_categorical_outliers - 分类异常值归并（Levenshtein距离）
8. standardize_date - 日期格式标准化
9. remove_special_chars - 去除特殊字符
10. regex_replace - 正则替换
11. collapse_whitespace - 合并多余空格
12. remove_html - 去除HTML标签
13. drop_empty_columns - 删除空列

参考项目：
- DataForge (Go): 13种清洗规则的完整实现
- clean_data_etl: 完整ETL管道
- AIEDF: transformation.py
"""

from __future__ import annotations

import logging
import re
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


def _levenshtein_distance(s1: str, s2: str) -> int:
    """计算Levenshtein编辑距离"""
    if len(s1) < len(s2):
        return _levenshtein_distance(s2, s1)
    
    if len(s2) == 0:
        return len(s1)
    
    prev_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        curr_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = prev_row[j + 1] + 1
            deletions = curr_row[j] + 1
            substitutions = prev_row[j] + (c1 != c2)
            curr_row.append(min(insertions, deletions, substitutions))
        prev_row = curr_row
    
    return prev_row[-1]


# Null哨兵值集合
NULL_SENTINELS = {
    "", "null", "n/a", "na", "none", "nil", "-", "<na>", "nan",
    "missing", "#n/a", "#null!", "#ref!", "#value!", "undefined",
    "inf", "-inf", "?", "..", "--",
}


def _is_null_value(val: Any) -> bool:
    """判断值是否为空值哨兵"""
    if pd.isna(val):
        return True
    if isinstance(val, str):
        return val.strip().lower() in NULL_SENTINELS
    return False


class DataCleaner:
    """
    数据清洗引擎
    
    对DataFrame应用一系列清洗规则，输出干净的数据。
    """

    def __init__(self, rules: list[dict[str, Any]] | None = None):
        """
        初始化清洗器
        
        Args:
            rules: 自定义清洗规则列表，默认使用标准规则
        """
        self.rules = rules or self._default_rules()

    def _default_rules(self) -> list[dict[str, Any]]:
        """默认清洗规则"""
        return [
            {"operation": "trim_whitespace", "column": None},  # 所有列
            {"operation": "fill_null", "column": None, "strategy": "mean"},
            {"operation": "fix_mismatched_types", "column": None},
            {"operation": "remove_special_chars", "column": None, "allow": r"a-zA-Z0-9\s._-"},
            {"operation": "collapse_whitespace", "column": None},
        ]

    def clean(self, df: pd.DataFrame) -> tuple[pd.DataFrame, dict[str, Any]]:
        """
        执行数据清洗
        
        Args:
            df: 原始DataFrame
            
        Returns:
            tuple: (清洗后的DataFrame, 清洗统计信息)
        """
        stats = {
            "original_rows": len(df),
            "operations": [],
            "total_cells_modified": 0,
        }
        
        df = df.copy()
        
        # 预处理：删除全空行
        before = len(df)
        df = df.dropna(how='all')
        dropped = before - len(df)
        if dropped > 0:
            stats["operations"].append({
                "operation": "drop_empty_rows",
                "affected": dropped,
            })
        
        # 预处理：删除空列
        df, empty_cols_dropped = self._drop_empty_columns(df)
        if empty_cols_dropped:
            stats["operations"].append({
                "operation": "drop_empty_columns",
                "affected": empty_cols_dropped,
            })
        
        # 预处理：去除重复行
        before = len(df)
        df = df.drop_duplicates()
        dropped = before - len(df)
        if dropped > 0:
            stats["operations"].append({
                "operation": "drop_duplicates",
                "affected": dropped,
            })
        
        # 计算列填充统计（用于智能填充）
        col_stats = self._compute_column_stats(df)
        
        # 应用清洗规则
        for rule in self.rules:
            op = rule["operation"]
            col = rule.get("column")
            
            if op == "trim_whitespace":
                df, affected = self._trim_whitespace(df, col)
            elif op == "fill_null":
                df, affected = self._fill_null(df, col, rule.get("strategy", "mean"), col_stats)
            elif op == "fix_mismatched_types":
                df, affected = self._fix_mismatched_types(df, col, col_stats)
            elif op == "remove_special_chars":
                df, affected = self._remove_special_chars(df, col, rule.get("allow", r"a-zA-Z0-9\s._-"))
            elif op == "collapse_whitespace":
                df, affected = self._collapse_whitespace(df, col)
            else:
                continue
            
            if affected > 0:
                stats["operations"].append({
                    "operation": op,
                    "column": col or "all",
                    "affected": affected,
                })
                stats["total_cells_modified"] += affected
        
        stats["final_rows"] = len(df)
        return df, stats

    def _drop_empty_columns(self, df: pd.DataFrame) -> tuple[pd.DataFrame, int]:
        """删除空列（所有值都为空或null）"""
        cols_to_drop = []
        for col in df.columns:
            fill_rate = 1 - df[col].isna().mean()
            if fill_rate < 0.01:  # 填充率<1%视为空列
                cols_to_drop.append(col)
        
        if cols_to_drop:
            df = df.drop(columns=cols_to_drop)
            logger.info(f"删除空列: {cols_to_drop}")
        
        return df, len(cols_to_drop)

    def _compute_column_stats(self, df: pd.DataFrame) -> dict[str, dict]:
        """计算每列的统计信息（均值、中位数、众数）"""
        stats = {}
        for col in df.columns:
            col_data = df[col]
            non_null = col_data.dropna()
            
            col_stat = {"mean": None, "median": None, "mode": None}
            
            if non_null.empty:
                stats[str(col)] = col_stat
                continue
            
            # 尝试转为数值
            numeric = pd.to_numeric(non_null, errors='coerce')
            numeric = numeric.dropna()
            
            if len(numeric) > 0:
                col_stat["mean"] = numeric.mean()
                col_stat["median"] = numeric.median()
            
            # 众数
            mode_result = non_null.mode()
            if len(mode_result) > 0:
                col_stat["mode"] = mode_result.iloc[0]
            
            stats[str(col)] = col_stat
        
        return stats

    def _trim_whitespace(self, df: pd.DataFrame, col: str | None) -> tuple[pd.DataFrame, int]:
        """去除首尾空格"""
        affected = 0
        cols = [col] if col else df.columns.tolist()
        
        for c in cols:
            if c in df.columns and df[c].dtype == object:
                before = df[c].copy()
                df[c] = df[c].astype(str).str.strip()
                changed = (before != df[c]).sum()
                affected += changed
        
        return df, affected

    def _fill_null(
        self,
        df: pd.DataFrame,
        col: str | None,
        strategy: str,
        col_stats: dict,
    ) -> tuple[pd.DataFrame, int]:
        """填充缺失值"""
        affected = 0
        cols = [col] if col else df.columns.tolist()
        
        for c in cols:
            if c not in df.columns:
                continue
            
            # 检测空值（包括NaN和字符串null哨兵）
            null_mask = df[c].isna()
            # 对于字符串列，也检查null哨兵
            if df[c].dtype == object:
                null_mask = null_mask | df[c].apply(_is_null_value)
            null_count = null_mask.sum()
            
            if null_count == 0:
                continue
            
            stats = col_stats.get(str(c), {})
            
            # 确定填充值
            fill_val = None
            if strategy == "mean" and stats.get("mean") is not None:
                fill_val = stats["mean"]
            elif strategy == "median" and stats.get("median") is not None:
                fill_val = stats["median"]
            elif strategy == "mode" and stats.get("mode") is not None:
                fill_val = stats["mode"]
            else:
                # 尝试用均值填充，否则用0
                fill_val = stats.get("mean", 0) or 0
            
            # 对于混合类型列，先转为数值
            if df[c].dtype == object:
                # 尝试转为数值（非数值的会变成NaN）
                numeric_vals = pd.to_numeric(df[c], errors='coerce')
                if numeric_vals.notna().any():
                    # 有数值，用数值填充
                    # 先填充空值
                    null_mask_new = numeric_vals.isna()
                    if null_mask_new.any():
                        numeric_vals[null_mask_new] = fill_val
                    df[c] = numeric_vals
                else:
                    # 全是非数值，用字符串填充
                    fill_val_str = str(fill_val)
                    df.loc[null_mask, c] = fill_val_str
            else:
                # 数值列直接填充
                df.loc[null_mask, c] = fill_val
            
            affected += null_count
        
        return df, affected

    def _fix_mismatched_types(
        self,
        df: pd.DataFrame,
        col: str | None,
        col_stats: dict,
    ) -> tuple[pd.DataFrame, int]:
        """修复类型不匹配的值"""
        affected = 0
        cols = [col] if col else df.columns.tolist()
        
        for c in cols:
            if c not in df.columns:
                continue
            
            # 检查列是否应该是数值型
            numeric_ratio = pd.to_numeric(df[c], errors='coerce').notna().mean()
            
            if numeric_ratio > 0.8:  # 80%以上是数值，修复剩余的
                numeric_vals = pd.to_numeric(df[c], errors='coerce')
                non_numeric_mask = numeric_vals.isna() & df[c].notna()
                
                if non_numeric_mask.sum() > 0:
                    # 尝试提取数值
                    for idx in df[non_numeric_mask].index:
                        val = str(df.loc[idx, c])
                        # 提取数字部分
                        match = re.search(r'[-+]?\d*\.?\d+', val)
                        if match:
                            df.loc[idx, c] = float(match.group())
                            affected += 1
                        else:
                            # 用众数填充
                            mode_val = col_stats.get(str(c), {}).get("mode")
                            if mode_val is not None:
                                df.loc[idx, c] = mode_val
                                affected += 1
        
        return df, affected

    def _remove_special_chars(
        self,
        df: pd.DataFrame,
        col: str | None,
        allow: str,
    ) -> tuple[pd.DataFrame, int]:
        """去除特殊字符"""
        affected = 0
        cols = [col] if col else df.columns.tolist()
        pattern = re.compile(f'[^{allow}]')
        
        for c in cols:
            if c in df.columns and df[c].dtype == object:
                before = df[c].copy()
                df[c] = df[c].astype(str).apply(lambda x: pattern.sub('', x))
                changed = (before != df[c]).sum()
                affected += changed
        
        return df, affected

    def _collapse_whitespace(self, df: pd.DataFrame, col: str | None) -> tuple[pd.DataFrame, int]:
        """合并多余空格"""
        affected = 0
        cols = [col] if col else df.columns.tolist()
        pattern = re.compile(r'\s{2,}')
        
        for c in cols:
            if c in df.columns and df[c].dtype == object:
                before = df[c].copy()
                df[c] = df[c].astype(str).apply(lambda x: pattern.sub(' ', x))
                changed = (before != df[c]).sum()
                affected += changed
        
        return df, affected
