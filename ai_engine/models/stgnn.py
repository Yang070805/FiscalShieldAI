# models/stgnn.py
"""
时空图神经网络模型定义
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch_geometric.nn import GATConv
import numpy as np


class STGNN(nn.Module):
    """时空图神经网络 (教师模型)"""

    def __init__(self,
                 input_dim: int = 54,       # 3年 × 18特征 = 54
                 hidden_dim: int = 64,
                 gat_heads: int = 4,
                 gru_hidden: int = 32,
                 num_classes: int = 5,
                 dropout: float = 0.2):
        super(STGNN, self).__init__()

        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.gat_heads = gat_heads
        self.gru_hidden = gru_hidden
        self.num_classes = num_classes
        self.dropout = dropout

        # ==================== 空间卷积层 ====================
        self.gat1 = GATConv(
            in_channels=input_dim,
            out_channels=hidden_dim // gat_heads,
            heads=gat_heads,
            dropout=dropout,
            concat=True
        )
        self.bn1 = nn.BatchNorm1d(hidden_dim)

        self.gat2 = GATConv(
            in_channels=hidden_dim,
            out_channels=hidden_dim // gat_heads,
            heads=gat_heads,
            dropout=dropout,
            concat=True
        )
        self.bn2 = nn.BatchNorm1d(hidden_dim)

        # ================= 时间卷积层 ====================
        self.time_dim = 3
        self.feat_per_step = input_dim // self.time_dim   # 54 // 3 = 18
        self.projection = nn.Linear(hidden_dim, input_dim)  # 64 → 54

        self.gru = nn.GRU(
            input_size=self.feat_per_step,
            hidden_size=gru_hidden,
            num_layers=1,
            batch_first=True,
            bidirectional=False
        )

        # ==================== 多任务预测头 =================
        self.fiscal_head = nn.Sequential(
            nn.Linear(gru_hidden, gru_hidden // 2),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(gru_hidden // 2, num_classes)
        )

        self.finance_head = nn.Sequential(
            nn.Linear(gru_hidden, gru_hidden // 2),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(gru_hidden // 2, num_classes)
        )

        # ================= 残差连接 ====================
        self.residual1 = nn.Linear(input_dim, hidden_dim)
        self.residual2 = nn.Linear(hidden_dim, hidden_dim)

        self.dropout_layer = nn.Dropout(dropout)

    def forward(self, data):
        x, edge_index, batch = data.x, data.edge_index, data.batch

        num_nodes = 5
        batch_size = x.size(0) // num_nodes

        # 空间卷积层 1
        x_gat1 = self.gat1(x, edge_index)
        x_gat1 = self.bn1(x_gat1)
        x_gat1 = F.elu(x_gat1)
        x_gat1 = self.dropout_layer(x_gat1)
        x_gat1 = x_gat1 + self.residual1(x)

        # 空间卷积层 2
        x_gat2 = self.gat2(x_gat1, edge_index)
        x_gat2 = self.bn2(x_gat2)
        x_gat2 = F.elu(x_gat2)
        x_gat2 = self.dropout_layer(x_gat2)
        x_gat2 = x_gat2 + self.residual2(x_gat1)

        # 投影 + 时间卷积
        x_proj = self.projection(x_gat2)                   # [batch*5, 54]

        time_features = []
        for i in range(self.time_dim):
            start = i * self.feat_per_step
            end = (i + 1) * self.feat_per_step
            time_features.append(x_proj[:, start:end])

        x_time = torch.stack(time_features, dim=1)         # [batch*5, 3, 18]
        x_time_reshaped = x_time.view(batch_size, num_nodes, self.time_dim, -1)

        gru_outputs = []
        for node_idx in range(num_nodes):
            node_feat = x_time_reshaped[:, node_idx, :, :]  # [batch, 3, 18]
            gru_out, _ = self.gru(node_feat)
            last_hidden = gru_out[:, -1, :]
            gru_outputs.append(last_hidden)

        gru_combined = torch.stack(gru_outputs, dim=1)       # [batch, 5, gru_hidden]
        gru_flat = gru_combined.view(-1, self.gru_hidden)    # [batch*5, gru_hidden]

        fiscal_logits = self.fiscal_head(gru_flat)
        finance_logits = self.finance_head(gru_flat)

        return fiscal_logits, finance_logits

    def get_attention_weights(self, data):
        x, edge_index = data.x, data.edge_index
        attention_weights = {}
        x_gat1, att1 = self.gat1(x, edge_index, return_attention_weights=True)
        attention_weights['layer1'] = att1
        x_gat2, att2 = self.gat2(x_gat1, edge_index, return_attention_weights=True)
        attention_weights['layer2'] = att2
        return attention_weights


class LightTCN(nn.Module):
    """轻量级时序卷积网络 (学生模型)"""

    def __init__(self,
                 input_channels: int = 9,
                 hidden_channels: int = 32,
                 output_dim: int = 64,
                 num_classes: int = 5,
                 dropout: float = 0.1):
        super(LightTCN, self).__init__()

        self.input_channels = input_channels
        self.time_steps = 3

        self.conv1 = nn.Conv1d(
            in_channels=input_channels,
            out_channels=hidden_channels,
            kernel_size=3, dilation=1, padding=2
        )
        self.bn1 = nn.BatchNorm1d(hidden_channels)

        self.conv2 = nn.Conv1d(
            in_channels=hidden_channels,
            out_channels=output_dim,
            kernel_size=3, dilation=2, padding=4
        )
        self.bn2 = nn.BatchNorm1d(output_dim)

        self.global_pool = nn.AdaptiveAvgPool1d(1)
        self.dropout = nn.Dropout(dropout)

        self.fiscal_head = nn.Sequential(
            nn.Linear(output_dim, output_dim // 2),
            nn.ReLU(), self.dropout,
            nn.Linear(output_dim // 2, num_classes)
        )

        self.finance_head = nn.Sequential(
            nn.Linear(output_dim, output_dim // 2),
            nn.ReLU(), self.dropout,
            nn.Linear(output_dim // 2, num_classes)
        )

    def forward(self, x):
        x = x.transpose(1, 2)
        x = self.conv1(x)
        x = self.bn1(x)
        x = F.relu(x)
        x = self.dropout(x)
        x = self.conv2(x)
        x = self.bn2(x)
        x = F.relu(x)
        x = self.dropout(x)
        x = self.global_pool(x)
        x = x.squeeze(-1)
        fiscal_logits = self.fiscal_head(x)
        finance_logits = self.finance_head(x)
        return fiscal_logits, finance_logits
