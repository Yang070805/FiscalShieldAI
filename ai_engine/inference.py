# inference.py
"""
推理与部署模块 (Inference and Deployment Module)
核心功能：加载训练好的轻量级学生模型（LightTCN），对单个城市的最新时序数据进行预处理、风险预测，并生成包含预警等级和解释说明的完整报告。
此模块专为集成到移动端（vivo手机）应用程序而设计，满足 ≤3 秒的端侧推理要求。
"""

import torch
import torch.nn as nn
import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Any, Optional
import json
from datetime import datetime
import joblib
import warnings
warnings.filterwarnings('ignore')

class RiskPredictor:
    """
    风险预测器 (Risk Predictor)
    封装了模型加载、数据预处理、前向推理、结果解析与预警生成的全流程。
    """
    
    def __init__(self, 
                 model_path: str,
                 scaler_path: Optional[str] = None,
                 device: str = 'cpu'):
        """
        初始化风险预测器。

        参数:
            model_path (str): 训练好的LightTCN学生模型文件路径（.pth格式）。
            scaler_path (Optional[str]): 用于数据标准化的StandardScaler对象保存路径（.pkl或.joblib格式）。如果为None，则跳过标准化步骤。
            device (str): 指定模型运行的设备，'cpu' 或 'cuda'。默认为'cpu'以兼容移动端。
        """
        self.device = torch.device(device)
        print(f"正在加载模型，设备: {self.device}")
        
        # 1. 模型定义与加载
        checkpoint = torch.load(model_path, map_location=self.device)
        
        # 检测是否为 compact 模型
        if isinstance(checkpoint, dict) and 'config' in checkpoint and 'model_state_dict' in checkpoint:
            # Compact 模型（train_compact.py 训练的）
            cfg = checkpoint['config']
            
            class LightTCNCompact(torch.nn.Module):
                def __init__(self, input_channels=9, hidden_channels=12, output_dim=24,
                             num_classes=5, dropout=0.1):
                    super().__init__()
                    self.conv1 = torch.nn.Conv1d(input_channels, hidden_channels,
                                                 kernel_size=3, dilation=1, padding=1)
                    self.bn1 = torch.nn.BatchNorm1d(hidden_channels)
                    self.conv2 = torch.nn.Conv1d(hidden_channels, output_dim,
                                                 kernel_size=3, dilation=2, padding=2)
                    self.bn2 = torch.nn.BatchNorm1d(output_dim)
                    self.global_pool = torch.nn.AdaptiveAvgPool1d(1)
                    self.dropout = torch.nn.Dropout(dropout)
                    self.fiscal_head = torch.nn.Sequential(
                        torch.nn.Linear(output_dim, output_dim // 2),
                        torch.nn.ReLU(), self.dropout,
                        torch.nn.Linear(output_dim // 2, num_classes)
                    )
                    self.finance_head = torch.nn.Sequential(
                        torch.nn.Linear(output_dim, output_dim // 2),
                        torch.nn.ReLU(), self.dropout,
                        torch.nn.Linear(output_dim // 2, num_classes)
                    )
                def forward(self, x):
                    x = x.transpose(1, 2)
                    x = self.conv1(x)
                    x = self.bn1(x)
                    x = torch.nn.functional.relu(x)
                    x = self.dropout(x)
                    x = self.conv2(x)
                    x = self.bn2(x)
                    x = torch.nn.functional.relu(x)
                    x = self.dropout(x)
                    x = self.global_pool(x)
                    x = x.squeeze(-1)
                    return self.fiscal_head(x), self.finance_head(x)
            
            self.model = LightTCNCompact(
                input_channels=cfg.get('input_channels', 9),
                hidden_channels=cfg.get('hidden_channels', 12),
                output_dim=cfg.get('output_dim', 24),
                num_classes=cfg.get('num_classes', 5),
                dropout=cfg.get('dropout', 0.1)
            )
            self.model.load_state_dict(checkpoint['model_state_dict'])
            param_count = sum(p.numel() for p in self.model.parameters())
            print(f"Compact 模型加载成功: {param_count:,} 参数, 测试准确率={checkpoint.get('test_acc', 'N/A')}")
        else:
            # 原始 LightTCN 模型（知识蒸馏训练的）
            from models.stgnn import LightTCN
            self.model = LightTCN(
                input_channels=9,
                hidden_channels=32,
                output_dim=64,
                num_classes=5,
                dropout=0.1
            )
            if isinstance(checkpoint, dict) and 'student_state_dict' in checkpoint:
                self.model.load_state_dict(checkpoint['student_state_dict'])
                print(f"从检查点加载模型，最佳Epoch: {checkpoint.get('epoch', 'N/A')}, 验证损失: {checkpoint.get('val_loss', 'N/A'):.4f}")
            else:
                self.model.load_state_dict(checkpoint)
                print("加载模型状态字典成功。")
        
        self.model.to(self.device)
        self.model.eval()  # 将模型设置为评估模式，禁用Dropout等训练层
        print("模型加载完成并移至指定设备。")
        
        # 2. 加载数据标准化器 (Scaler)
        if scaler_path:
            try:
                self.scaler = joblib.load(scaler_path)
                print(f"标准化器从 '{scaler_path}' 加载成功。")
            except Exception as e:
                warnings.warn(f"无法加载标准化器: {e}。预测时将跳过标准化步骤。")
                self.scaler = None
        else:
            self.scaler = None
            print("未提供标准化器路径，将使用原始数据或假设输入已预处理。")
        
        # 3. 定义风险等级、颜色及预警消息映射
        self.risk_levels = ['低风险', '中等偏低', '中等', '中等偏高', '高风险']
        self.risk_colors = {
            '低风险': '#4CAF50',      # Green
            '中等偏低': '#8BC34A',    # Light Green
            '中等': '#FFEB3B',        # Yellow
            '中等偏高': '#FF9800',    # Orange
            '高风险': '#F44336'       # Red
        }
        
        # 4. 预警触发阈值：不同风险等级需要达到的最小置信度
        self.warning_thresholds = {
            '低风险': 0.70,
            '中等偏低': 0.60,
            '中等': 0.50,
            '中等偏高': 0.40,
            '高风险': 0.30
        }
        
        # 5. 基础特征列表（必须与训练时完全一致）
        self.base_features = [
            '负债率(%)', '债务率(%)', '赤字率(%)',
            '现金短期债务比', '短期债务占比(%)',
            '存贷比(%)',
            '不良贷款率(%)', '拨备覆盖率(%)', '资本充足率(%)'
        ]
        
        assert len(self.base_features) == 9, "基础特征数量必须为9。"

    def preprocess_single_city_data(self,
                                    data_df: pd.DataFrame,
                                    city_name: str = "目标城市") -> torch.Tensor:
        """
        对单个城市的原始时序数据进行预处理，转换为模型输入张量。

        步骤:
            1. 按年份排序，选取最近3年的数据。
            2. 提取指定的9项基础指标 + 9项同比变化率 = 共18维。
            3. 处理缺失值（用0填充）。
            4. 应用标准化（如果提供了scaler）。
            5. 取前9维（基础特征）转换为PyTorch张量。

        参数:
            data_df (pd.DataFrame): 包含'年份'列和9项基础指标列的DataFrame。
            city_name (str): 城市名称，用于错误提示。

        返回:
            torch.Tensor: 形状为 (1, 3, 9) 的张量。
        """
        if '年份' not in data_df.columns:
            raise ValueError(f"数据框必须包含'年份'列。")

        data_df = data_df.sort_values('年份').reset_index(drop=True)
        recent_years = data_df['年份'].tail(3).tolist()

        if len(recent_years) < 3:
            raise ValueError(f"'{city_name}'的数据不足3年（仅{len(recent_years)}年），无法构建时间窗口。")

        # ===== 全量历史数据特征提取 =====
        # 用全部可用年份计算平均同比变化率，替代第一个年份的全0填充
        all_years = sorted(data_df['年份'].unique())
        all_change_rates = []  # 存放所有年份的变化率
        for i in range(1, len(all_years)):
            curr_year_data = data_df[data_df['年份'] == all_years[i]]
            prev_year_data = data_df[data_df['年份'] == all_years[i-1]]
            if curr_year_data.empty or prev_year_data.empty:
                continue
            rates = []
            for feat in self.base_features:
                if feat in curr_year_data.columns and feat in prev_year_data.columns:
                    curr_val = curr_year_data[feat].values[0]
                    prev_val = prev_year_data[feat].values[0]
                    if not pd.isna(curr_val) and not pd.isna(prev_val) and prev_val != 0:
                        rates.append((curr_val - prev_val) / abs(prev_val))
                    else:
                        rates.append(0.0)
                else:
                    rates.append(0.0)
            all_change_rates.append(rates)

        # 计算平均变化率（9维）
        if all_change_rates:
            avg_change_rates = np.mean(all_change_rates, axis=0).tolist()
        else:
            avg_change_rates = [0.0] * len(self.base_features)

        features_list = []
        missing_features = []

        for year in recent_years:
            year_data = data_df[data_df['年份'] == year]
            if year_data.empty:
                raise ValueError(f"年份 {year} 的数据缺失。")

            # 1. 提取9项基础特征
            year_features = []
            for feat in self.base_features:
                if feat in year_data.columns:
                    val = year_data[feat].iloc[0]
                    if pd.isna(val):
                        year_features.append(0.0)
                        missing_features.append(f"{feat}({year})")
                    else:
                        year_features.append(float(val))
                else:
                    year_features.append(0.0)
                    missing_features.append(f"{feat}({year})")

            # 2. 计算9项同比变化率（用全量历史均值兜底）
            prev_year = year - 1
            prev_year_data = data_df[data_df['年份'] == prev_year]

            if len(prev_year_data) > 0:
                for feat in self.base_features:
                    if feat in year_data.columns and feat in prev_year_data.columns:
                        curr_val = year_data[feat].values[0]
                        prev_val = prev_year_data[feat].values[0]
                        if not pd.isna(curr_val) and not pd.isna(prev_val) and prev_val != 0:
                            change_rate = (curr_val - prev_val) / abs(prev_val)
                        else:
                            change_rate = avg_change_rates[self.base_features.index(feat)]
                    else:
                        change_rate = avg_change_rates[self.base_features.index(feat)]
                    year_features.append(change_rate)
            else:
                # 第一个年份无前一年数据，用全量历史平均变化率
                year_features.extend(avg_change_rates)

            features_list.append(year_features)  # 18维

        if missing_features:
            warnings.warn(f"城市 '{city_name}' 的以下特征存在缺失，已用0填充: {set(missing_features)}")

        features_array = np.array(features_list, dtype=np.float32)  # 形状: (3, 18)

        # 3. 标准化
        if self.scaler is not None:
            original_shape = features_array.shape
            features_flattened = features_array.reshape(-1, 18)
            features_normalized = self.scaler.transform(features_flattened)
            features_array = features_normalized.reshape(original_shape)
        else:
            warnings.warn("未应用标准化，预测结果可能不准确。")

        # 4. 转换为张量，只取前9维（基础特征）作为模型输入
        input_tensor = torch.FloatTensor(features_array).unsqueeze(0)[:, :, :9]  # (1, 3, 9)
        return input_tensor

    def predict(self, input_tensor: torch.Tensor) -> Dict[str, Any]:
        """
        执行模型前向传播，进行风险预测。

        参数:
            input_tensor (torch.Tensor): 预处理后的输入张量，形状为 (batch_size, 3, 9)。

        返回:
            Dict[str, Any]: 包含完整预测结果的字典，结构如下：
                - fiscal_risk: 财政风险详细结果
                - finance_risk: 金融风险详细结果
                - overall_risk: 综合风险评估
                - warning: 预警信息
                - explanation: 文本解释
                - timestamp: 预测时间戳
        """
        start_time = datetime.now()
        
        with torch.no_grad():  # 禁用梯度计算，节省内存和计算资源
            input_tensor = input_tensor.to(self.device)
            
            # 模型推理
            fiscal_logits, finance_logits = self.model(input_tensor)
            
            # 计算Softmax概率
            fiscal_probs = torch.softmax(fiscal_logits, dim=-1)
            finance_probs = torch.softmax(finance_logits, dim=-1)
            
            # 获取预测类别（风险等级）和置信度
            fiscal_pred_idx = torch.argmax(fiscal_probs, dim=-1).item()
            finance_pred_idx = torch.argmax(finance_probs, dim=-1).item()
            
            fiscal_confidence = fiscal_probs[0, fiscal_pred_idx].item()
            finance_confidence = finance_probs[0, finance_pred_idx].item()
            
            fiscal_risk_level = self.risk_levels[fiscal_pred_idx]
            finance_risk_level = self.risk_levels[finance_pred_idx]
            
            # 综合风险：取财政和金融风险中较高的等级
            overall_pred_idx = max(fiscal_pred_idx, finance_pred_idx)
            overall_risk_level = self.risk_levels[overall_pred_idx]
            overall_confidence = max(fiscal_confidence, finance_confidence)
            
            # 生成预警信息
            warning_info = self._generate_warning_info(overall_risk_level, overall_confidence)
            
            # 生成详细解释文本
            explanation_text = self._generate_explanation_text(
                fiscal_risk_level, finance_risk_level,
                fiscal_confidence, finance_confidence,
                input_tensor
            )
            
            inference_time = (datetime.now() - start_time).total_seconds() * 1000  # 毫秒
            
            result = {
                'fiscal_risk': {
                    'level': fiscal_risk_level,
                    'level_index': int(fiscal_pred_idx),
                    'confidence': float(fiscal_confidence),
                    'probability_distribution': fiscal_probs[0].cpu().numpy().tolist()
                },
                'finance_risk': {
                    'level': finance_risk_level,
                    'level_index': int(finance_pred_idx),
                    'confidence': float(finance_confidence),
                    'probability_distribution': finance_probs[0].cpu().numpy().tolist()
                },
                'overall_risk': {
                    'level': overall_risk_level,
                    'level_index': int(overall_pred_idx),
                    'confidence': float(overall_confidence)
                },
                'warning': {
                    'level': warning_info['level'],
                    'color': self.risk_colors.get(overall_risk_level, '#757575'),
                    'message': warning_info['message'],
                    'threshold_met': warning_info['threshold_met']
                },
                'explanation': explanation_text,
                'performance': {
                    'inference_time_ms': float(inference_time),
                    'device': str(self.device)
                },
                'timestamp': start_time.isoformat()
            }
            
            return result

    def _generate_warning_info(self, risk_level: str, confidence: float) -> Dict[str, Any]:
        """
        根据风险等级和置信度生成预警信息。

        参数:
            risk_level (str): 综合风险等级。
            confidence (float): 综合风险置信度。

        返回:
            Dict: 包含预警等级、消息和是否达到阈值的信息。
        """
        threshold = self.warning_thresholds.get(risk_level, 0.5)
        threshold_met = confidence >= threshold
        
        warning_configs = {
            '高风险': {'level': '红色预警', 'icon': '🚨', 'action': '立即采取应对措施'},
            '中等偏高': {'level': '橙色预警', 'icon': '⚠️', 'action': '加强监测和预防措施'},
            '中等': {'level': '黄色预警', 'icon': '⚠️', 'action': '保持关注并准备预案'},
            '中等偏低': {'level': '蓝色预警', 'icon': 'ℹ️', 'action': '定期监测'},
            '低风险': {'level': '正常', 'icon': '✅', 'action': '维持常规监测'}
        }
        
        config = warning_configs.get(risk_level, {'level': '未知', 'icon': '', 'action': ''})
        
        if threshold_met:
            message = f"{config['icon']} {config['level']}！检测到{risk_level}（置信度{confidence:.1%}），{config['action']}。"
        else:
            message = f"当前风险等级为{risk_level}，但置信度({confidence:.1%})低于预警阈值({threshold:.0%})，建议持续观察。"
            config['level'] = '需关注'
        
        return {
            'level': config['level'],
            'message': message,
            'threshold_met': threshold_met
        }
    
    def _generate_explanation_text(self,
                                  fiscal_risk: str,
                                  finance_risk: str,
                                  fiscal_conf: float,
                                  finance_conf: float,
                                  input_tensor: torch.Tensor) -> str:
        """
        生成易于理解的风险解释文本，模拟专家分析报告。

        参数:
            fiscal_risk (str): 财政风险等级。
            finance_risk (str): 金融风险等级。
            fiscal_conf (float): 财政风险置信度。
            finance_conf (float): 金融风险置信度。
            input_tensor (torch.Tensor): 原始输入数据，用于提取具体指标值。

        返回:
            str: 格式化的解释文本。
        """
        # 从输入张量中提取最新一年的指标值（假设是第三年）
        latest_metrics = input_tensor[0, -1, :].cpu().numpy()
        metric_dict = dict(zip(self.base_features, latest_metrics))
        
        explanation_parts = []
        
        # 1. 财政风险分析
        explanation_parts.append("【财政风险分析】")
        if fiscal_risk in ['中等偏高', '高风险']:
            explanation_parts.append(f"  等级：{fiscal_risk}（置信度{fiscal_conf:.1%}），表明财政压力显著。")
            # 高负债或低流动性是常见原因
            if metric_dict.get('负债率(%)', 0) > 60:
                explanation_parts.append(f"  - 主要原因：负债率({metric_dict.get('负债率(%)', 0):.1f}%)超过60%的安全线。")
            if metric_dict.get('现金短期债务比', 0) < 1.0:
                explanation_parts.append(f"  - 流动性风险：现金短期债务比({metric_dict.get('现金短期债务比', 0):.2f})低于1.0，短期偿债能力偏紧。")
            explanation_parts.append("  - 建议：严格控制新增债务，优化债务结构，提高流动性储备。")
        elif fiscal_risk == '中等':
            explanation_parts.append(f"  等级：{fiscal_risk}（置信度{fiscal_conf:.1%}），财政状况总体可控但存在一定压力。")
            explanation_parts.append("  - 建议：关注债务率与赤字率变化趋势，避免进一步恶化。")
        else:  # 低风险或中等偏低
            explanation_parts.append(f"  等级：{fiscal_risk}（置信度{fiscal_conf:.1%}），财政状况健康。")
            explanation_parts.append("  - 建议：维持当前审慎的财政管理策略。")
        
        # 2. 金融风险分析
        explanation_parts.append("\n【金融风险分析】")
        if finance_risk in ['中等偏高', '高风险']:
            explanation_parts.append(f"  等级：{finance_risk}（置信度{finance_conf:.1%}），金融体系稳健性面临挑战。")
            if metric_dict.get('存贷比(%)', 0) > 100:
                explanation_parts.append(f"  - 信贷扩张：存贷比({metric_dict.get('存贷比(%)', 0):.1f}%)偏高，可能存在信贷过度投放。")
            if metric_dict.get('不良贷款率(%)', 0) > 2.0:
                explanation_parts.append(f"  - 资产质量：不良贷款率({metric_dict.get('不良贷款率(%)', 0):.2f}%)超过2%的监管关注线。")
            explanation_parts.append("  - 建议：加强信贷资产质量审查，控制贷款增速，提高拨备覆盖率。")
        elif finance_risk == '中等':
            explanation_parts.append(f"  等级：{finance_risk}（置信度{finance_conf:.1%}），金融风险处于可接受范围。")
            explanation_parts.append("  - 建议：监控存贷比和资本充足率等关键指标。")
        else:
            explanation_parts.append(f"  等级：{finance_risk}（置信度{finance_conf:.1%}），金融体系运行稳健。")
            explanation_parts.append("  - 建议：继续保持良好的风险管理实践。")
        
        # 3. 综合结论与行动建议
        explanation_parts.append("\n【综合评估与建议】")
        overall_idx = max(self.risk_levels.index(fiscal_risk), self.risk_levels.index(finance_risk))
        overall_risk = self.risk_levels[overall_idx]
        
        if overall_risk in ['中等偏高', '高风险']:
            explanation_parts.append("综合风险较高，需启动跨部门风险应对机制。")
            explanation_parts.append("1. 短期内：召开财政与金融监管部门联席会议，制定应急预案。")
            explanation_parts.append("2. 中期：调整财政支出结构，强化金融宏观审慎管理。")
        elif overall_risk == '中等':
            explanation_parts.append("综合风险适中，需警惕风险传导与累积。")
            explanation_parts.append("1. 加强财政与金融数据的联动监测。")
            explanation_parts.append("2. 对风险较高的细分领域（如地方融资平台、房地产信贷）进行压力测试。")
        else:
            explanation_parts.append("综合风险较低，经济金融环境总体稳定。")
            explanation_parts.append("1. 坚持常态化风险监测，巩固现有成果。")
            explanation_parts.append("2. 利用当前窗口期，推进结构性改革，增强长期韧性。")
        
        explanation_parts.append(f"\n（分析基于最近3年的9项核心指标，采用'财智哨兵'AI模型于{datetime.now().strftime('%Y年%m月%d日 %H:%M')}生成）")
        
        return '\n'.join(explanation_parts)

    # 5城平均同比变化率（用于新城市预测时填充，避免全0偏差）
    # 运行 compute_avg_change_rates.py 生成，或手动填入
    DEFAULT_AVG_CHANGE_RATES = [
        0.024863,   # 负债率(%)
        0.011364,   # 债务率(%)
        0.045037,   # 赤字率(%)
        0.014798,   # 现金短期债务比
        -0.009063,  # 短期债务占比(%)
        0.009928,   # 存贷比(%)
        -0.080674,  # 不良贷款率(%)
        0.039847,   # 拨备覆盖率(%)
        0.031788    # 资本充足率(%)
    ]

    def predict_from_indicators(self, indicators: dict,
                                city_name: str = "自定义城市",
                                year: int = 2026) -> dict:

        """
        直接输入9个指标的字典，返回风险评估结果。
        不需要3年时序数据，自动构造模型输入。

        参数:
            indicators: dict，key为指标简称，value为数值
            例如: {"负债率": 62.5, "债务率": 185.0, ...}
        """
        # 指标简称 → 完整列名映射
        key_map = {
            "负债率": "负债率(%)",
            "债务率": "债务率(%)",
            "赤字率": "赤字率(%)",
            "现金短期债务比": "现金短期债务比",
            "短期债务占比": "短期债务占比(%)",
            "存贷比": "存贷比(%)",
            "不良贷款率": "不良贷款率(%)",
            "拨备覆盖率": "拨备覆盖率(%)",
            "资本充足率": "资本充足率(%)"
        }

        # 按 base_features 顺序组装一行 9 维特征
        row = []
        for feat in self.base_features:
            short_key = None
            for k, v in key_map.items():
                if v == feat:
                    short_key = k
                    break
            if short_key is None or short_key not in indicators:
                raise ValueError(
                    f"缺少指标: {list(key_map.keys())}"
                )
            row.append(float(indicators[short_key]))

        features_9d = np.array([row], dtype=np.float32)  # (1, 9)

        # 标准化：scaler 在训练时 fit 的是 18 维数据
        # 用5城平均同比变化率填充，而非全0（更接近真实分布）
        if self.scaler is not None:
            avg_rates = np.array([self.DEFAULT_AVG_CHANGE_RATES], dtype=np.float32)  # (1, 9)
            full_18d = np.concatenate([features_9d, avg_rates], axis=1)  # (1, 18)
            scaled_18d = self.scaler.transform(full_18d)
            features_9d = scaled_18d[:, :9]  # 只取前 9 维

        # 模型需要 (batch, 3, 9) 输入，把单时间步复制 3 次
        input_array = np.repeat(features_9d[:, np.newaxis, :], 3, axis=1)  # (1, 3, 9)
        input_tensor = torch.FloatTensor(input_array).to(self.device)

        # 直接调用已有的 predict() 方法
        result = self.predict(input_tensor)
        result['city'] = city_name
        result['year'] = year
        result['metrics'] = dict(zip(self.base_features, [float(v) for v in row]))
        return result


    def save_prediction_report(self, result: Dict, filepath: str = 'risk_report.json'):
        """
        将预测结果保存为JSON文件。

        参数:
            result (Dict): predict()方法返回的结果字典。
            filepath (str): 保存的文件路径。
        """
        # 确保字典可序列化（将numpy/torch类型转为Python原生类型）
        def convert_to_serializable(obj):
            if isinstance(obj, (np.integer, np.floating)):
                return float(obj) if isinstance(obj, np.floating) else int(obj)
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            elif isinstance(obj, torch.Tensor):
                return obj.cpu().numpy().tolist()
            elif isinstance(obj, datetime):
                return obj.isoformat()
            elif isinstance(obj, dict):
                return {k: convert_to_serializable(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_to_serializable(item) for item in obj]
            else:
                return obj
        
        serializable_result = convert_to_serializable(result)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(serializable_result, f, ensure_ascii=False, indent=2)
        print(f"预测报告已保存至: {filepath}")


# ==================== 使用示例与测试函数 ====================
def test_inference_with_sample_data():
    """
    使用模拟数据测试整个推理流程。
    此函数展示了如何在实际应用中使用RiskPredictor类。
    """
    print("="*60)
    print("开始测试'财智哨兵'推理模块")
    print("="*60)
    
    # 1. 初始化预测器 (请替换为实际路径)
    model_path = 'checkpoints/best_model_epoch35_20260410_224713.pth'
    scaler_path = './checkpoints/data_scaler.joblib'
    
    try:
        predictor = RiskPredictor(
            model_path=model_path,
            scaler_path=scaler_path,
            device='cpu'  # 移动端通常使用CPU
        )
    except Exception as e:
        print(f"初始化预测器失败: {e}")
        return
    
    # 2. 创建模拟数据 (模拟'镇江市'2022-2024年的数据)
    sample_data = pd.DataFrame({
        '年份': [2022, 2023, 2024],
        '负债率(%)': [14.5, 14.8, 15.1],
        '债务率(%)': [70.1, 70.5, 71.0],
        '赤字率(%)': [2.6, 2.7, 2.8],
        '现金短期债务比': [1.02, 1.05, 1.07],
        '短期债务占比(%)': [26.5, 26.0, 25.8],
        '存贷比(%)': [98.5, 99.0, 99.3],
        '不良贷款率(%)': [0.85, 0.82, 0.80],
        '拨备覆盖率(%)': [320.0, 325.0, 330.0],
        '资本充足率(%)': [16.5, 16.7, 16.9]
    })
    
    print(f"模拟数据预览:\n{sample_data.tail(3)}")
    
    # 3. 数据预处理
    try:
        input_tensor = predictor.preprocess_single_city_data(sample_data, city_name="镇江")
        print(f"预处理成功。输入张量形状: {input_tensor.shape}")
    except ValueError as e:
        print(f"数据预处理错误: {e}")
        return
    
    # 4. 执行预测
    print("\n" + "-"*40)
    print("开始模型推理...")
    result = predictor.predict(input_tensor)
    print("推理完成！")
    print("-"*40)
    
    # 5. 打印关键结果
    print(f"\n📊 预测结果摘要:")
    print(f"   财政风险: {result['fiscal_risk']['level']} (置信度: {result['fiscal_risk']['confidence']:.1%})")
    print(f"   金融风险: {result['finance_risk']['level']} (置信度: {result['finance_risk']['confidence']:.1%})")
    print(f"   综合风险: {result['overall_risk']['level']}")
    print(f"   预警等级: {result['warning']['level']}")
    print(f"   推理耗时: {result['performance']['inference_time_ms']:.2f} 毫秒")
    
    # 6. 打印详细解释
    print(f"\n📝 详细分析:")
    print(result['explanation'])
    
    # 7. 保存完整报告
    report_path = '镇江_2024年风险预测报告.json'
    predictor.save_prediction_report(result, report_path)
    
    # 8. 模拟移动端预警触发
    warning = result['warning']
    if warning['level'] in ['红色预警', '橙色预警']:
        print(f"\n🚨 移动端应触发弹窗预警: {warning['message']}")
    elif warning['level'] in ['黄色预警', '蓝色预警']:
        print(f"\n⚠️  移动端可推送通知: {warning['message']}")
    
    print("\n✅ 测试完成！")


if __name__ == "__main__":
    # 直接运行此文件以测试推理模块
    test_inference_with_sample_data()