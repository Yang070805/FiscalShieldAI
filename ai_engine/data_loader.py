# data_loader.py
"""
城市风险数据加载与预处理模块
主要功能：
1. 从Excel/CSV文件加载苏南五市的财政金融数据
2. 构建时空图数据结构
3. 划分训练集、验证集和测试集
4. 为PyTorch Geometric准备图数据格式
"""

import numpy as np
import pandas as pd
import torch
from torch.utils.data import Dataset, DataLoader
from torch_geometric.data import Data, Batch
import os
import pickle
from typing import Dict, List, Tuple, Optional
from sklearn.preprocessing import StandardScaler
import warnings
warnings.filterwarnings('ignore')


class CityRiskDataset(Dataset):
    """
    城市风险数据集类
    用于加载和预处理五个城市的时序数据，构建时空图数据样本
    """
    
    def __init__(self, data_dir: str, city_names: List[str], 
                 time_window: int = 3, split: str = 'train',
                 train_ratio: float = 0.6, val_ratio: float = 0.2):
        """
        初始化城市风险数据集
        
        参数说明：
        ----------
        data_dir : str
            数据文件存储目录路径
        city_names : List[str]
            城市名称列表，如 ['南京', '苏州', '无锡', '常州', '镇江']
        time_window : int, 默认=3
            时间窗口大小，表示使用连续多少年的数据来预测下一年
        split : str, 默认='train'
            数据集划分类型，可选 'train'/'val'/'test'
        train_ratio : float, 默认=0.7
            训练集占总数据的比例
        val_ratio : float, 默认=0.15
            验证集占总数据的比例
            
        数据流程：
        ---------
        1. 定义基础特征和时序衍生特征
        2. 加载并预处理各城市数据
        3. 标准化特征数据
        4. 按时间划分数据集
        5. 构建图数据样本
        """
        self.data_dir = data_dir
        self.city_names = city_names
        # 创建城市名称到索引的映射字典
        self.city_to_idx = {city: idx for idx, city in enumerate(city_names)}
        self.num_cities = len(city_names)
        self.time_window = time_window
        self.split = split
        
        # 定义基础特征：财政风险5项、金融风险1项、资产质量3项
        self.fiscal_features = [
            '负债率(%)', '债务率(%)', '赤字率(%)', 
            '现金短期债务比', '短期债务占比(%)'
        ]
        self.finance_features = ['存贷比(%)']
        self.asset_features = [
            '不良贷款率(%)', '拨备覆盖率(%)', '资本充足率(%)'
        ]
        # 合并所有基础特征
        self.base_features = (self.fiscal_features + 
                             self.finance_features + 
                             self.asset_features)
        self.num_base_features = len(self.base_features)  # 9个基础特征
        
        # 加载和预处理数据
        self._load_and_preprocess_data()
        
        # 划分数据集
        self._split_dataset(train_ratio, val_ratio)
        
    def _load_and_preprocess_data(self):
        """
        加载和预处理所有城市的数据
        
        处理步骤：
        1. 遍历每个城市，从Excel/CSV文件加载原始数据
        2. 提取9项基础特征
        3. 计算9项时序衍生特征（同比变化率）
        4. 提取风险标签并映射为数值
        5. 统一各城市的时间长度
        6. 对特征数据进行标准化处理
        """
        all_city_data = []      # 存储所有城市的特征数据
        all_labels_fiscal = []  # 存储财政风险标签
        all_labels_finance = [] # 存储金融风险标签
        
        for city in self.city_names:
            # 尝试加载Excel或CSV格式的数据文件
            city_data_path = os.path.join(self.data_dir, f'{city}_data.xlsx')
            if not os.path.exists(city_data_path):
                city_data_path = os.path.join(self.data_dir, f'{city}_data.csv')
            
            if os.path.exists(city_data_path):
                # 根据文件扩展名选择读取方式
                if city_data_path.endswith('.xlsx'):
                    df = pd.read_excel(city_data_path)
                else:
                    df = pd.read_csv(city_data_path)
            else:
                raise FileNotFoundError(f"未找到{city}的数据文件")
            
            # 加载风险标签文件
            label_path = os.path.join(self.data_dir, f'{city}_labels.xlsx')
            if os.path.exists(label_path):
                if label_path.endswith('.xlsx'):
                    labels_df = pd.read_excel(label_path)
                else:
                    labels_df = pd.read_csv(label_path)
            else:
                raise FileNotFoundError(f"未找到{city}的标签文件")
            
            # 提取特征和标签
            years = sorted(df['年份'].unique())
            city_features = []
            city_labels_fiscal = []
            city_labels_finance = []
            
            for year in years:
                # 获取当前年份的数据行
                year_data = df[df['年份'] == year]
                if len(year_data) > 0:
                    # 步骤1: 提取9项基础特征
                    features = []
                    for feat in self.base_features:
                        if feat in year_data.columns:
                            feat_val = year_data[feat].values[0]
                            # 处理缺失值，用0填充
                            features.append(float(feat_val) if not pd.isna(feat_val) else 0.0)
                        else:
                            features.append(0.0)
                    
                    # 步骤2: 计算9项时序衍生特征（同比变化率）
                    prev_year = year - 1
                    prev_year_data = df[df['年份'] == prev_year]
                    
                    if len(prev_year_data) > 0:
                        for feat in self.base_features:
                            if feat in year_data.columns and feat in prev_year_data.columns:
                                curr_val = year_data[feat].values[0]
                                prev_val = prev_year_data[feat].values[0]
                                # 计算同比变化率：(当前值-上一年值) / |上一年值|
                                if not pd.isna(curr_val) and not pd.isna(prev_val) and prev_val != 0:
                                    change_rate = (curr_val - prev_val) / abs(prev_val)
                                else:
                                    change_rate = 0.0
                            else:
                                change_rate = 0.0
                            features.append(change_rate)
                    else:
                        # 没有上一年数据，所有变化率设为0
                        features.extend([0.0] * self.num_base_features)
                    
                    city_features.append(features)  # 18维特征向量
                    
                    # 步骤3: 提取风险标签
                    year_labels = labels_df[labels_df['年份'] == year]
                    if len(year_labels) > 0:
                        label_fisc = year_labels['财政风险综合等级'].values[0]
                        label_fin = year_labels['金融风险综合等级'].values[0]
                        
                        # 将文本标签映射为数值
                        label_map = {'低风险': 0, '中等偏低': 1, '中等': 2, 
                                    '中等偏高': 3, '高风险': 4}
                        
                        # 使用.get()方法处理未知标签，默认返回0（低风险）
                        city_labels_fiscal.append(label_map.get(str(label_fisc), 0))
                        city_labels_finance.append(label_map.get(str(label_fin), 0))
                    else:
                        # 标签缺失时使用默认值
                        city_labels_fiscal.append(0)
                        city_labels_finance.append(0)
            
            all_city_data.append(city_features)
            all_labels_fiscal.append(city_labels_fiscal)
            all_labels_finance.append(city_labels_finance)
        
        # 统一各城市的时间长度（取最小年份数）
        min_years = min(len(data) for data in all_city_data)
        all_city_data = [data[:min_years] for data in all_city_data]
        all_labels_fiscal = [labels[:min_years] for labels in all_labels_fiscal]
        all_labels_finance = [labels[:min_years] for labels in all_labels_finance]
        
        # 转换为numpy数组方便后续处理
        self.all_city_data = np.array(all_city_data)  # 形状: (5城市, 年份数, 18特征)
        self.all_labels_fiscal = np.array(all_labels_fiscal)  # 形状: (5城市, 年份数)
        self.all_labels_finance = np.array(all_labels_finance)  # 形状: (5城市, 年份数)
        
        # 对特征数据进行标准化
        self._normalize_data()
        
    def _normalize_data(self):
        """
        对特征数据进行标准化处理（Z-score标准化）
        
        标准化步骤：
        1. 将数据重塑为二维数组
        2. 使用训练集部分数据拟合StandardScaler
        3. 对所有数据应用相同的标准化变换
        
        注意：只对特征进行标准化，不对标签进行标准化
        """
        # 获取数据形状
        n_cities, n_years, n_features = self.all_city_data.shape
        
        # 重塑为二维数组: (总样本数, 特征数)
        data_reshaped = self.all_city_data.reshape(-1, n_features)
        
        # 使用前70%的数据（训练集）拟合标准化器
        train_mask = int(n_years * 0.7)
        train_data = data_reshaped[:n_cities * train_mask]
        
        # 创建StandardScaler并拟合训练数据
        self.scaler = StandardScaler()
        self.scaler.fit(train_data)
        
        # 对所有数据应用标准化变换
        data_normalized = self.scaler.transform(data_reshaped)
        # 恢复原始三维形状
        self.all_city_data = data_normalized.reshape(n_cities, n_years, n_features)
        
    def _split_dataset(self, train_ratio: float, val_ratio: float):
        """
        划分训练集、验证集和测试集
        
        划分逻辑：
        1. 按时间顺序划分，确保时间连续性
        2. 训练集: 前70%，验证集: 中间15%，测试集: 后15%
        3. 考虑时间窗口限制，确保每个样本都有足够的过去数据
        
        参数说明：
        ----------
        train_ratio : float
            训练集占总数据的比例
        val_ratio : float
            验证集占总数据的比例
        """
        n_cities, n_years, n_features = self.all_city_data.shape
        
        # 验证数据量是否足够
        assert n_years > self.time_window, "年份数必须大于时间窗口"
        
        # 计算划分点
        train_end = int(n_years * train_ratio)
        val_end = train_end + int(n_years * val_ratio)
        
        # 根据split参数确定数据范围
        if self.split == 'train':
            self.start_idx = 0
            self.end_idx = train_end
        elif self.split == 'val':
            self.start_idx = train_end
            self.end_idx = val_end
        else:  # 'test'
            self.start_idx = val_end
            self.end_idx = n_years
        
        # 生成样本索引（目标年份）
        self.samples = []
        for target_year in range(self.start_idx + self.time_window, self.end_idx):
            # 确保有足够的历史数据
            self.samples.append(target_year)
        
    def __len__(self):
        """返回数据集的样本数量"""
        return len(self.samples)
    
    def _build_adjacency_matrix(self) -> torch.Tensor:
        """
        构建邻接矩阵，表示城市间的关联强度
        
        邻接矩阵包含三部分：
        1. 地理邻接矩阵 (A_geo): 基于行政区划接壤关系
        2. 经济关联矩阵 (A_econ): 基于经济指标相关性
        3. 自适应邻接矩阵 (A_adapt): 可学习参数，捕捉潜在关联
        
        返回：
        ------
        torch.Tensor
            归一化后的混合邻接矩阵，形状为 (5, 5)
        """
        # 地理邻接矩阵 - 基于实际接壤关系
        # 南京与镇江接壤，苏州、无锡、常州相互接壤
        geo_adj = np.array([
            [1, 0, 0, 0, 1],  # 南京 (与镇江接壤)
            [0, 1, 1, 1, 0],  # 苏州 (与无锡、常州接壤)
            [0, 1, 1, 1, 0],  # 无锡
            [0, 1, 1, 1, 0],  # 常州
            [1, 0, 0, 0, 1]   # 镇江
        ], dtype=np.float32)
        
        # 经济关联矩阵 - 基于贷款余额的相关系数
        # 这里用随机数模拟，实际应用中应使用真实经济数据计算
        econ_adj = np.random.rand(5, 5).astype(np.float32)
        np.fill_diagonal(econ_adj, 1.0)  # 对角线设为1
        
        # 自适应邻接矩阵 - 可学习参数，初始化为小值
        adapt_adj = np.ones((5, 5), dtype=np.float32) * 0.1
        
        # 组合邻接矩阵（加权求和）
        # 实际应用中，这些权重可以是可学习的参数
        adj = 0.3 * geo_adj + 0.3 * econ_adj + adapt_adj
        
        # 对称归一化: D^(-1/2) * A * D^(-1/2)
        # 这种归一化有助于稳定GNN的训练
        rowsum = adj.sum(axis=1)  # 计算每个节点的度
        d_inv_sqrt = np.power(rowsum, -0.5).flatten()
        d_inv_sqrt[np.isinf(d_inv_sqrt)] = 0.  # 处理度为0的节点
        d_mat_inv_sqrt = np.diag(d_inv_sqrt)  # 构建度矩阵的-1/2次方
        adj_normalized = adj.dot(d_mat_inv_sqrt).T.dot(d_mat_inv_sqrt)
        
        return torch.FloatTensor(adj_normalized)
    
    def __getitem__(self, idx: int) -> Dict:
        """
        获取单个图数据样本
        
        参数说明：
        ----------
        idx : int
            样本索引
            
        返回：
        ------
        Data
            PyTorch Geometric的Data对象，包含：
            - x: 节点特征矩阵 (5节点, 时间窗口×18特征)
            - edge_index: 边索引 (2, 边数)
            - edge_attr: 边权重 (边数, 1)
            - y_fiscal: 财政风险标签 (5节点)
            - y_finance: 金融风险标签 (5节点)
            - target_year: 目标年份
            - num_nodes: 节点数
        """
        # 获取目标年份
        target_year = self.samples[idx]
        start_year = target_year - self.time_window  # 起始年份
        
        # 提取特征：对每个城市，拼接时间窗口内的特征
        features = []
        for city_idx in range(self.num_cities):
            city_features = []
            for year in range(start_year, target_year):
                # 拼接每个年份的18维特征
                city_features.extend(self.all_city_data[city_idx, year])
            features.append(city_features)
        
        # 转换为numpy数组，形状: (5城市, 时间窗口×18特征)
        features = np.array(features, dtype=np.float32)
        
        # 获取标签（目标年份的风险等级）
        labels_fiscal = self.all_labels_fiscal[:, target_year]
        labels_finance = self.all_labels_finance[:, target_year]
        
        # 构建邻接矩阵
        adj_matrix = self._build_adjacency_matrix()
        
        # 转换为PyG所需的稀疏格式
        edge_index = adj_matrix.nonzero().t().contiguous()  # 形状: (2, 边数)
        edge_attr = adj_matrix[edge_index[0], edge_index[1]]  # 形状: (边数,)
        
        # 创建PyG Data对象
        data = Data(
            x=torch.FloatTensor(features),  # 节点特征 [5, 特征数]
            edge_index=edge_index,  # 边索引 [2, 边数]
            edge_attr=edge_attr.unsqueeze(1),  # 边权重 [边数, 1]
            y_fiscal=torch.LongTensor(labels_fiscal),  # 财政风险标签 [5]
            y_finance=torch.LongTensor(labels_finance),  # 金融风险标签 [5]
            target_year=torch.tensor([target_year]),  # 目标年份
            num_nodes=self.num_cities  # 节点数
        )
        
        return data


