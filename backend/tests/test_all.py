"""后端集成测试脚本 — V2（含对话模块）"""
import requests
import json
import sys
import os
import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

BASE = "http://127.0.0.1:8000"
passed = 0
failed = 0

def test(name, condition, detail=""):
    global passed, failed
    if condition:
        print(f"  ✅ {name}")
        passed += 1
    else:
        print(f"  ❌ {name} — {detail}")
        failed += 1

# ==================== 认证 ====================
print("\n=== 认证模块 ===")

r = requests.post(f"{BASE}/api/v1/auth/register", json={
    "phone": "13800000001", "password": "123456", "nickname": "测试用户"
})
d = r.json()
test("注册", d["success"] == True, d)
token = d.get("data", {}).get("access_token", "")

r = requests.post(f"{BASE}/api/v1/auth/login", json={
    "phone": "13800000001", "password": "123456"
})
d = r.json()
test("登录", d["success"] == True, d)
token = d["data"]["access_token"]
headers = {"Authorization": f"Bearer {token}"}

r = requests.get(f"{BASE}/api/v1/auth/me", headers=headers)
d = r.json()
test("获取用户", d["success"] == True and d["data"]["phone"] == "13800000001", d)

r = requests.put(f"{BASE}/api/v1/auth/password", headers=headers, json={
    "old_password": "123456", "new_password": "654321"
})
d = r.json()
test("改密", d["success"] == True, d)

r = requests.post(f"{BASE}/api/v1/auth/login", json={
    "phone": "13800000001", "password": "654321"
})
d = r.json()
test("新密码登录", d["success"] == True, d)
token = d["data"]["access_token"]
headers = {"Authorization": f"Bearer {token}"}

r = requests.post(f"{BASE}/api/v1/auth/register", json={
    "phone": "13800000001", "password": "123456", "nickname": "重复"
})
d = r.json()
test("重复注册被拒", d["success"] == False, d)

r = requests.post(f"{BASE}/api/v1/auth/login", json={
    "phone": "13800000001", "password": "123456"
})
d = r.json()
test("错误密码被拒", d["success"] == False, d)

r = requests.get(f"{BASE}/api/v1/auth/me")
test("无token被拒", r.status_code == 401)

# ==================== 预测 ====================
print("\n=== 预测模块 ===")

r = requests.get(f"{BASE}/api/v1/predict/cities")
d = r.json()
test("城市列表", d["success"] == True and len(d["data"]) > 0, d)

r = requests.get(f"{BASE}/api/v1/predict/南京?year=2026", headers=headers)
d = r.json()
test("预测南京", d["success"] == True and "risk_score" in d.get("data", {}), d)

r = requests.get(f"{BASE}/api/v1/predict/南京?year=2026", headers=headers)
d = r.json()
test("预测缓存", d["success"] == True, d)

# ==================== 报告 ====================
print("\n=== 报告模块 ===")

r = requests.get(f"{BASE}/api/v1/report/南京?year=2026", headers=headers)
d = r.json()
test("AI报告", d["success"] == True and len(d.get("data", {}).get("content", "")) > 50, d)

# ==================== 对话 ====================
print("\n=== 对话模块 ===")

# SSE 流式对话
r = requests.post(f"{BASE}/api/v1/chat", headers=headers, json={
    "message": "南京的财政风险怎么样？",
    "city": "南京",
    "year": 2026,
    "model": "bluelm"
}, stream=True)
test("对话SSE连接", r.status_code == 200, r.status_code)

# 解析SSE事件
events = []
full_content = ""
for line in r.iter_lines(decode_unicode=True):
    if line and line.startswith("data: "):
        try:
            data = json.loads(line[6:])
            events.append(data["type"])
            if data["type"] == "chunk":
                full_content += data.get("content", "")
        except:
            pass

test("SSE事件序列", "start" in events and "done" in events, events)
test("AI回复有内容", len(full_content) > 10, f"content_len={len(full_content)}")

# 对话列表
r = requests.get(f"{BASE}/api/v1/chat/list", headers=headers)
d = r.json()
test("对话列表", d["success"] == True and len(d["data"]) > 0, d)

chat_id = d["data"][0]["id"]

# 对话详情
r = requests.get(f"{BASE}/api/v1/chat/{chat_id}", headers=headers)
d = r.json()
test("对话详情", d["success"] == True and len(d["data"]["messages"]) > 0, d)

# 删除对话
r = requests.delete(f"{BASE}/api/v1/chat/{chat_id}", headers=headers)
d = r.json()
test("删除对话", d["success"] == True, d)

# ==================== 角色 ====================
print("\n=== 角色模块 ===")

r = requests.post(f"{BASE}/api/v1/auth/register", json={
    "phone": "13900000001", "password": "123456", "nickname": "政务用户", "role": "gov"
})
d = r.json()
test("注册gov角色", d["success"] == True and d["data"]["user"]["role"] == "gov", d)

r = requests.post(f"{BASE}/api/v1/auth/register", json={
    "phone": "13900000002", "password": "123456", "nickname": "黑客", "role": "admin"
})
d = r.json()
test("非法角色被拒", d["success"] == False, d)

