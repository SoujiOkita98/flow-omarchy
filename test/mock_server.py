"""Minimal OpenAI-compatible provider for Flow for Omarchy's tests.

Behaviour is driven by MOCK_SCENARIO (read per request from a file so one
server can serve several scenarios). Every request is logged to MOCK_LOG.
"""
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

state_dir = sys.argv[1]
TRANSCRIPT = "um so hey dana comma can we move the sync to thursday no actually wednesday"


def scenario():
    with open(os.path.join(state_dir, "scenario")) as f:
        return f.read().strip()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def record(self, body):
        with open(os.path.join(state_dir, "requests.jsonl"), "a") as f:
            f.write(json.dumps({
                "path": self.path,
                "auth": self.headers.get("Authorization"),
                "body": body,
            }) + "\n")

    def do_GET(self):
        self.record("")
        ok = self.headers.get("Authorization") == "Bearer test-key"
        self.reply(200 if ok else 401, {"data": []} if ok else {"error": {"message": "bad key"}})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        s = scenario()
        if self.path.endswith("/audio/transcriptions"):
            fields = dict(re.findall(rb'name="(\w+)"\r\n\r\n([^\r]*)\r\n', raw))
            self.record({k.decode(): v.decode() for k, v in fields.items()})
            if s == "transcribe-fails":
                return self.reply(401, {"error": {"message": "Invalid API Key"}})
            text = "" if s == "silence" else TRANSCRIPT
            return self.reply(200, {"text": text})

        body = json.loads(raw)
        self.record(body)
        model = body["model"]
        if s == "primary-fails" and model == "openai/gpt-oss-20b":
            return self.reply(500, {"error": {"message": "boom"}})
        if s == "answers-instruction":
            content = "Sure! Here's a draft email to Dana about rescheduling."
        elif s == "empty":
            content = "EMPTY"
        elif s == "think":
            content = "<think>reasoning</think>\"Hey Dana, can we move the sync to Wednesday?\""
        else:
            content = "Hey Dana, can we move the sync to Wednesday?"
        self.reply(200, {"choices": [{"message": {"content": content}}]})


HTTPServer(("127.0.0.1", int(sys.argv[2])), Handler).serve_forever()
