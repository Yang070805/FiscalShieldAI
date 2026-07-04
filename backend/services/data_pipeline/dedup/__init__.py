"""
去重引擎（优化版）
==================

优化策略：
1. 多级阻塞：先粗分桶，再细比较
2. 早期终止：相似度低于阈值时提前退出
3. 向量化计算：利用numpy加速数值比较
4. 分块处理：大数据集分块处理，控制内存

参考项目：
- dedupe: ML驱动的去重，Fingerprinter+活动学习
- deduplipy: 主动学习去重
- data-matching: 三种匹配方式
"""

from __future__ import annotations

import logging
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

# 尝试导入rapidfuzz
try:
    from rapidfuzz import fuzz as rfuzz
    HAS_RAPIDFUZZ = True
except ImportError:
    HAS_RAPIDFUZZ = False

try:
    from fuzzywuzzy import fuzz as fwuzz
    HAS_FUZZYWUZZY = True
except ImportError:
    HAS_FUZZYWUZZY = False


def _similarity(s1: str, s2: str) -> float:
    """计算两个字符串的相似度"""
    if HAS_RAPIDFUZZ:
        return rfuzz.token_set_ratio(str(s1).lower(), str(s2).lower())
    elif HAS_FUZZYWUZZY:
        return fwuzz.token_set_ratio(str(s1).lower(), str(s2).lower())
    else:
        s1, s2 = str(s1).lower(), str(s2).lower()
        if s1 == s2:
            return 100.0
        common = len(set(s1) & set(s2))
        total = len(set(s1) | set(s2))
        return (common / total * 100) if total > 0 else 0.0


def _fast_numeric_similarity(arr1: np.ndarray, arr2: np.ndarray) -> float:
    """向量化数值相似度计算"""
    if len(arr1) == 0:
        return 0.0
    
    max_vals = np.maximum(np.abs(arr1), np.abs(arr2))
    max_vals = np.where(max_vals == 0, 1, max_vals)  # 避免除零
    diffs = np.abs(arr1 - arr2) / max_vals
    similarities = np.maximum(0, 100 - diffs * 100)
    return float(np.mean(similarities))


