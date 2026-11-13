"""Allowlisted, audited backend archive. Runtime data is never a packaging input."""
import argparse
import json
import os
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
from release_safety import ROOT, audit_source, audit_zip, secret_path

parser = argparse.ArgumentParser()
parser.add_argument("--with-vendor", action="store_true")
args = parser.parse_args()
report = audit_source()
if report["status"] != "OK":
    print(json.dumps(report, indent=2))
    raise SystemExit("Source security audit failed")
backend, dist, staging = ROOT / "backend", ROOT / "dist", ROOT / ".local/release-staging"
for directory in (dist, staging):
    directory.mkdir(parents=True, exist_ok=True)
    if directory.is_symlink() or not directory.resolve().is_relative_to(ROOT.resolve()):
        raise SystemExit("Unsafe output directory")
with tempfile.TemporaryDirectory(prefix="backend-", dir=staging) as temp:
    target = Path(temp).resolve()
    assert target.is_relative_to(staging.resolve())
    for relative in ["app", "bootstrap", "config", "public", "resources", "routes", "lang", "database/migrations", "database/seeders"]:
        source = backend / relative
        if not source.exists():
            continue
        for path in source.rglob("*"):
            if path.is_symlink():
                raise SystemExit("Symlinks are not allowed in backend source input")
            if not path.is_file():
                continue
            rel = path.relative_to(backend)
            if secret_path(rel) or ".sync-conflict-" in str(rel) or rel.parts[:2] in [("bootstrap", "cache"), ("public", "storage")]:
                continue
            if path.name in ["DemoDataSeeder.php", "DevelopmentAdminSeeder.php"]:
                continue
            dest = target / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, dest)
    for name in ("artisan", "composer.json", "composer.lock", ".env.example"):
        shutil.copyfile(backend / name, target / name)
    for folder in ["bootstrap/cache", "database/factories", "storage/app/private", "storage/framework/cache/data",
                   "storage/framework/sessions", "storage/framework/views", "storage/logs"]:
        (target / folder).mkdir(parents=True, exist_ok=True)
        (target / folder / ".gitignore").write_text("*\n!.gitignore\n", encoding="utf-8")
    for document in ("DEPLOYMENT.md", "LOCATION_TIME_TRAVEL.md"):
        (target / document).write_bytes((ROOT / "docs" / document).read_bytes())
    (target / "README_RELEASE.md").write_text(
        "# Backend release\n\nNo environment, secrets, user media, logs, local DB or demo seeders are included.\n"
        "Primary method: install PHP 8.2+ extensions, run composer install --no-dev --prefer-dist --optimize-autoloader, "
        "configure .env, set APP_KEY securely, migrate --force, create the real admin, run app:check.\n"
        "If vendor is included it is freshly installed without dev packages in isolated staging. "
        "Run php artisan package:discover --ansi on the server. Never overwrite an existing APP_KEY.\n"
        "See DEPLOYMENT.md for private uploads, queue, cron, backup, restore and rollback.\n", encoding="utf-8")
    if args.with_vendor:
        composer = shutil.which("composer") or shutil.which("composer.bat")
        command = [composer] if composer else [shutil.which("php"), str(ROOT / ".local/composer.phar")]
        if not command[0] or (not composer and not (ROOT / ".local/composer.phar").is_file()):
            raise SystemExit("Composer is required for --with-vendor")
        subprocess.run(command + ["install", "--no-dev", "--prefer-dist", "--optimize-autoloader", "--no-scripts", "--no-interaction"],
                       cwd=target, check=True, shell=os.name == "nt")
    suffix = "-vendor" if args.with_vendor else ""
    archive_path = dist / f"senmiydin-backend-release{suffix}.tmp.zip"
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(target.rglob("*")):
            if path.is_symlink():
                raise SystemExit("Unexpected staging symlink")
            if path.is_file():
                rel = path.relative_to(target)
                if rel.parts[0] == "vendor" and (secret_path(rel) or any(part.lower() in {"tests", ".git"} for part in rel.parts)):
                    continue
                archive.write(path, rel.as_posix())
    result = audit_zip(archive_path)
    if result["status"] != "OK":
        print(json.dumps(result, indent=2))
        raise SystemExit("Archive audit failed")
    output = dist / f"senmiydin-backend-release{suffix}.zip"
    os.replace(archive_path, output)
    result.update(path=str(output), vendor_included=args.with_vendor,
                  source_files_checked=report["source_files_checked"])
    (dist / f"senmiydin-backend-release{suffix}.audit.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
