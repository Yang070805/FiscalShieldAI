"""
通过Windows命令行推送GitHub
"""
import subprocess
import os

repo_dir = r"D:\FiscalShieldAI"

print("正在推送到GitHub...")
print(f"目录: {repo_dir}")

# 使用Windows的git（通过cmd.exe调用，可以访问Windows凭证管理器）
result = subprocess.run(
    ["git", "push", "origin", "main"],
    cwd=repo_dir,
    capture_output=True,
    text=True,
    shell=True
)

print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
print("Return code:", result.returncode)

if result.returncode == 0:
    print("\n✅ 推送成功！")
else:
    print("\n❌ 推送失败")