class DataDeduplicator:
    """
    数据去重器（优化版）
    
    使用多级阻塞+模糊匹配的方式去除重复记录。
    时间复杂度：O(n * k)，其中k是每个桶的平均大小（通常远小于n）
    """

    def __init__(
        self,
        similarity_threshold: float = 85.0,
        block_size: int = 3,
        max_block_size: int = 100,
    ):
        """
        初始化去重器
        
        Args:
            similarity_threshold: 相似度阈值（0-100），高于此值视为重复
            block_size: 阻塞键长度
            max_block_size: 单个桶的最大大小，超过则二次分桶
        """
        self.similarity_threshold = similarity_threshold
        self.block_size = block_size
        self.max_block_size = max_block_size

    def deduplicate(
        self,
        df: pd.DataFrame,
        key_columns: list[str] | None = None,
    ) -> tuple[pd.DataFrame, dict[str, Any]]:
        """
        去除重复记录（优化版）
        
        Args:
            df: 待去重的DataFrame
            key_columns: 用于判断重复的关键列（None则使用所有列）
            
        Returns:
            tuple: (去重后的DataFrame, 去重统计)
        """
        stats = {
            "original_rows": len(df),
            "removed": 0,
            "strategy": "multi_level_blocking",
            "blocks_created": 0,
            "comparisons_made": 0,
        }
        
        if len(df) <= 1:
            stats["final_rows"] = len(df)
            return df, stats
        
        # 确定用于匹配的列
        if key_columns:
            match_cols = [c for c in key_columns if c in df.columns]
        else:
            match_cols = self._select_match_columns(df)
        
        if not match_cols:
            match_cols = df.columns.tolist()
        
        # 分离数值列和文本列（优化数值比较）
        numeric_cols = [c for c in match_cols if df[c].dtype in ['int64', 'float64', 'int32', 'float32']]
        text_cols = [c for c in match_cols if c not in numeric_cols]
        
        # 预处理：将数值列转为numpy数组（加速比较）
        df = df.copy()
        numeric_data = {}
        if numeric_cols:
            for col in numeric_cols:
                numeric_data[col] = df[col].fillna(0).values.astype(np.float64)
        
        # 构建多级阻塞键
        blocking_key = match_cols[0] if match_cols else df.columns[0]
        df['_block_key'] = df[blocking_key].astype(str).str.lower().str[:self.block_size]
        
        # 统计块数量
        blocks = df.groupby('_block_key')
        stats["blocks_created"] = len(blocks)
        
        # 找出重复对
        duplicates_to_drop = set()
        comparisons = 0
        
        for block_key, group in blocks:
            if len(group) <= 1:
                continue
            
            # 如果块太大，进行二次分桶
            if len(group) > self.max_block_size:
                sub_groups = self._sub_block(group, match_cols)
                for sub_group in sub_groups:
                    duplicates_to_drop.update(
                        self._find_duplicates_in_block(
                            sub_group, match_cols, numeric_cols, text_cols, numeric_data
                        )
                    )
            else:
                duplicates_to_drop.update(
                    self._find_duplicates_in_block(
                        group, match_cols, numeric_cols, text_cols, numeric_data
                    )
                )
        
        # 删除重复记录
        df_cleaned = df.drop(index=list(duplicates_to_drop)).drop(columns=['_block_key'])
        
        stats["removed"] = len(duplicates_to_drop)
        stats["final_rows"] = len(df_cleaned)
        stats["comparisons_made"] = comparisons
        
        logger.info(
            f"去重完成: {stats['original_rows']} → {stats['final_rows']} "
            f"(去除 {stats['removed']} 条, {stats['blocks_created']} 个块)"
        )
        
        return df_cleaned, stats

    def _sub_block(self, group: pd.DataFrame, match_cols: list[str]) -> list[pd.DataFrame]:
        """二次分桶：用第二个字符作为阻塞键"""
        if len(match_cols) < 2:
            return [group]
        
        second_key = match_cols[1] if len(match_cols) > 1 else match_cols[0]
        group = group.copy()
        group['_sub_block_key'] = group[second_key].astype(str).str.lower().str[:2]
        
        sub_groups = list(group.groupby('_sub_block_key'))
        return [sg for _, sg in sub_groups]

    def _find_duplicates_in_block(
        self,
        group: pd.DataFrame,
        match_cols: list[str],
        numeric_cols: list[str],
        text_cols: list[str],
        numeric_data: dict,
    ) -> set:
        """在单个块内查找重复"""
        duplicates = set()
        indices = group.index.tolist()
        
        # 预提取数值数据（块内）
        block_numeric = {}
        if numeric_cols:
            for col in numeric_cols:
                if col in numeric_data:
                    # 获取块内对应行的数值
                    block_idx = group.index.tolist()
                    block_numeric[col] = np.array([numeric_data[col][i] for i in block_idx])
        
        comparisons = 0
        
        for i in range(len(indices)):
            if indices[i] in duplicates:
                continue
            
            for j in range(i + 1, len(indices)):
                if indices[j] in duplicates:
                    continue
                
                # 快速数值比较（如果都是数值列）
                if numeric_cols and not text_cols:
                    similarity = self._fast_numeric_compare(
                        i, j, numeric_cols, block_numeric
                    )
                else:
                    # 完整比较
                    similarity = self._record_similarity(
                        group.loc[indices[i]],
                        group.loc[indices[j]],
                        match_cols,
                        numeric_cols,
                        text_cols,
                        block_numeric,
                        i, j,
                    )
                
                comparisons += 1
                
                if similarity >= self.similarity_threshold:
                    duplicates.add(indices[j])
                elif similarity < self.similarity_threshold * 0.5:
                    # 早期终止：相似度太低，跳过后续比较
                    break
        
        return duplicates

    def _fast_numeric_compare(
        self,
        i: int,
        j: int,
        numeric_cols: list[str],
        block_numeric: dict,
    ) -> float:
        """快速数值比较"""
        scores = []
        for col in numeric_cols:
            if col in block_numeric:
                arr = block_numeric[col]
                val1, val2 = arr[i], arr[j]
                max_val = max(abs(val1), abs(val2))
                if max_val == 0:
                    scores.append(100.0)
                else:
                    diff = abs(val1 - val2) / max_val
                    scores.append(max(0, 100 - diff * 100))
        
        return np.mean(scores) if scores else 0.0

    def _select_match_columns(self, df: pd.DataFrame) -> list[str]:
        """自动选择用于匹配的列"""
        numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
        
        if len(numeric_cols) >= 3:
            return numeric_cols[:5]
        
        return df.columns.tolist()

    def _record_similarity(
        self,
        row1: pd.Series,
        row2: pd.Series,
        match_cols: list[str],
        numeric_cols: list[str],
        text_cols: list[str],
        block_numeric: dict,
        idx1: int,
        idx2: int,
    ) -> float:
        """计算两条记录的综合相似度（优化版）"""
        scores = []
        
        # 数值列：使用预提取的numpy数组
        for col in numeric_cols:
            if col in block_numeric:
                arr = block_numeric[col]
                val1, val2 = arr[idx1], arr[idx2]
                max_val = max(abs(val1), abs(val2))
                if max_val == 0:
                    scores.append(100.0)
                else:
                    diff = abs(val1 - val2) / max_val
                    scores.append(max(0, 100 - diff * 100))
        
        # 文本列：模糊匹配
        for col in text_cols:
            val1 = row1.get(col)
            val2 = row2.get(col)
            
            if pd.isna(val1) and pd.isna(val2):
                scores.append(100.0)
            elif pd.isna(val1) or pd.isna(val2):
                scores.append(0.0)
            else:
                scores.append(_similarity(str(val1), str(val2)))
        
        return np.mean(scores) if scores else 0.0
