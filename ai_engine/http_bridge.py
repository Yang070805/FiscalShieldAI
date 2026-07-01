"""
http_bridge.py
为 Flutter Web / 远程客户端提供 HTTP API 桥接

功能：将 TCP Socket 接口包装为 HTTP REST API
启动：python http_bridge.py [--port 8080] [--tcp-host 127.0.0.1] [--tcp-port 9527]

API 端点：
  GET  /health                → 健康检查
  POST /predict               → 城市预测
  POST /predict/batch         → 批量预测
  POST /predict/custom        → 自定义指标预测
"""

import sys
import json
import socket
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

# 确保 ai_engine 目录在 path 中
sys.path.insert(0, str(Path(__file__).parent))


class APIHandler(BaseHTTPRequestHandler):
    """HTTP API 请求处理器"""

    tcp_host = '127.0.0.1'
    tcp_port = 9527

    def do_GET(self):
        if self.path == '/health':
            self._proxy_request({'action': 'health'})
        else:
            self._send_error(404, 'Not Found')

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length == 0:
            self._send_error(400, 'Empty request body')
            return

        try:
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
        except json.JSONDecodeError:
            self._send_error(400, 'Invalid JSON')
            return

        if self.path == '/predict':
            action = data.get('action', 'predict_by_city')
            data['action'] = action
            self._proxy_request(data)
        elif self.path == '/predict/batch':
            data['action'] = 'predict_batch'
            self._proxy_request(data)
        elif self.path == '/predict/custom':
            data['action'] = 'predict_custom'
            self._proxy_request(data)
        else:
            self._send_error(404, 'Not Found')

    def do_OPTIONS(self):
        """CORS 预检"""
        self.send_response(200)
        self._set_cors_headers()
        self.end_headers()

    def _proxy_request(self, request_data):
        """转发请求到 TCP 后端"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(30)
            sock.connect((self.tcp_host, self.tcp_port))

            # 发送
            json_str = json.dumps(request_data, ensure_ascii=False)
            sock.sendall(json_str.encode('utf-8'))

            # 接收
            chunks = []
            while True:
                try:
                    chunk = sock.recv(4096)
                    if not chunk:
                        break
                    chunks.append(chunk)
                except socket.timeout:
                    break

            sock.close()

            if not chunks:
                self._send_error(502, 'No response from TCP backend')
                return

            response_data = json.loads(b''.join(chunks).decode('utf-8'))
            self._send_json(200, response_data)

        except ConnectionRefusedError:
            self._send_error(502, 'TCP backend not running. Start api_server.py first.')
        except Exception as e:
            self._send_error(500, str(e))

    def _send_json(self, status, data):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self._set_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

    def _send_error(self, status, message):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self._set_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps({
            'status': 'error',
            'message': message,
        }, ensure_ascii=False).encode('utf-8'))

    def _set_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def log_message(self, format, *args):
        print(f"[HTTP] {args[0]}")


def main():
    parser = argparse.ArgumentParser(description='FiscalShieldAI HTTP Bridge')
    parser.add_argument('--port', type=int, default=8080, help='HTTP 端口')
    parser.add_argument('--tcp-host', default='127.0.0.1', help='TCP 后端地址')
    parser.add_argument('--tcp-port', type=int, default=9527, help='TCP 后端端口')
    args = parser.parse_args()

    APIHandler.tcp_host = args.tcp_host
    APIHandler.tcp_port = args.tcp_port

    server = HTTPServer(('0.0.0.0', args.port), APIHandler)
    print(f"[HTTP Bridge] 监听 0.0.0.0:{args.port}")
    print(f"[HTTP Bridge] 转发到 TCP {args.tcp_host}:{args.tcp_port}")
    print(f"[HTTP Bridge] 端点:")
    print(f"  GET  /health")
    print(f"  POST /predict")
    print(f"  POST /predict/batch")
    print(f"  POST /predict/custom")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[HTTP Bridge] 已停止")
        server.server_close()


if __name__ == '__main__':
    main()
