import urllib.request, json

BASE = "http://localhost:8082"

def call(method, path, token=None, body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    return json.loads(urllib.request.urlopen(req).read().decode())

login = call("POST", "/api/auth/login", body={"username": "sysadmin", "password": "sysadmin"})
token = login["data"]["token"]
print("LOGIN", login["code"])

for path in ["/workflow/task/todo?page=1&size=10", "/workflow/task/stats"]:
    r = call("GET", path, token=token)
    print(path, "code=", r.get("code"), "data=", type(r.get("data")), "keys=", list((r.get("data") or {}).keys()) if isinstance(r.get("data"), dict) else "")
print("OK")
