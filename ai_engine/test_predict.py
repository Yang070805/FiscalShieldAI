import socket
import json

s = socket.socket()
s.connect(('127.0.0.1', 9527))

request = {
    "action": "predict_custom",
    "city": "镇江",
    "year": 2026,
    "indicators": {
        "负债率": 62.5,
        "债务率": 185.0,
        "赤字率": 4.2,
        "现金短期债务比": 0.85,
        "短期债务占比": 45.0,
        "存贷比": 110.0,
        "不良贷款率": 3.50,
        "拨备覆盖率": 180.0,
        "资本充足率": 10.5
    }
}

s.sendall(json.dumps(request, ensure_ascii=False).encode('utf-8'))

response = b''
while True:
    chunk = s.recv(65536)
    if not chunk:
        break
    response += chunk

result = json.loads(response.decode('utf-8'))
print(json.dumps(result, ensure_ascii=False, indent=2))
s.close()
