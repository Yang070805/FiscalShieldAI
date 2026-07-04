"""
FiscalShieldAI 综合测试套件
===========================

覆盖所有核心功能：
1. 数据管道
2. 模型推理
3. 训练管道
4. API端点
"""

import sys
from pathlib import Path

# 确保backend目录在路径中
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

# 先导入models，避免循环导入
from models.prediction import Prediction
from models.training import TrainingRecord

import pandas as pd
import numpy as np


def test_data_pipeline():
    """测试数据管道"""
    print("\n=== 测试数据管道 ===")
    
    from services.data_pipeline import DataPipeline
    
    # 创建测试数据
    data = {
        '负债率': [45.2, 52.1, 38.7, 61.3, 55.8],
        '赤字率': [3.1, 2.8, 4.2, 1.9, 2.5],
        '存贷比': [78.5, 82.3, 71.2, 88.9, 85.6],
        '不良贷款率': [1.2, 0.8, 1.5, 0.6, 0.9],
        '资本充足率': [14.2, 15.1, 13.8, 16.2, 15.5],
    }
    df = pd.DataFrame(data)
    
    pipeline = DataPipeline()
    result = pipeline.process(df, city='测试', year=2023, permission='gov')
    
    assert result.success, f"管道失败: {result.message}"
    assert result.quality_score > 0, "质量评分应大于0"
    assert result.confidence_weight > 0, "可信度权重应大于0"
    assert result.processed_data is not None, "处理后数据不应为空"
    
    print(f"✅ 数据管道: 质量={result.quality_score:.2f}, 可信度={result.confidence_weight:.2f}")


def test_model_prediction():
    """测试模型推理"""
    print("\n=== 测试模型推理 ===")
    
    from services.ai_engine import predict_by_city, get_available_cities
    
    # 获取可用城市
    cities = get_available_cities()
    assert len(cities) == 5, f"应有5个城市，实际{len(cities)}"
    print(f"可用城市: {cities}")
    
    # 测试已知城市
    result = predict_by_city('南京', 2026)
    assert 'risk_score' in result, "结果应包含risk_score"
    assert 'risk_level' in result, "结果应包含risk_level"
    assert result.get('source') == 'model', "已知城市应使用模型预测"
    print(f"✅ 南京预测: score={result['risk_score']}, level={result['risk_level']}")
    
    # 测试陌生城市
    result = predict_by_city('北京', 2026)
    assert 'risk_score' in result, "结果应包含risk_score"
    assert result.get('source') == 'fallback', "陌生城市应使用兜底预测"
    print(f"✅ 北京预测(兜底): score={result['risk_score']}, level={result['risk_level']}")


def test_training_pipeline():
    """测试训练管道"""
    print("\n=== 测试训练管道 ===")
    
    from services.training_pipeline import start_training, get_training_status, _run_training_sync
    
    # 检查初始状态
    status = get_training_status()
    assert status['status'] == 'idle', "初始状态应为idle"
    
    # 执行小规模训练
    _run_training_sync(epochs=2, incremental=False)
    
    # 检查训练后状态
    status = get_training_status()
    assert status['status'] == 'completed', f"训练后状态应为completed，实际为{status['status']}"
    assert status['accuracy'] is not None, "应有准确率"
    assert status['accuracy'] > 0, "准确率应大于0"
    
    print(f"✅ 训练完成: epoch={status['current_epoch']}, acc={status['accuracy']:.4f}")


def test_api_endpoints():
    """测试API端点"""
    print("\n=== 测试API端点 ===")
    
    from api.v1.endpoints import (
        auth, predict, report, chat, search,
        upload, training, monitor, llm_config, data_pipeline
    )
    
    # 检查所有路由都已注册
    routers = {
        'auth': auth.router,
        'predict': predict.router,
        'report': report.router,
        'chat': chat.router,
        'search': search.router,
        'upload': upload.router,
        'training': training.router,
        'monitor': monitor.router,
        'llm_config': llm_config.router,
        'data_pipeline': data_pipeline.router,
    }
    
    total_routes = 0
    for name, router in routers.items():
        routes = [r for r in router.routes if hasattr(r, 'path')]
        total_routes += len(routes)
        print(f"  {name}: {len(routes)} 个路由")
    
    assert total_routes >= 25, f"应有至少25个路由，实际{total_routes}"
    print(f"✅ API端点: 共{total_routes}个路由")


def test_error_handling():
    """测试错误处理"""
    print("\n=== 测试错误处理 ===")
    
    from services.ai_engine import predict_by_city
    from services.data_pipeline import DataPipeline
    import pandas as pd
    
    # 测试空数据
    pipeline = DataPipeline()
    result = pipeline.process(pd.DataFrame(), city='test', year=2023)
    # 空数据可能返回success=True但quality_score=0，或返回success=False
    if result.success:
        assert result.quality_score == 0, "空数据质量评分应为0"
        print(f"✅ 空数据处理: {result.message} (质量评分=0)")
    else:
        print(f"✅ 空数据处理: {result.message}")
    
    # 测试无效输入
    result = predict_by_city('', 2026)
    assert 'risk_score' in result, "空城市名应返回结果（兜底）"
    print(f"✅ 空城市名: 返回兜底结果")
    
    # 测试极端年份
    result = predict_by_city('南京', 9999)
    assert 'risk_score' in result, "极端年份应返回结果"
    print(f"✅ 极端年份: 返回结果")


if __name__ == "__main__":
    print("=" * 60)
    print("FiscalShieldAI 综合测试")
    print("=" * 60)
    
    test_data_pipeline()
    test_model_prediction()
    test_training_pipeline()
    test_api_endpoints()
    test_error_handling()
    
    print("\n" + "=" * 60)
    print("🎉 所有测试通过！")
    print("=" * 60)
