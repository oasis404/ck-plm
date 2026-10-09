import urllib.request, json, urllib.parse

BASE = "http://localhost:8082"

def call(method, path, token=None, body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        return {"_error": e.code, "body": e.read().decode()}

login = call("POST", "/api/auth/login", body={"username": "sysadmin", "password": "sysadmin"})
token = login["data"]["token"]
print("LOGIN", login["code"])

for name in ["黄华安", "齐芳芳"]:
    r = call("GET", "/api/users?keyword=" + urllib.parse.quote(name), token=token)
    print("=== search:", name, "code=", r.get("code"))
    data = r.get("data") or []
    if isinstance(data, list):
        for u in data:
            print("   oid=%s username=%s name=%s tenant=%s status=%s" % (
                u.get("oid"), u.get("username"), u.get("realName") or u.get("name"),
                u.get("tenantOid") or u.get("tenant"), u.get("status")))
        if not data:
            print("   (no match under current tenant scope)")
    else:
        print("   raw:", json.dumps(r, ensure_ascii=False)[:300])
