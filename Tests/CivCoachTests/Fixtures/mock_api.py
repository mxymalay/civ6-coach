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
            responses = self.path.endswith('/responses')
            if model in ['metadata', 'metadata-flood']:
                event = {'type': 'response.reasoning.delta', 'delta': 'x' * 1000} if responses else {'choices': [{'delta': {'reasoning_content': 'x' * 1000}}]}
                self.wfile.write((('data: ' + json.dumps(event) + '\n\n') * (17000 if model == 'metadata-flood' else 2100)).encode())
            if model == 'oversized-event':
                self.wfile.write(('data: ' + json.dumps({'padding': 'x' * 2000000}) + '\n\n').encode())
            if model == 'long':
                event = {'type': 'response.output_text.delta', 'delta': '文' * 10000} if responses else {'choices': [{'delta': {'content': '文' * 10000}}]}
                self.wfile.write(('data: ' + json.dumps(event, ensure_ascii=False) + '\n\n').encode())
            if model == 'json-incomplete':
                value = {'status': 'incomplete', 'output': [{'content': [{'text': '半截回答'}]}]} if responses else {'choices': [{'finish_reason': 'content_filter', 'message': {'content': '半截回答'}}]}
                self.wfile.write(json.dumps(value).encode())
                return
            if model in ['json-budget', 'json-long']:
                text = '已有建议' if model == 'json-budget' else '文' * 10000
                value = {'status': 'incomplete' if model == 'json-budget' else 'completed', 'incomplete_details': {'reason': 'max_output_tokens'}, 'output': [{'content': [{'text': text}]}]} if responses else {'choices': [{'finish_reason': 'length' if model == 'json-budget' else 'stop', 'message': {'content': text}}]}
                self.wfile.write(json.dumps(value).encode())
                return
            if model == 'json':
                self.wfile.write(json.dumps({'choices': [{'message': {'content': '普通JSON回复'}}]}).encode())
                return
            responses = self.path.endswith('/responses')
            if model == 'reasoning-budget':
                event = {'type': 'response.incomplete', 'response': {'incomplete_details': {'reason': 'max_output_tokens'}}} if responses else {'choices': [{'delta': {}, 'finish_reason': 'length'}]}
                self.wfile.write(('data: ' + json.dumps(event) + '\n\n').encode())
                return
            for fragment in ['先发展', '城市', '。']:
                event = {'type': 'response.output_text.delta', 'delta': fragment} if responses else {'choices': [{'delta': {'content': fragment}}]}
                wire = ('data: ' + json.dumps(event, ensure_ascii=False) + '\n\n').encode()
                # Split across UTF-8 boundaries to exercise URLSession byte decoding.
                for part in [wire[:14], wire[14:21], wire[21:]]:
                    self.wfile.write(part)
                    self.wfile.flush()
            if model != 'truncated':
                if model == 'budget':
                    event = {'type': 'response.incomplete', 'response': {'incomplete_details': {'reason': 'max_output_tokens'}}} if responses else {'choices': [{'delta': {'content': '尾'}, 'finish_reason': 'length'}]}
                    end = json.dumps(event)
                else:
                    end = json.dumps({'type': 'response.completed'}) if responses else '[DONE]'
                self.wfile.write(('data: ' + end + '\n\n').encode())
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
print(server.server_port, flush=True)
server.serve_forever()
