"""
字段映射引擎
===========

支持三种匹配方式：
1. 精确匹配（exact match）
2. 子串匹配（substring match）
3. 模糊匹配（fuzzy match, fuzz.ratio > 80）

参考项目：
- data-matching: 三种匹配方式的DataProcessor
- FuzzyWuzzy: 字符串相似度计算
- rapidfuzz: 高性能模糊匹配
"""

from __future__ import annotations

import logging
import re
from typing import Any

import pandas as pd

logger = logging.getLogger(__name__)

# 尝试导入rapidfuzz（优先），fallback到fuzzywuzzy
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
    """计算两个字符串的相似度（0-100）"""
    if HAS_RAPIDFUZZ:
        return rfuzz.token_set_ratio(s1.lower(), s2.lower())
    elif HAS_FUZZYWUZZY:
        return fwuzz.token_set_ratio(s1.lower(), s2.lower())
    else:
        # 简单的fallback：基于公共字符比例
        s1, s2 = s1.lower(), s2.lower()
        if s1 == s2:
            return 100.0
        common = len(set(s1) & set(s2))
        total = len(set(s1) | set(s2))
        return (common / total * 100) if total > 0 else 0.0


# 字段名标准化：去除空格、括号、百分号等
def _normalize_field_name(name: str) -> str:
    """标准化字段名，用于匹配"""
    name = name.strip().lower()
    # 去除括号内容 (xxx)
    name = re.sub(r'\(.*?\)', '', name)
    # 去除百分号
    name = name.replace('%', '').replace('％', '')
    # 去除多余空格
    name = re.sub(r'\s+', ' ', name).strip()
    return name


class FieldMapper:
    """
    字段映射引擎
    
    将用户上传的数据列名映射到 FiscalShieldAI 的标准字段名。
    """

    def __init__(self, indicators: dict[str, dict[str, Any]] | None = None):
        """
        初始化字段映射器
        
        Args:
            indicators: 标准指标定义，格式为 {标准名: {"aliases": [...], "type": ..., "range": ...}}
        """
        self.indicators = indicators or {}
        
        # 构建同义词表：{标准化别名: 标准名}
        self._synonym_map: dict[str, str] = {}
        for std_name, info in self.indicators.items():
            # 标准名本身
            self._synonym_map[_normalize_field_name(std_name)] = std_name
            # 所有别名
            for alias in info.get("aliases", []):
                self._synonym_map[_normalize_field_name(alias)] = std_name

    def map_columns(self, df: pd.DataFrame) -> tuple[pd.DataFrame, dict[str, str]]:
        """
        映射DataFrame的列名到标准字段名
        
        Args:
            df: 原始DataFrame
            
        Returns:
            tuple: (映射后的DataFrame, 映射关系字典)
        """
        mappings = {}
        rename_map = {}
        
        for col in df.columns:
            normalized = _normalize_field_name(str(col))
            
            # 1. 精确匹配
            if normalized in self._synonym_map:
                std_name = self._synonym_map[normalized]
                mappings[str(col)] = std_name
                rename_map[col] = std_name
                logger.debug(f"精确匹配: {col} → {std_name}")
                continue
            
            # 2. 子串匹配
            matched = False
            for syn_norm, std_name in self._synonym_map.items():
                if syn_norm in normalized or normalized in syn_norm:
                    mappings[str(col)] = std_name
                    rename_map[col] = std_name
                    logger.debug(f"子串匹配: {col} → {std_name}")
                    matched = True
                    break
            if matched:
                continue
            
            # 3. 模糊匹配（阈值80%）
            best_score = 0.0
            best_match = None
            for syn_norm, std_name in self._synonym_map.items():
                score = _similarity(normalized, syn_norm)
                if score > best_score:
                    best_score = score
                    best_match = std_name
            
            if best_score >= 80 and best_match:
                mappings[str(col)] = best_match
                rename_map[col] = best_match
                logger.info(f"模糊匹配: {col} → {best_match} (score={best_score:.1f})")
            else:
                logger.debug(f"未匹配: {col} (best_score={best_score:.1f})")
        
        # 执行重命名
        if rename_map:
            df = df.rename(columns=rename_map)
        
        return df, mappings

    def get_mapping_report(self, df: pd.DataFrame) -> dict[str, Any]:
        """
        生成字段映射报告
        
        Returns:
            dict: 映射报告
        """
        report = {
            "total_columns": len(df.columns),
            "mapped": [],
            "unmapped": [],
            "mapping_coverage": 0.0,
        }
        
        mapped_count = 0
        for col in df.columns:
            normalized = _normalize_field_name(str(col))
            if normalized in self._synonym_map:
                report["mapped"].append({
                    "original": str(col),
                    "standard": self._synonym_map[normalized],
                })
                mapped_count += 1
            else:
                report["unmapped"].append(str(col))
        
        report["mapping_coverage"] = mapped_count / len(df.columns) if df.columns.size > 0 else 0.0
        return report
