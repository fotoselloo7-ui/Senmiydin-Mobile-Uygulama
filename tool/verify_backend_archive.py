"""Bootstrap an audited self-produced vendor archive in disposable isolated staging."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
import zipfile
from release_safety import ROOT, audit_zip

parser = argparse.ArgumentParser()
parser.add_argument("--zip", type=Path, default=ROOT / "dist/senmiydin-backend-release-vendor.zip")
args = parser.parse_args()
report = audit_zip(args.zip)
if report["status"] != "OK":
    raise SystemExit("Archive audit failed; refusing extraction")
base = ROOT / ".local/archive-verification"
base.mkdir(parents=True, exist_ok=True)
assert base.resolve().is_relative_to(ROOT.resolve()) and not base.is_symlink()
with tempfile.TemporaryDirectory(prefix="verify-", dir=base) as name:
    target = Path(name).resolve()
    assert target.is_relative_to(base.resolve())
    with zipfile.ZipFile(args.zip) as archive:
        archive.extractall(target)
    if not (target / "vendor/autoload.php").exists():
        raise SystemExit("Use the vendor archive for an offline bootstrap check")
    process = subprocess.run([shutil.which("php"), "artisan", "route:list", "--json"], cwd=target,
                             capture_output=True, text=True)
    if process.returncode:
        raise SystemExit("Isolated Laravel bootstrap failed; no environment or credentials were copied")
    routes = json.loads(process.stdout)
    assert any(route["uri"] == "health" for route in routes)
    assert any(route["uri"] == "api/v1/auth/account" for route in routes)
    assert not (target / ".env").exists()
    print(json.dumps({"status": "OK", "isolated_bootstrap": True, "routes": len(routes), "environment_copied": False}))
