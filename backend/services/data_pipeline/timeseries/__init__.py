"""
时间序列预处理
=============

功能：
1. 时间序列平滑（去除噪声）
2. 异常值检测（超出3σ区间的点）
3. 缺失值插值（基于平滑趋势）

参考项目：
- tsmoothie: 时间序列平滑+异常检测
- AnomalyDetection: S-H-ESD算法
- TODS: 全栈异常检测
- darts: 时间序列预测框架
"""

from __future__ import annotations

import logging
from typing import Any

import numpy as np
import pandas as pd
from scipy import signal

logger = logging.getLogger(__name__)


class TimeSeriesPreprocessor:
    """
    时间序列预处理器
    
    对数值型列进行平滑、异常检测和插值。
    """

    def __init__(
        self,
        sigma_threshold: float = 3.0,
        smooth_window: int = 3,
        interpolation_method: str = "linear",
    ):
        """
        初始化预处理器
        
        Args:
            sigma_threshold: 异常检测的σ阈值（默认3σ）
            smooth_window: 平滑窗口大小
            interpolation_method: 插值方法（linear/quadratic/cubic）
        """
        self.sigma_threshold = sigma_threshold
        self.smooth_window = smooth_window
        self.interpolation_method = interpolation_method

    def preprocess(
        self,
        df: pd.DataFrame,
        numeric_cols: list[str] | None = None,
    ) -> tuple[pd.DataFrame, dict[str, Any]]:
        """
        执行时间序列预处理
        
        Args:
            df: 输入DataFrame
            numeric_cols: 需要处理的数值列（None则自动检测）
            
        Returns:
            tuple: (处理后的DataFrame, 统计信息)
        """
        stats = {
            "smoothed_columns": [],
            "anomalies_detected": 0,
            "anomalies_fixed": 0,
            "interpolated_values": 0,
        }
        
        if len(df) < 3:
            logger.info("数据量不足（<3行），跳过时间序列预处理")
            return df, stats
        
        df = df.copy()
        
        # 确定要处理的列
        if numeric_cols is None:
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
        
        for col in numeric_cols:
            if col not in df.columns:
                continue
            
            series = df[col].astype(float)
            
            # 1. 缺失值插值
            null_count = series.isna().sum()
            if null_count > 0:
                series = self._interpolate(series)
                stats["interpolated_values"] += null_count
            
            # 2. 异常值检测
            anomalies = self._detect_anomalies(series)
            if len(anomalies) > 0:
                stats["anomalies_detected"] += len(anomalies)
                # 用平滑值替换异常值
                series = self._fix_anomalies(series, anomalies)
                stats["anomalies_fixed"] += len(anomalies)
            
            # 3. 平滑处理
            smoothed = self._smooth(series)
            df[col] = smoothed
            stats["smoothed_columns"].append(col)
        
        return df, stats

    def _interpolate(self, series: pd.Series) -> pd.Series:
        """
        缺失值插值
        
        使用线性插值填充缺失值，首尾用前向/后向填充。
        """
        # 先用线性插值
        interpolated = series.interpolate(method=self.interpolation_method)
        
        # 首尾用前向/后向填充
        interpolated = interpolated.ffill().bfill()
        
        # 如果还有缺失，用均值填充
        if interpolated.isna().any():
            interpolated = interpolated.fillna(interpolated.mean())
        
        return interpolated

    def _detect_anomalies(self, series: pd.Series) -> list[int]:
        """
        异常值检测
        
        使用3σ法则：超出 [mean - 3*std, mean + 3*std] 的点为异常值。
        """
        if len(series) < 3:
            return []
        
        mean = series.mean()
        std = series.std()
        
        if std == 0:
            return []
        
        lower = mean - self.sigma_threshold * std
        upper = mean + self.sigma_threshold * std
        
        anomaly_mask = (series < lower) | (series > upper)
        anomalies = series[anomaly_mask].index.tolist()
        
        return anomalies

    def _fix_anomalies(self, series: pd.Series, anomalies: list[int]) -> pd.Series:
        """
        修复异常值
        
        用相邻值的均值替换异常值。
        """
        series = series.copy()
        
        for idx in anomalies:
            # 获取相邻值
            pos = series.index.get_loc(idx)
            
            neighbors = []
            if pos > 0:
                neighbors.append(series.iloc[pos - 1])
            if pos < len(series) - 1:
                neighbors.append(series.iloc[pos + 1])
            
            if neighbors:
                series.iloc[pos] = np.mean(neighbors)
        
        return series

    def _smooth(self, series: pd.Series) -> pd.Series:
        """
        平滑处理
        
        使用移动平均平滑，窗口大小为 smooth_window。
        """
        if len(series) < self.smooth_window:
            return series
        
        # 使用scipy的savgol滤波器（如果窗口足够大）
        if self.smooth_window >= 3 and self.smooth_window % 2 == 1:
            try:
                smoothed = signal.savgol_filter(
                    series.values, 
                    window_length=self.smooth_window, 
                    polyorder=min(3, self.smooth_window - 1),
                )
                return pd.Series(smoothed, index=series.index)
            except Exception:
                pass
        
        # Fallback到简单移动平均
        smoothed = series.rolling(
            window=self.smooth_window, 
            center=True, 
            min_periods=1,
        ).mean()
        
        return smoothed

    def get_anomaly_report(self, df: pd.DataFrame) -> dict[str, Any]:
        """
        生成异常值报告
        
        Returns:
            dict: 异常值报告
        """
        report = {
            "columns": {},
            "total_anomalies": 0,
        }
        
        numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
        
        for col in numeric_cols:
            series = df[col].dropna().astype(float)
            if len(series) < 3:
                continue
            
            anomalies = self._detect_anomalies(series)
            report["columns"][col] = {
                "anomaly_count": len(anomalies),
                "anomaly_rate": len(anomalies) / len(series) if len(series) > 0 else 0,
                "anomaly_indices": anomalies[:10],  # 最多显示10个
            }
            report["total_anomalies"] += len(anomalies)
        
        return report
