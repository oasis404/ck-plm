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

defs = call("GET", "/workflow/definition/list", token=token)
print("DEFS", defs["code"], "count", len(defs["data"]))
for x in defs["data"]:
    print("  ", x["key"], x["name"], "v" + str(x["version"]))

start = call("POST", "/workflow/instance/start", token=token,
             body={"processDefinitionKey": "plm-change-review", "businessKey": "verify-001",
                   "variables": {"initiator": "sysadmin", "approved": True}})
print("START change-review", start["code"], "status=", (start["data"] or {}).get("status"))
print("DONE")
