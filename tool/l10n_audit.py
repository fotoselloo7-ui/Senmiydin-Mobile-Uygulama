"""Finds user-facing Turkish string literals in lib/ that have no English entry (catalog or ARB).

Usage: python tool/l10n_audit.py [--all]
Exit code 0 when every UI literal that looks Turkish is covered; 1 otherwise (so it can run in CI).
A literal counts as covered when it is a key of `enCatalog`, the value of an `app_tr.arb` entry, or it is
explicitly allow-listed in tool/l10n_allowlist.txt (user content examples, brand names, technical tokens).
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / 'lib'
BS = chr(92)
ESC = BS + BS  # an escaped backslash for use inside a regex character class
TR_CHARS = set('çğıöşüÇĞİÖŞÜâîû')

def unescape(raw: str) -> str:
    out, i = [], 0
    while i < len(raw):
        if raw[i] == BS and i + 1 < len(raw):
            nxt = raw[i + 1]
            out.append({'n': '\n', 't': '\t', "'": "'", '"': '"', BS: BS, '$': '$'}.get(nxt, nxt))
            i += 2
        else:
            out.append(raw[i])
            i += 1
    return ''.join(out)

LITERAL = re.compile(r"'((?:[^'" + ESC + r"\n]|" + ESC + r".)*)'|\"((?:[^\"" + ESC + r"\n]|" + ESC + r".)*)\"")

def catalog_keys() -> set:
    text = (LIB / 'l10n' / 'en_catalog.dart').read_text(encoding='utf-8')
    keys = set()
    for line in text.splitlines():
        m = re.match(r"\s*(?:'((?:[^'" + ESC + r"]|" + ESC + r".)*)'|\"((?:[^\"" + ESC + r"]|" + ESC + r".)*)\")\s*:", line)
        if m:
            keys.add(unescape(m.group(1) if m.group(1) is not None else m.group(2)))
    return keys

def arb_turkish() -> set:
    values = set()
    data = json.loads((LIB / 'l10n' / 'app_tr.arb').read_text(encoding='utf-8'))
    for key, value in data.items():
        if not key.startswith('@') and isinstance(value, str):
            values.add(value)
    return values

def allowlist() -> set:
    path = ROOT / 'tool' / 'l10n_allowlist.txt'
    if not path.exists():
        return set()
    return {line.rstrip('\n') for line in path.read_text(encoding='utf-8').splitlines() if line and not line.startswith('#')}

UI_CONTEXT = re.compile(r"(?:\bText\(|\bText\.rich|label:|labelText:|hintText:|helperText:|errorText:|title:|subtitle:|tooltip:|semanticLabel:|"
                        r"semanticsLabel:|message:|content:|child:\s*const\s+Text|SnackBar|showSnack|_snack|toast\(|tr\()")

def vocabulary(keys: set) -> set:
    words = set()
    for key in keys:
        for word in re.findall(r"[A-Za-zÇĞİÖŞÜçğıöşü]{4,}", key):
            words.add(word.lower())
    return words

def looks_turkish(text: str, vocab: set) -> bool:
    if any(c in TR_CHARS for c in text):
        return True
    words = [w.lower() for w in re.findall(r"[A-Za-z]{4,}", text)]
    return bool(words) and sum(1 for w in words if w in vocab) >= 1 and not re.fullmatch(r"[A-Za-z0-9_./:-]+", text)

def main() -> int:
    sys.stdout.reconfigure(encoding='utf-8')
    keys, arb, allowed = catalog_keys(), arb_turkish(), allowlist()
    vocab = vocabulary(keys)
    show_all = '--all' in sys.argv
    missing: dict = {}
    for path in sorted(LIB.rglob('*.dart')):
        rel = path.relative_to(ROOT).as_posix()
        if 'sync-conflict' in rel or rel.startswith('lib/l10n/') or rel.endswith('.g.dart') or rel == 'lib/data/mock_data.dart':
            continue
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith('//') or stripped.startswith('///') or stripped.startswith('import '):
                continue
            if not (UI_CONTEXT.search(line) or show_all):
                continue
            for m in LITERAL.finditer(line):
                raw = m.group(1) if m.group(1) is not None else m.group(2)
                text = unescape(raw)
                if '$' in raw and 'trf(' not in line and 'Key(' not in line and 'debugPrint' not in line:
                    # Interpolated sentences cannot be looked up: they must go through trf('... {0} ...', [value]).
                    static = re.sub(r"\$\{[^}]*\}|\$[A-Za-z_]+", "", text)
                    if raw not in allowed and '/' not in text and re.search(r"[A-Za-zÇĞİÖŞÜçğıöşü]{3,}", static) and looks_turkish(static, vocab)                             and not rel.startswith('lib/data/'):
                        missing.setdefault('INTERPOLATED: ' + raw, []).append(f'{rel}:{number}')
                    continue
                if len(text.strip()) < 3 or '${' in raw or text in keys or text in allowed:
                    continue
                if not looks_turkish(text, vocab):
                    continue
                missing.setdefault(text, []).append(f'{rel}:{number}')
    for text, places in sorted(missing.items(), key=lambda item: item[1][0]):
        print(f'{places[0]}  {text!r}' + (f'  (+{len(places) - 1})' if len(places) > 1 else ''))
    print(f'\n{len(missing)} uncovered Turkish UI literal(s); catalog {len(keys)}, ARB {len(arb)}.')
    return 1 if missing else 0

if __name__ == '__main__':
    sys.exit(main())
