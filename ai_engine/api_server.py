"""
api_server.py
Qt-Python 桥接通信服务

功能：接收 Qt 前端的请求，调用 AI 模型进行预测，返回 JSON 格式结果
通信方式：TCP Socket（端口 9527）

修改记录：
- 2024-04-03: 适配 Python 3.12 + Qt6.10 环境
- 模型路径改为可配置
- 增加模型延迟加载（首次请求时才加载）
- 修复 _handle_report 中重复 import 的问题
- 增加 /predict 批量预测支持
"""

import sys
import os
import json
import socket
import threading
import traceback
from datetime import datetime
from pathlib import Path


class QtBridgeServer:
    """
    Qt-Python 桥接服务器

    工作流程：
    1. Qt 前端通过 QProcess 启动本 Python 服务
    2. Qt 通过 TCP Socket 发送 JSON 请求
    3. 本服务解析请求，调用 AI 模型，返回 JSON 响应
    4. Qt 解析响应并更新界面

    支持的请求类型：
    - health: 健康检查（测试连接是否正常）
    - predict: 对单个城市进行财政风险预测
    - predict_batch: 批量预测多个城市
    - report: 使用 MiMo 生成分析报告
    - models: 列出已加载的模型信息
    """
    
    def __init__(self, host='127.0.0.1', port=9527,
                 checkpoint_dir: str = './checkpoints'):
        self.host = host
        self.port = port
        self.checkpoint_dir = Path(checkpoint_dir)
        self.predictor = None
        self.report_gen = None
        self.running = False
        self._models_loaded = False
        # 报告缓存目录
        self.report_cache_dir = Path(__file__).parent / 'report_cache'
        self.report_cache_dir.mkdir(exist_ok=True)
    
    def _init_models(self):
        """
        加载 AI 模型（延迟加载模式）
        首次调用时加载，之后复用（模型常驻内存）
        """
        if self._models_loaded:
            return
        
        print("[初始化] 正在加载 AI 模型...", flush=True)
        
        # 确保 ai_engine 目录在 sys.path 中
        import sys
        ai_engine_dir = str(Path(__file__).parent)
        if ai_engine_dir not in sys.path:
            sys.path.insert(0, ai_engine_dir)
        
        # 尝试加载学生模型
        try:
            from inference import RiskPredictor
            
            # 优先加载 compact 模型（2,026参数，83%压缩）
            compact_models = list(self.checkpoint_dir.glob('compact_model_*.pth'))
            if compact_models:
                model_path = sorted(compact_models)[-1]  # 最新的
                print(f"[初始化] 使用 Compact 模型: {model_path.name}", flush=True)
                scaler_path = self.checkpoint_dir / 'data_scaler.joblib'
            else:
                model_path = self.checkpoint_dir / 'best_model_epoch35_20260410_224713.pth'
                scaler_path = self.checkpoint_dir / 'data_scaler.joblib'
            
            if model_path.exists() and scaler_path.exists():
                self.predictor = RiskPredictor(
                    model_path=str(model_path),
                    scaler_path=str(scaler_path),
                    device='cpu'
                )
                print("[初始化] 学生模型加载完成", flush=True)
            else:
                print(f"[警告] 模型文件不存在: {model_path}", flush=True)
                print("[警告] 将使用模拟模式运行", flush=True)
                self.predictor = None
        except ImportError:
            print("[警告] inference 模块未安装，将使用模拟模式", flush=True)
            self.predictor = None
        except Exception as e:
            print(f"[警告] 学生模型加载失败: {e}", flush=True)
            self.predictor = None
        
        # 初始化 MiMo 报告生成器
        try:
            from bluelm_report import ReportGenerator
            self.report_gen = ReportGenerator()
            print("[初始化] MiMo 报告生成器就绪", flush=True)
        except Exception as e:
            print(f"[警告] MiMo 初始化失败: {e}", flush=True)
            self.report_gen = None
        
        self._models_loaded = True
        print("[初始化] 所有组件加载完成，服务就绪", flush=True)
    
    def handle_request(self, request_data: dict) -> dict:
        """处理 Qt 前端的请求"""
        action = request_data.get('action', '')
        
        try:
            handlers = {
                'health': self._handle_health,
                'predict': self._handle_predict,
                'predict_custom': self._handle_predict_custom,
                'predict_batch': self._handle_predict_batch,
                'predict_by_city': self._handle_predict_by_city,
                'report': self._handle_report,
                'models': self._handle_models,
            }
            
            handler = handlers.get(action)
            if handler:
                return handler(request_data)
            else:
                return {
                    'status': 'error',
                    'message': f'未知操作: {action}',
                    'supported_actions': list(handlers.keys())
                }
        
        except Exception as e:
            return {
                'status': 'error',
                'message': str(e),
                'traceback': traceback.format_exc()
            }
    
    def _handle_health(self, request_data: dict) -> dict:
        """健康检查"""
        return {
            'status': 'ok',
            'timestamp': datetime.now().isoformat(),
            'server': 'FiscalShield AI Bridge v1.0',
            'python_version': sys.version,
            'models_loaded': {
                'predictor': self.predictor is not None,
                'report_generator': self.report_gen is not None
            }
        }
    
    def _handle_models(self, request_data: dict) -> dict:
        """列出模型信息"""
        return {
            'status': 'ok',
            'models': {
                'predictor': {
                    'loaded': self.predictor is not None,
                    'type': type(self.predictor).__name__ if self.predictor else None,
                    'device': 'cpu'
                },
                'report_generator': {
                    'loaded': self.report_gen is not None,
                    'type': type(self.report_gen).__name__ if self.report_gen else None,
                    'api_configured': bool(self.report_gen.api_key) if self.report_gen else False,
                }
            },
            'checkpoint_dir': str(self.checkpoint_dir),
            'checkpoint_exists': self.checkpoint_dir.exists()
        }
    
    def _handle_predict(self, request_data: dict) -> dict:
        """处理单个城市风险预测请求"""
        city = request_data.get('city', '')
        year = request_data.get('year', 2024)
        
        if self.predictor is None:
            # 模拟模式：返回示例数据
            return self._simulated_predict(city, year)
        
        # 实际推理
        try:
            import pandas as pd
            data = request_data.get('data', {})
            df = pd.DataFrame(data)
            input_tensor = self.predictor.preprocess_single_city_data(df, city_name=city)
            result = self.predictor.predict(input_tensor)
            result['status'] = 'ok'
            result['city'] = city
            result['year'] = year
            result['mode'] = 'real'
            return result
        except Exception as e:
            return {
                'status': 'error',
                'message': f'预测失败: {e}',
                'city': city,
                'year': year
            }
    
    def _handle_predict_batch(self, request_data: dict) -> dict:
        """批量预测多个城市（调用 predict_by_city 逐个推理）"""
        cities = request_data.get('cities', [])
        year = request_data.get('year', 2026)
        need_report = request_data.get('report', False)
        role = request_data.get('role', 'gov')
        enterprise_id = request_data.get('enterprise_id', None)
        data_consent = request_data.get('data_consent', False)

        if not cities:
            return {'status': 'error', 'message': '缺少 cities 列表'}

        results = []
        for city in cities:
            sub_request = {
                'action': 'predict_by_city',
                'city': city,
                'year': year,
                'report': need_report,
                'role': role,
                'enterprise_id': enterprise_id,
                'data_consent': data_consent
            }
            result = self._handle_predict_by_city(sub_request)
            results.append(result)

        success_count = sum(1 for r in results if r.get('status') == 'ok')
        return {
            'status': 'ok',
            'count': len(results),
            'success_count': success_count,
            'fail_count': len(results) - success_count,
            'results': results
        }

    def _handle_predict_by_city(self, request_data: dict) -> dict:
        """
        便捷预测接口：传城市名+年份，自动加载数据并预测

        请求格式：
            {
                "action": "predict_by_city",
                "city": "南京",
                "year": 2026,
                "report": true  // 可选，是否生成大模型报告
            }

        返回格式：
            {
                "status": "ok",
                "city": "南京",
                "year": 2026,
                "fiscal_risk": { ... },
                "finance_risk": { ... },
                "overall_risk": { ... },
                "warning": { ... },
                "explanation": "...",
                "ai_report": "..." (可选),
                "performance": { ... }
            }
        """
        city = request_data.get('city', '')
        year = request_data.get('year', 2026)
        need_report = request_data.get('report', False)
        role = request_data.get('role', 'gov')  # gov=政务 / enterprise=企业 / citizen=民用
        enterprise_id = request_data.get('enterprise_id', None)  # 企业版必填
        data_consent = request_data.get('data_consent', False)   # 是否同意数据用于模型优化

        if not city:
            return {'status': 'error', 'message': '缺少 city 字段'}

        # 角色校验
        valid_roles = ['gov', 'enterprise', 'citizen']
        if role not in valid_roles:
            return {'status': 'error', 'message': f'无效角色: {role}，可选: {valid_roles}'}

        # 企业版必须提供 enterprise_id（数据隔离）
        if role == 'enterprise' and not enterprise_id:
            return {'status': 'error', 'message': '企业版必须提供 enterprise_id 字段'}

        # 模拟模式
        if self.predictor is None:
            result = self._simulated_predict(city, year)
            result['source'] = 'simulated'
            return result

        try:
            import pandas as pd
            from pathlib import Path

            # 自动查找数据文件
            data_dir = Path(__file__).parent / 'data'
            data_file = data_dir / f'{city}_data.xlsx'

            if not data_file.exists():
                # 不在已训练城市列表中，走自定义预测路径
                return {
                    'status': 'error',
                    'message': f'未找到 {city} 的历史数据文件，请使用 predict_custom 接口传入指标数据',
                    'available_cities': self._get_available_cities(),
                    'hint': '可用 predict_custom 传入9个指标值进行预测'
                }

            # 加载数据
            df = pd.read_excel(str(data_file))

            if '年份' not in df.columns:
                return {'status': 'error', 'message': f'{city} 数据文件缺少"年份"列'}

            # 检查数据年数
            available_years = sorted(df['年份'].unique())
            if len(available_years) < 3:
                return {
                    'status': 'error',
                    'message': f'{city} 数据不足3年（仅有{len(available_years)}年: {available_years}），无法预测',
                    'available_years': [int(y) for y in available_years]
                }

            # 取最近3年数据
            recent_years = available_years[-3:]
            df_recent = df[df['年份'].isin(recent_years)].copy()

            print(f"[predict_by_city] 城市={city}, 使用年份={recent_years}", flush=True)

            # 调用推理引擎
            input_tensor = self.predictor.preprocess_single_city_data(
                df_recent, city_name=city
            )
            result = self.predictor.predict(input_tensor)

            # 补充基本信息
            result['city'] = city
            result['year'] = year
            result['source'] = 'model'
            result['data_years'] = [int(y) for y in recent_years]

            # 提取最新一年的指标
            latest = df_recent[df_recent['年份'] == recent_years[-1]]
            metrics = {}
            for col in self.predictor.base_features:
                if col in latest.columns:
                    val = latest[col].iloc[0]
                    metrics[col] = float(val) if not pd.isna(val) else 0.0
            result['metrics'] = metrics

            # 可选：生成大模型报告（带缓存）
            if need_report:
                report_result = self._get_or_generate_report(result, city, year, role)
                result['ai_report'] = report_result['report']
                result['report_generator'] = report_result['generator']
                result['report_cached'] = report_result.get('cached', False)

            # ===== 数据治理字段 =====
            result['role'] = role
            result['data_consent'] = data_consent
            if enterprise_id:
                result['enterprise_id'] = enterprise_id

            # ===== 角色差异化输出 =====
            result = self._filter_by_role(result, role)

            return result

        except Exception as e:
            import traceback
            return {
                'status': 'error',
                'message': f'预测失败: {e}',
                'traceback': traceback.format_exc()
            }

    def _get_available_cities(self) -> list:
        """获取可用城市列表"""
        from pathlib import Path
        data_dir = Path(__file__).parent / 'data'
        cities = []
        for f in data_dir.glob('*_data.xlsx'):
            city = f.stem.replace('_data', '')
            cities.append(city)
        return sorted(cities)

    def _filter_by_role(self, result: dict, role: str) -> dict:
        """
        按角色过滤输出内容

        政务版(gov):     全量数据 + 详细报告 + 审计字段
        企业版(enterprise): 核心指标 + 专业报告
        民用版(citizen):   简化结果 + 隐私优先
        """
        if role == 'gov':
            # 政务版：全量输出，增加审计字段
            result['audit'] = {
                'access_level': 'government',
                'data_scope': 'full',
                'export_allowed': True,
                'retention_days': 365
            }
            return result

        elif role == 'enterprise':
            # 企业版：保留核心指标，去掉内部模型细节
            filtered = {
                'status': result.get('status'),
                'city': result.get('city'),
                'year': result.get('year'),
                'role': role,
                'enterprise_id': result.get('enterprise_id'),
                'data_consent': result.get('data_consent', False),
                'overall_risk': result.get('overall_risk'),
                'warning': result.get('warning'),
                'metrics': result.get('metrics'),
                'explanation': result.get('explanation'),
                'performance': result.get('performance'),
            }
            # 保留报告（如有）
            for key in ['ai_report', 'report_generator', 'report_cached']:
                if key in result:
                    filtered[key] = result[key]
            # 企业版：去掉概率分布等模型内部细节
            return filtered

        elif role == 'citizen':
            # 民用版：最简化，只保留用户关心的信息
            level = result.get('overall_risk', {}).get('level', '未知')
            confidence = result.get('overall_risk', {}).get('confidence', 0)
            warning = result.get('warning', {})

            filtered = {
                'status': result.get('status'),
                'city': result.get('city'),
                'year': result.get('year'),
                'role': role,
                'data_consent': result.get('data_consent', False),
                'risk_summary': {
                    'level': level,
                    'confidence': confidence,
                    'warning_message': warning.get('message', ''),
                    'color': warning.get('color', '#757575')
                },
                'key_metrics': {},
            }
            # 只给用户看最关键的3个指标
            metrics = result.get('metrics', {})
            for key in ['负债率(%)', '赤字率(%)', '现金短期债务比']:
                if key in metrics:
                    filtered['key_metrics'][key] = metrics[key]
            # 保留报告（如有）
            for key in ['ai_report', 'report_generator', 'report_cached']:
                if key in result:
                    filtered[key] = result[key]
            # 民用版：不暴露模型细节、概率分布、推理时间等
            return filtered

        return result

    def _get_or_generate_report(self, prediction: dict, city: str, year: int, role: str) -> dict:
        """
        报告缓存逻辑：
        1. 检查缓存是否存在（city+year+role）
        2. 缓存命中 → 直接返回
        3. 缓存未命中 → 调用蓝心生成 → 存入缓存
        """
        import hashlib

        # 缓存 key：城市+年份+角色的哈希
        cache_key = f"{city}_{year}_{role}"
        cache_hash = hashlib.md5(cache_key.encode()).hexdigest()[:12]
        cache_file = self.report_cache_dir / f"{cache_hash}.json"

        # 检查缓存
        if cache_file.exists():
            try:
                import json as _json
                with open(cache_file, 'r', encoding='utf-8') as f:
                    cached = _json.load(f)
                print(f"[报告缓存] 命中: {cache_key}", flush=True)
                return {
                    'report': cached['report'],
                    'generator': cached.get('generator', 'cache'),
                    'cached': True
                }
            except Exception:
                pass  # 缓存损坏，重新生成

        # 缓存未命中，生成报告
        if self.report_gen is None:
            try:
                from bluelm_report import ReportGenerator
                self.report_gen = ReportGenerator()
            except Exception:
                return {
                    'report': '报告生成器初始化失败',
                    'generator': 'error',
                    'cached': False
                }

        try:
            report = self.report_gen.generate_report(prediction)
            generator = 'bluelm' if self.report_gen.api_key else 'local-template'

            # 写入缓存
            import json as _json
            with open(cache_file, 'w', encoding='utf-8') as f:
                _json.dump({
                    'report': report,
                    'generator': generator,
                    'city': city,
                    'year': year,
                    'role': role
                }, f, ensure_ascii=False, indent=2)

            print(f"[报告缓存] 新增: {cache_key}", flush=True)
            return {
                'report': report,
                'generator': generator,
                'cached': False
            }
        except Exception as e:
            return {
                'report': f'报告生成失败: {e}',
                'generator': 'error',
                'cached': False
            }

    def _simulated_predict(self, city: str, year: int) -> dict:
        """生成模拟预测数据"""
        import random
        random.seed(hash(city) + year)
        
        levels = ['低风险', '中等偏低', '中等', '中等偏高', '高风险']
        level_idx = random.randint(0, 4)
        
        probs = [random.random() for _ in range(5)]
        total = sum(probs)
        probs = [p / total for p in probs]
        probs[level_idx] = max(probs)  # 确保选中的等级概率最高
        
        return {
            'status': 'ok',
            'mode': 'simulated',
            'city': city,
            'year': year,
            'fiscal_risk': {
                'level': levels[level_idx],
                'level_index': level_idx,
                'confidence': round(random.uniform(0.6, 0.95), 2),
                'probability_distribution': [round(p, 3) for p in probs]
            },
            'metrics': {
                '负债率(%)': round(random.uniform(10, 65), 1),
                '债务率(%)': round(random.uniform(50, 120), 1),
                '赤字率(%)': round(random.uniform(1.0, 4.5), 1),
                '现金短期债务比': round(random.uniform(0.8, 1.5), 2),
                '短期债务占比(%)': round(random.uniform(15, 40), 1),
                '存贷比(%)': round(random.uniform(70, 110), 1),
                '不良贷款率(%)': round(random.uniform(0.5, 3.0), 2),
                '拨备覆盖率(%)': round(random.uniform(100, 400), 1),
                '资本充足率(%)': round(random.uniform(10, 18), 1),
            },
            'performance': {
                'inference_time_ms': round(random.uniform(3, 8), 1),
                'device': 'cpu'
            }
        }

    def _predict_with_history(self, city: str, year: int,
                              new_indicators: dict) -> dict:
        """有历史数据的城市：加载Excel时序数据 + 用户新指标覆盖最新年，走3年时序推理"""
        import pandas as pd

        data_file = self.checkpoint_dir.parent / 'data' / f'{city}_data.xlsx'
        df = pd.read_excel(data_file)

        # 用用户输入的新指标覆盖最新一年的数据
        if new_indicators:
            latest_year = df['年份'].max()
            key_map = {
                "负债率": "负债率(%)", "债务率": "债务率(%)",
                "赤字率": "赤字率(%)", "现金短期债务比": "现金短期债务比",
                "短期债务占比": "短期债务占比(%)", "存贷比": "存贷比(%)",
                "不良贷款率": "不良贷款率(%)", "拨备覆盖率": "拨备覆盖率(%)",
                "资本充足率": "资本充足率(%)"
            }
            for short_key, full_key in key_map.items():
                if short_key in new_indicators and full_key in df.columns:
                    df.loc[df['年份'] == latest_year, full_key] = float(new_indicators[short_key])

        # 时序推理
        input_tensor = self.predictor.preprocess_single_city_data(df, city_name=city)
        result = self.predictor.predict(input_tensor)
        result['city'] = city
        result['year'] = year
        result['metrics'] = {
            key: float(new_indicators.get(short, 0))
            for short, key in key_map.items()
        }
        return result

    def _handle_predict_custom(self, request_data: dict) -> dict:
        """处理自定义指标预测请求：有历史数据走时序推理，新城市走单点推理"""
        indicators = request_data.get('indicators', {})
        city = request_data.get('city', '自定义城市')
        year = request_data.get('year', 2026)

        if not indicators:
            return {'status': 'error', 'message': '缺少 indicators 字段'}
        if self.predictor is None:
            return {'status': 'error', 'message': '模型未加载，无法进行自定义预测'}

        try:
            # 判断城市是否在数据库中
            known_cities = ['南京', '苏州', '无锡', '常州', '镇江']
            data_file = self.checkpoint_dir.parent / 'data' / f'{city}_data.xlsx'
            print(f"[DEBUG] 查找数据文件: {data_file}, 存在={data_file.exists()}", flush=True)

            if city in known_cities and data_file.exists():
                # 有历史数据：用3年时序推理
                result = self._predict_with_history(city, year, indicators)
                result['mode'] = 'history'
            else:
                # 新城市：纯用输入指标推理
                result = self.predictor.predict_from_indicators(
                    indicators, city_name=city, year=year
                )
                result['mode'] = 'custom'

            result['metrics'] = {
                '负债率(%)': float(indicators.get('负债率', 0)),
                '债务率(%)': float(indicators.get('债务率', 0)),
                '赤字率(%)': float(indicators.get('赤字率', 0)),
                '现金短期债务比': float(indicators.get('现金短期债务比', 0)),
                '短期债务占比(%)': float(indicators.get('短期债务占比', 0)),
                '存贷比(%)': float(indicators.get('存贷比', 0)),
                '不良贷款率(%)': float(indicators.get('不良贷款率', 0)),
                '拨备覆盖率(%)': float(indicators.get('拨备覆盖率', 0)),
                '资本充足率(%)': float(indicators.get('资本充足率', 0)),
            }
            result['status'] = 'ok'
            result['city'] = city
            result['year'] = year

            # 调用 MiMo 生成分析报告
            if self.report_gen is None:
                try:
                    from bluelm_report import ReportGenerator
                    self.report_gen = ReportGenerator()
                except Exception:
                    pass

            if self.report_gen is not None:
                try:
                    report = self.report_gen.generate_report(result)
                    result['ai_report'] = report
                    result['report_generator'] = 'mimo-v2-pro' if self.report_gen.api_key else 'local-template'
                except Exception as e:
                    result['ai_report'] = f'报告生成失败: {e}'
                    result['report_generator'] = 'error'

            return result

        except Exception as e:
            return {'status': 'error', 'message': f'预测失败: {e}'}

    def _handle_report(self, request_data: dict) -> dict:
        """处理报告生成请求（带缓存）"""
        prediction = request_data.get('prediction', {})
        city = prediction.get('city', 'unknown')
        year = prediction.get('year', 2026)
        role = request_data.get('role', 'gov')

        report_result = self._get_or_generate_report(prediction, city, year, role)

        return {
            'status': 'ok',
            'report': report_result['report'],
            'generator': report_result['generator'],
            'cached': report_result.get('cached', False),
            'timestamp': datetime.now().isoformat()
        }
    
    def start(self):
        """启动 TCP 服务器"""
        # 懒加载：不在启动时加载模型，等第一个请求来再加载
        print("[服务器] 模型将在首次请求时加载（懒加载模式）", flush=True)
        
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.port))
        server.listen(5)
        self.running = True
        
        print(f"[服务器] 🚀 监听 {self.host}:{self.port}", flush=True)
        print("[服务器] 等待 Qt 前端连接...", flush=True)
        
        while self.running:
            try:
                conn, addr = server.accept()
                thread = threading.Thread(
                    target=self._handle_client,
                    args=(conn, addr),
                    daemon=True
                )
                thread.start()
            except KeyboardInterrupt:
                print("\n[服务器] 收到中断信号，正在关闭...", flush=True)
                break
            except Exception as e:
                print(f"[服务器] 接受连接失败: {e}", flush=True)
        
        server.close()
        print("[服务器] 已关闭", flush=True)
    
    def _handle_client(self, conn, addr):
        """处理单个客户端连接（支持粘包处理）"""
        try:
            # 先读取长度前缀（4字节大端），如果没有前缀则按老协议处理
            data = b''
            while True:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                data += chunk
                # 简单判断：如果已经收到完整 JSON（以 } 结尾），就停止
                try:
                    json.loads(data.decode('utf-8'))
                    break
                except json.JSONDecodeError:
                    continue
            
            if not data:
                return
            
            request = json.loads(data.decode('utf-8'))
            action = request.get('action', 'unknown')
            print(f"[请求] {addr} -> {action}", flush=True)
            
            # 首次请求时加载模型
            self._init_models()
            
            response = self.handle_request(request)
            
            response_json = json.dumps(response, ensure_ascii=False)
            conn.sendall(response_json.encode('utf-8'))
            
            print(f"[响应] {addr} <- status={response.get('status', '?')}", flush=True)
        
        except json.JSONDecodeError:
            error_resp = {'status': 'error', 'message': '无效的 JSON 数据'}
            conn.sendall(json.dumps(error_resp).encode('utf-8'))
        except Exception as e:
            error_resp = {'status': 'error', 'message': str(e)}
            try:
                conn.sendall(json.dumps(error_resp).encode('utf-8'))
            except Exception:
                pass
        finally:
            conn.close()


def main():
    """主入口"""
    import argparse
    
    parser = argparse.ArgumentParser(description='FiscalShield AI Bridge Server')
    parser.add_argument('--host', default='127.0.0.1', help='监听地址')
    parser.add_argument('--port', type=int, default=9527, help='监听端口')
    parser.add_argument('--checkpoint-dir', default='./checkpoints', help='模型目录')
    
    args = parser.parse_args()
    
    print("=" * 50, flush=True)
    print("  「财智哨兵」Qt-Python 桥接服务 v1.0", flush=True)
    print(f"  Python {sys.version}", flush=True)
    print("=" * 50, flush=True)
    
    server = QtBridgeServer(
        host=args.host,
        port=args.port,
        checkpoint_dir=args.checkpoint_dir
    )
    server.start()


if __name__ == "__main__":
    main()