# ==================== 搜索/收藏/推荐 ====================
print("\n=== 搜索/收藏/推荐模块 ===")

# 搜索
r = requests.get(f"{BASE}/api/v1/search?q=南京", headers=headers)
d = r.json()
test("搜索城市", d["success"] == True and "南京" in d["data"]["cities"], d)

# 收藏
r = requests.post(f"{BASE}/api/v1/search/favorite/南京", headers=headers)
d = r.json()
test("收藏城市", d["success"] == True, d)

# 重复收藏
r = requests.post(f"{BASE}/api/v1/search/favorite/南京", headers=headers)
d = r.json()
test("重复收藏被拒", d["success"] == False, d)

# 收藏列表
r = requests.get(f"{BASE}/api/v1/search/favorites", headers=headers)
d = r.json()
test("收藏列表", d["success"] == True and len(d["data"]) > 0, d)

# 取消收藏
r = requests.delete(f"{BASE}/api/v1/search/favorite/南京", headers=headers)
d = r.json()
test("取消收藏", d["success"] == True, d)

# 推荐
r = requests.get(f"{BASE}/api/v1/search/recommend", headers=headers)
d = r.json()
test("推荐", d["success"] == True and "all" in d["data"], d)

# ==================== 数据上传 ====================
print("\n=== 数据上传模块 ===")

# 创建 gov 用户
r = requests.post(f"{BASE}/api/v1/auth/register", json={
    "phone": "13600000001", "password": "123456", "nickname": "政务上传者", "role": "gov"
})
d = r.json()
gov_token = d["data"]["access_token"]
gov_headers = {"Authorization": f"Bearer {gov_token}"}
test("注册gov用户", d["success"] == True, d)

# citizen 不能上传
r = requests.post(f"{BASE}/api/v1/upload/preview", headers=headers, files={"file": ("test.xlsx", b"fake", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")})
test("citizen不能上传", r.status_code == 403, r.status_code)

# 生成测试 Excel
import io
test_df = pd.DataFrame({
    "年份": [2023, 2024, 2025],
    "城市": ["南京", "南京", "南京"],
    "财政收入(亿)": [1200, 1250, 1300],
    "财政支出(亿)": [1100, 1150, 1200],
    "债务率(%)": [45.2, 46.1, 47.0],
})
excel_buffer = io.BytesIO()
test_df.to_excel(excel_buffer, index=False)
excel_bytes = excel_buffer.getvalue()

# 上传预览
r = requests.post(f"{BASE}/api/v1/upload/preview", headers=gov_headers, files={"file": ("南京数据.xlsx", excel_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")})
d = r.json()
test("上传预览", d["success"] == True and d["data"]["rows"] == 3, d)

# 确认入库
r = requests.post(f"{BASE}/api/v1/upload/confirm", headers=gov_headers, json={
    "city": "南京",
    "year": 2025,
    "data": [
        {"年份": 2023, "财政收入(亿)": 1200, "债务率(%)": 45.2},
        {"年份": 2024, "财政收入(亿)": 1250, "债务率(%)": 46.1},
    ],
    "permission": "internal"
})
d = r.json()
test("确认入库", d["success"] == True and d["data"]["inserted"] == 2, d)

# 上传历史
r = requests.get(f"{BASE}/api/v1/upload/history", headers=gov_headers)
d = r.json()
test("上传历史", d["success"] == True and len(d["data"]) > 0, d)

# 错误格式
r = requests.post(f"{BASE}/api/v1/upload/preview", headers=gov_headers, files={"file": ("test.txt", b"hello", "text/plain")})
d = r.json()
test("错误格式被拒", d["success"] == False, d)

# ==================== 安全与运维 ====================
print("\n=== 安全与运维模块 ===")

# 脱敏工具
from utils.encryption import mask_phone, mask_id_card, mask_email, mask_name
test("手机号脱敏", mask_phone("13800138000") == "138****8000", mask_phone("13800138000"))
test("身份证脱敏", mask_id_card("110101199001011234") == "110***********1234", mask_id_card("110101199001011234"))
test("邮箱脱敏", mask_email("test@example.com") == "t***@example.com", mask_email("test@example.com"))
test("姓名脱敏", mask_name("张三明") == "张*明", mask_name("张三明"))

# 限流测试（连续请求）
r = requests.get(f"{BASE}/health")
test("健康检查", r.status_code == 200, r.status_code)

# API文档
r = requests.get(f"{BASE}/docs")
test("Swagger文档", r.status_code == 200, r.status_code)

r = requests.get(f"{BASE}/redoc")
test("ReDoc文档", r.status_code == 200, r.status_code)

# OpenAPI schema
r = requests.get(f"{BASE}/openapi.json")
d = r.json()
test("OpenAPI Schema", "paths" in d and "/api/v1/auth/register" in d["paths"], list(d.get("paths", {}).keys())[:5])

# ==================== 汇总 ====================
print(f"\n{'='*30}")
print(f"总计: {passed + failed} | 通过: {passed} | 失败: {failed}")
if failed == 0:
    print("🎉 全部通过！")
else:
    print(f"⚠️ 有 {failed} 项失败")
sys.exit(0 if failed == 0 else 1)
