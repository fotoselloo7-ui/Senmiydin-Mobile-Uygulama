"""Tiny App Store Connect API client (JWT from the git-ignored secrets/apple/AuthKey_*.p8). Usage: python tool/asc_api.py lists builds.
Needs: pip install pyjwt cryptography. No secret is stored in this file."""
import jwt, time, json, sys, urllib.request, urllib.error
KEY_ID = '945723RZ4R'; ISS = 'f16d8ffe-31c7-4361-a875-bd9f88613237'
P8 = open('C:/Projeler/Senmiydin Mobile Uygulama/secrets/apple/AuthKey_945723RZ4R.p8').read()
APP = '6835031308'
def token():
    return jwt.encode({'iss': ISS, 'iat': int(time.time()), 'exp': int(time.time()) + 900, 'aud': 'appstoreconnect-v1'},
                      P8, algorithm='ES256', headers={'kid': KEY_ID, 'typ': 'JWT'})
def call(method, path, body=None):
    url = path if path.startswith('http') else 'https://api.appstoreconnect.apple.com' + path
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': 'Bearer ' + token(), 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req) as r:
            t = r.read(); return r.status, (json.loads(t) if t else {})
    except urllib.error.HTTPError as e:
        t = e.read().decode('utf-8', 'replace'); 
        try: return e.code, json.loads(t)
        except Exception: return e.code, t
if __name__ == '__main__':
    st, d = call('GET', f'/v1/builds?filter[app]={APP}&sort=-uploadedDate&limit=5&include=preReleaseVersion')
    print(st)
    for b in d.get('data', []):
        a = b['attributes']; print(b['id'], a.get('version'), a.get('processingState'), a.get('usesNonExemptEncryption'), a.get('expired'), a.get('uploadedDate'))