def create_data_loaders(data_dir: str, batch_size: int = 16) -> Dict[str, DataLoader]:
    """
    创建训练、验证、测试数据加载器
    
    参数说明：
    ----------
    data_dir : str
        数据目录路径
    batch_size : int, 默认=16
        批次大小
        
    返回：
    ------
    Dict[str, DataLoader]
        包含三个数据加载器的字典：
        - 'train': 训练集数据加载器
        - 'val': 验证集数据加载器
        - 'test': 测试集数据加载器
    """
    # 苏南五市列表
    city_names = ['南京', '苏州', '无锡', '常州', '镇江']
    
    # 创建数据集实例
    train_dataset = CityRiskDataset(
        data_dir=data_dir,
        city_names=city_names,
        time_window=3,
        split='train'
    )
    
    val_dataset = CityRiskDataset(
        data_dir=data_dir,
        city_names=city_names,
        time_window=3,
        split='val'
    )
    
    test_dataset = CityRiskDataset(
        data_dir=data_dir,
        city_names=city_names,
        time_window=3,
        split='test'
    )
    
    # 定义批次整理函数
    def collate_fn(batch):
        """
        将多个Data对象整理为一个Batch对象
        """
        return Batch.from_data_list(batch)
    
    # 创建数据加载器
    train_loader = DataLoader(
        train_dataset, 
        batch_size=batch_size, 
        shuffle=True,  # 训练集需要打乱
        collate_fn=collate_fn
    )
    
    val_loader = DataLoader(
        val_dataset, 
        batch_size=batch_size, 
        shuffle=False,  # 验证集不需要打乱
        collate_fn=collate_fn
    )
    
    test_loader = DataLoader(
        test_dataset, 
        batch_size=batch_size, 
        shuffle=False,  # 测试集不需要打乱
        collate_fn=collate_fn
    )
    
    return {
        'train': train_loader,
        'val': val_loader,
        'test': test_loader
    }