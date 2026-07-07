import boto3
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

SECRET_ID = os.environ.get("SECRET_ID", "vaultpay/dev/app-secret")
REGION = os.environ.get("AWS_REGION", "eu-west-2")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return

        if self.path == "/secret-metadata":
            try:
                client = boto3.client("secretsmanager", region_name=REGION)
                response = client.describe_secret(SecretId=SECRET_ID)
                metadata = {
                    "name": response.get("Name"),
                    "arn": response.get("ARN"),
                    "last_changed": str(response.get("LastChangedDate", "")),
                    "irsa_role": os.environ.get("AWS_ROLE_ARN", "not-set")
                }
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(metadata).encode())
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        print(f"[{self.address_string()}] {format % args}")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    print(f"Starting secret-reader on port {port}")
    print(f"Secret ID: {SECRET_ID}")
    HTTPServer(("", port), Handler).serve_forever()
