"""
FiscalShieldAI 数据回流管道
==========================

完整的数据清洗、验证、质量评分、去重、时间序列预处理管道。

架构：
    用户上传 → 字段映射 → Schema验证 → 清洗 → 去重 → 时间序列预处理 → 质量评分 → 可信度加权 → 入库

参考项目：
    - Pydantic: API层schema验证
    - Pandera: 数据层schema验证
    - FuzzyWuzzy: 字段名模糊匹配
    - DataForge: 清洗规则引擎
    - tsmoothie: 时间序列平滑+异常检测
    - AIEDF: 多维质量评分
    - dedupe: 去重引擎
"""

from .core import DataPipeline, PipelineResult

__all__ = ["DataPipeline", "PipelineResult"]
