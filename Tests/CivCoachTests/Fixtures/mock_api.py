import http.server
import json
import time

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        model = body['model']
        if model == 'unauthorized':
            self.send_response(401)
            self.end_headers()
            return
        if model == 'redirect':
            self.send_response(307)
            self.send_header('Location', '/never-follow')
            self.end_headers()
            return
        if model == 'slow':
            time.sleep(3)
        self.send_response(200)
        self.send_header('Content-Type', 'application/json' if model.startswith('json') else 'text/event-stream')
        self.end_headers()
        try:
            if model == 'json-incomplete':
                value = {'status': 'incomplete', 'output': [{'content': [{'text': '半截回答'}]}]} if self.path.endswith('/responses') else {'choices': [{'finish_reason': 'length', 'message': {'content': '半截回答'}}]}
                self.wfile.write(json.dumps(value).encode())
                return
            if model == 'json':
                self.wfile.write(json.dumps({'choices': [{'message': {'content': '普通JSON回复'}}]}).encode())
                return
            responses = self.path.endswith('/responses')
            for fragment in ['先发展', '城市', '。']:
                event = {'type': 'response.output_text.delta', 'delta': fragment} if responses else {'choices': [{'delta': {'content': fragment}}]}
                wire = ('data: ' + json.dumps(event, ensure_ascii=False) + '\n\n').encode()
                # Split across UTF-8 boundaries to exercise URLSession byte decoding.
                for part in [wire[:14], wire[14:21], wire[21:]]:
                    self.wfile.write(part)
                    self.wfile.flush()
            if model != 'truncated':
                end = json.dumps({'type': 'response.completed'}) if responses else '[DONE]'
                self.wfile.write(('data: ' + end + '\n\n').encode())
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
print(server.server_port, flush=True)
server.serve_forever()
