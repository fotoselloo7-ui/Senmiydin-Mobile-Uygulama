"""Fail-closed source/ZIP audit. Never prints matched secret values."""
import argparse
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import stat
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
SKIP = {".git", ".local", ".dart_tool", "build", "vendor", "node_modules", ".gradle", ".idea", ".codex", ".agents", "dist", ".syncthing.tmp"}
EXT = {".jks", ".keystore", ".p8", ".pem", ".key", ".crt", ".cer", ".der", ".p12", ".pfx", ".mobileprovision", ".sql", ".dump", ".bak", ".sqlite", ".sqlite3", ".db", ".hprof", ".dmp"}
SECRET_NAMES = {"key.properties", "google-services.json", "GoogleService-Info.plist", "auth.json"}
TEXT_EXT = {".php", ".json", ".ps1", ".py", ".dart", ".yaml", ".yml", ".xml", ".env", ".md", ".txt", ".ini", ".properties"}
def secret_path(path):
    name = Path(path).name
    return (name == ".env" or (name.startswith(".env.") and name != ".env.example")
            or name in SECRET_NAMES or Path(name).suffix.lower() in EXT
            or name.endswith(".sql.gz") or "service-account" in name or "firebase-adminsdk" in name)

def inline_findings(data):
    text = data.decode("utf-8", errors="replace")
    findings = []
    for match in re.finditer(r"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----\s*\r?\n[A-Za-z0-9+/=]{40,}", text):
        findings.append({"line": text[:match.start()].count("\n") + 1, "kind": "private-key"})
    for number, line in enumerate(text.splitlines(), 1):
        if re.search(r'"(?:client_secret|SMTP_PASSWORD|MAIL_PASSWORD|DB_PASSWORD)"\s*:\s*"[^"]{8,}"', line):
            findings.append({"line": number, "kind": "literal-config-secret"})
        if re.search(r'"type"\s*:\s*"service_account"', line) and '"private_key"' in text:
            findings.append({"line": number, "kind": "service-account"})
        match = re.search(r'^\s*(?:MAIL_PASSWORD|SMTP_PASSWORD|DB_PASSWORD|GOOGLE_CLIENT_SECRET|APPLE_CLIENT_SECRET)\s*=\s*(.+?)\s*$', line)
        if match and match.group(1).strip("\"' ") and not re.fullmatch(r"[\s\"']*", match.group(1)):
            findings.append({"line": number, "kind": "literal-environment-secret"})
    return findings

def source_files():
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP and not Path(base, d).is_symlink()]
        for name in files:
            p = Path(base, name)
            if ".sync-conflict-" not in name and not p.is_symlink():
                yield p

def audit_source():
    findings, sensitive, ignores = [], [], []
    files = list(source_files())
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        if path.name == ".gitignore":
            ignores.append(path)
        if secret_path(rel):
            sensitive.append(rel)
            continue
        if path.suffix in TEXT_EXT and path.stat().st_size < 2_000_000:
            for item in inline_findings(path.read_bytes()):
                findings.append({"path": rel, **item})
    probes = sensitive + [".env", "backend/.env.production", "backend/auth.json",
        "secrets/service-account.json", "android/key.properties", "android/release.jks",
        "ios/Runner/GoogleService-Info.plist", "android/app/google-services.json",
        "private/key.p8", "backup/users.sql", "backup/users.sql.gz", "backend/database/local.sqlite"]
    audit_temp = ROOT / ".local/security-audit"
    audit_temp.mkdir(parents=True, exist_ok=True)
    assert audit_temp.resolve().is_relative_to(ROOT.resolve()) and not audit_temp.is_symlink()
    with tempfile.TemporaryDirectory(prefix="ignore-", dir=audit_temp) as name:
        temp = Path(name)
        subprocess.run(["git", "init", "-q", str(temp)], check=True, capture_output=True)
        for src in ignores:
            dest = temp / src.relative_to(ROOT)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(src.read_bytes())
        result = subprocess.run(["git", "-c", f"safe.directory={temp.as_posix()}", "-C", str(temp), "check-ignore", "--no-index", "-z", "--stdin"],
            input=("\0".join(probes) + "\0").encode("utf-8"), capture_output=True)
        if result.returncode not in (0, 1):
            raise RuntimeError("Git ignore verification failed: " + result.stderr.decode("utf-8", errors="replace").strip())
        ignored = set(result.stdout.decode("utf-8").split("\0"))
        for path in probes:
            if path not in ignored:
                findings.append({"path": path, "kind": "not-gitignored"})
    if (ROOT / ".git").exists():
        result = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, check=True)
        for path in result.stdout.decode().split("\0"):
            if path and secret_path(path):
                findings.append({"path": path, "kind": "sensitive-file-tracked"})
    return {"status": "FAIL" if findings else "OK", "findings": findings,
        "ignored_sensitive_files": len(sensitive), "source_files_checked": len(files),
        "git_tracking_checked": (ROOT / ".git").exists()}

def audit_zip(path):
    findings = []
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            rel = info.filename
            normalized = rel.replace("\\", "/")
            if ".." in PurePosixPath(normalized).parts or normalized.startswith("/") or re.match(r"^[A-Za-z]:", normalized) or stat.S_ISLNK(info.external_attr >> 16) or secret_path(rel):
                findings.append({"path": rel, "kind": "forbidden-archive-path"})
            if any(x in Path(rel).parts for x in [".local", ".git", "tests", "node_modules"]) or ".sync-conflict-" in rel:
                findings.append({"path": rel, "kind": "runtime-or-development-file"})
            if Path(rel).suffix in TEXT_EXT and info.file_size < 2_000_000 and not rel.startswith("vendor/"):
                findings += [{"path": rel, **item} for item in inline_findings(archive.read(info))]
        assert len(archive.namelist()) == len(set(archive.namelist())), "Duplicate archive entries"
        assert "artisan" in archive.namelist() and "public/index.php" in archive.namelist(), "Missing backend entry points"
    return {"status": "FAIL" if findings else "OK", "findings": findings,
        "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest(), "bytes": Path(path).stat().st_size}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit_zip(args.zip) if args.zip else audit_source()
    data = json.dumps(report, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(data + "\n", encoding="utf-8")
    print(data)
    raise SystemExit(0 if report["status"] == "OK" else 1)
