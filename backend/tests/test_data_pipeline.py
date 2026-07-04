"""
数据管道测试
===========

测试完整的数据处理管道。
"""

import sys
sys.path.insert(0, '.')

import pandas as pd
import numpy as np

from services.data_pipeline.core import DataPipeline
from services.data_pipeline.mapping import FieldMapper
from services.data_pipeline.validation import SchemaValidator
from services.data_pipeline.cleaning import DataCleaner
from services.data_pipeline.quality import QualityScorer
from services.data_pipeline.dedup import DataDeduplicator
from services.data_pipeline.timeseries import TimeSeriesPreprocessor


def create_test_data():
    """创建测试数据"""
    data = {
        "城市": ["南京", "苏州", "无锡", "常州", "南京"],  # 重复
        "年份": [2023, 2023, 2023, 2023, 2023],
        "负债率(%)": [45.2, 52.1, 38.7, 61.3, 45.2],  # 重复
        "赤字率(%)": [3.1, 2.8, 4.2, 1.9, 3.1],
        "存贷比(%)": [78.5, 82.3, 71.2, 88.9, 78.5],
        "不良贷款率(%)": [1.2, 0.8, 1.5, 0.6, 1.2],
        "资本充足率(%)": [14.2, 15.1, 13.8, 16.2, 14.2],
    }
    return pd.DataFrame(data)


def create_dirty_data():
    """创建脏数据（各种问题）"""
    data = {
        "负债比率": [45.2, "N/A", 38.7, 61.3, 150.0],  # 有空值、类型不匹配、异常值
        "赤字比率": [3.1, 2.8, None, 1.9, 3.1],  # 有空值
        "贷存比": [78.5, 82.3, 71.2, 88.9, 78.5],
        "不良率": [1.2, 0.8, 1.5, 0.6, 1.2],
        "资本充足率": [14.2, 15.1, 13.8, 16.2, 14.2],
    }
    return pd.DataFrame(data)


def test_field_mapping():
    """测试字段映射"""
    print("\n=== 测试字段映射 ===")
    
    df = create_dirty_data()
    from services.data_pipeline.core import CORE_INDICATORS
    mapper = FieldMapper(indicators=CORE_INDICATORS)
    
    df_mapped, mappings = mapper.map_columns(df)
    
    print(f"原始列名: {list(df.columns)}")
    print(f"映射后列名: {list(df_mapped.columns)}")
    print(f"映射关系: {mappings}")
    
    assert len(mappings) > 0, "应该有字段映射"
    print("✅ 字段映射测试通过")


def test_schema_validation():
    """测试Schema验证"""
    print("\n=== 测试Schema验证 ===")
    
    df = create_test_data()
    validator = SchemaValidator()
    
    is_valid, errors = validator.validate(df)
    
    print(f"验证结果: {'通过' if is_valid else '失败'}")
    print(f"错误数: {len(errors)}")
    for err in errors:
        print(f"  - {err}")
    
    # 测试数据契约生成
    contract = validator.generate_contract()
    print(f"\n数据契约字段: {list(contract.get('columns', {}).keys())}")
    
    print("✅ Schema验证测试通过")


def test_data_cleaning():
    """测试数据清洗"""
    print("\n=== 测试数据清洗 ===")
    
    df = create_dirty_data()
    cleaner = DataCleaner()
    
    df_cleaned, stats = cleaner.clean(df)
    
    print(f"原始行数: {stats['original_rows']}")
    print(f"清洗后行数: {stats['final_rows']}")
    print(f"修改单元格数: {stats['total_cells_modified']}")
    print(f"操作统计:")
    for op in stats['operations']:
        print(f"  - {op['operation']}: {op['affected']} 个")
    
    print("✅ 数据清洗测试通过")


def test_quality_scoring():
    """测试质量评分"""
    print("\n=== 测试质量评分 ===")
    
    df = create_test_data()
    scorer = QualityScorer()
    
    report = scorer.score(df)
    
    print(f"总分: {report['total_score']:.2f}")
    print(f"维度评分:")
    for dim, score_info in report['dimensions'].items():
        print(f"  - {dim}: {score_info.get('score', 0):.2f}")
    print(f"警告: {report['warnings']}")
    
    print("✅ 质量评分测试通过")


def test_deduplication():
    """测试去重"""
    print("\n=== 测试去重 ===")
    
    df = create_test_data()
    dedup = DataDeduplicator(similarity_threshold=85)
    
    df_deduped, stats = dedup.deduplicate(df)
    
    print(f"原始行数: {stats['original_rows']}")
    print(f"去重后行数: {stats['final_rows']}")
    print(f"去除重复: {stats['removed']}")
    
    assert stats['removed'] > 0, "应该去除重复行"
    print("✅ 去重测试通过")


def test_timeseries_preprocessing():
    """测试时间序列预处理"""
    print("\n=== 测试时间序列预处理 ===")
    
    # 创建有异常值的时间序列数据
    np.random.seed(42)
    n = 20
    data = {
        "year": list(range(2004, 2004 + n)),
        "debt_ratio": np.random.normal(50, 5, n).tolist(),
        "deficit_ratio": np.random.normal(3, 0.5, n).tolist(),
    }
    # 添加异常值
    data["debt_ratio"][5] = 200  # 异常高值
    data["debt_ratio"][10] = -50  # 异常低值
    # 添加缺失值
    data["debt_ratio"][15] = np.nan
    
    df = pd.DataFrame(data)
    preprocessor = TimeSeriesPreprocessor(sigma_threshold=2.5)
    
    df_processed, stats = preprocessor.preprocess(df)
    
    print(f"处理列数: {len(stats['smoothed_columns'])}")
    print(f"检测到异常: {stats['anomalies_detected']}")
    print(f"修复异常: {stats['anomalies_fixed']}")
    print(f"插值数: {stats['interpolated_values']}")
    
    # 生成异常报告
    report = preprocessor.get_anomaly_report(df)
    print(f"异常报告: {report}")
    
    print("✅ 时间序列预处理测试通过")


def test_full_pipeline():
    """测试完整管道"""
    print("\n=== 测试完整管道 ===")
    
    df = create_dirty_data()
    pipeline = DataPipeline()
    
    result = pipeline.process(
        df=df,
        city="测试城市",
        year=2023,
        permission="gov",
    )
    
    print(f"成功: {result.success}")
    print(f"消息: {result.message}")
    print(f"原始行数: {result.original_rows}")
    print(f"清洗后行数: {result.cleaned_rows}")
    print(f"质量评分: {result.quality_score:.2f}")
    print(f"可信度权重: {result.confidence_weight:.2f}")
    print(f"字段映射: {result.field_mappings}")
    print(f"验证错误数: {len(result.validation_errors)}")
    print(f"清洗操作数: {len(result.cleaning_stats.get('operations', []))}")
    print(f"警告: {result.warnings}")
    
    assert result.success, f"管道处理失败: {result.message}"
    assert result.quality_score > 0, "质量评分应该大于0"
    assert result.confidence_weight > 0, "可信度权重应该大于0"
    
    print("✅ 完整管道测试通过")


if __name__ == "__main__":
    print("=" * 50)
    print("FiscalShieldAI 数据管道测试")
    print("=" * 50)
    
    test_field_mapping()
    test_schema_validation()
    test_data_cleaning()
    test_quality_scoring()
    test_deduplication()
    test_timeseries_preprocessing()
    test_full_pipeline()
    
    print("\n" + "=" * 50)
    print("🎉 所有测试通过！")
    print("=" * 50)
