"""Builds bashrc.sh (from main.sh) and windows-setup.ps1 (from main.ps1).

Directives, which must be alone on their line:
- §include <file>: replaced by the content of <file> (relative to this directory).
- §writeFile {json}: replaced by code that writes the file "src" (embedded in base64) to "dest", unless "dest" already exists and is more recent than "src".
    - "msg": message displayed when writing the file, in past tense (eg "Added .vimrc"). Also used for the "Already ..." and "Cannot ..., needs admin rights" messages.
    - "command" (optional): only write the file if this command exists.
    - "needsAdmin" (optional): only write the file if running as admin (root for bash).
    - "applyConfigValues" (optional): replace ###key### placeholders in "src" with the values of config.json.
    - .klc files are compiled to a keyboard layout dll with Microsoft Keyboard Layout Creator.
    - Backslashes are literal, so that Windows paths can be written as is.

###key### placeholders in main.sh, main.ps1 and included files are replaced with the values of config.json.
"""

import base64
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CONFIG_PATH = ROOT / "config.json"
CONFIG = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
KBDUTOOL = Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Microsoft Keyboard Layout Creator 1.4" / "bin" / "i386" / "kbdutool.exe"

DIRECTIVE_RE = re.compile(r"^(\s*)§(\w+) (.*)$")
PLACEHOLDER_RE = re.compile(r"###(\w+)###")
WRITE_FILE_KEYS = {"src", "dest", "msg", "command", "needsAdmin", "applyConfigValues"}
# Used to turn the "msg" of §writeFile into "Cannot <verb> ..., needs admin rights". Add verbs as needed.
PRESENT_TENSE = {"Added": "add", "Applied": "apply", "Installed": "install", "Set": "set"}


def read_text(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def apply_config_values(text, origin):
    def replace(match):
        if match.group(1) not in CONFIG:
            raise KeyError(f"Unknown placeholder '{match.group(0)}' in {origin}")
        return str(CONFIG[match.group(1)])
    return PLACEHOLDER_RE.sub(replace, text)


def compile_klc(klc):
    # kbdutool embeds a timestamp in the dll, so only recompile when the .klc changes to avoid needless diffs in windows-setup.ps1
    dll = klc.with_suffix(".dll")
    if dll.exists() and dll.stat().st_mtime >= klc.stat().st_mtime:
        return dll
    print(f"Compiling {klc.name}")
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copy(klc, tmp)
        subprocess.run([KBDUTOOL, "-u", "-m", klc.name], cwd=tmp, check=True)
        # The dll is named after the KBD name in the .klc
        dlls = list(Path(tmp).glob("*.dll"))
        if len(dlls) != 1:
            raise RuntimeError(f"Expected kbdutool to output one dll, got {dlls}")
        shutil.move(dlls[0], dll)
    return dll


def present_tense(msg):
    verb, rest = msg.split(" ", 1)
    if verb not in PRESENT_TENSE:
        raise KeyError(f"Unknown verb '{verb}' in §writeFile msg '{msg}', add it to PRESENT_TENSE")
    return f"{PRESENT_TENSE[verb]} {rest}"


def sh_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"


def ps_quote(s):
    return "'" + s.replace("'", "''") + "'"


def write_file_bash(dest, content_b64, mtime, msg, command, needs_admin):
    dest = '"' + re.sub(r"^~/", "$HOME/", dest) + '"'
    lines = [
        f"if [[ -f {dest} ]] && [[ $(stat -c %Y {dest}) -ge {mtime} ]]; then",
        "    : # Already up to date",
    ]
    if needs_admin:
        lines += [
            "elif [[ $EUID -ne 0 ]]; then",
            f"    echo {sh_quote(f'[.bashrc] Cannot {present_tense(msg)}, needs root rights')}",
        ]
    if command:
        lines += [
            f"elif ! command -v {sh_quote(command)} >/dev/null; then",
            f"    : # {command} is not installed",
        ]
    lines += [
        "else",
        f'    mkdir -p "$(dirname {dest})"',
        f"    echo '{content_b64}' | base64 -d > {dest}",
        f"    echo {sh_quote('[.bashrc] ' + msg)}",
        "fi",
    ]
    return lines


def write_file_ps1(dest, content_b64, mtime, msg, command, needs_admin):
    lines = [
        f'$writeFileDest = "{dest}"',
        f"if ((Test-Path -LiteralPath $writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds({mtime}).UtcDateTime) {{",
        f"    Write-Host {ps_quote('Already ' + msg[0].lower() + msg[1:])} -ForegroundColor DarkGray",
    ]
    if needs_admin:
        lines += [
            "} elseif (-not $isAdmin) {",
            f"    Write-Host {ps_quote(f'Cannot {present_tense(msg)}, needs admin rights')} -ForegroundColor Yellow",
        ]
    if command:
        lines += [
            f"}} elseif (-not (Get-Command {ps_quote(command)} -ErrorAction SilentlyContinue)) {{",
            f"    # {command} is not installed",
        ]
    lines += [
        "} else {",
        "    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null",
        f"    [IO.File]::WriteAllBytes($writeFileDest, [Convert]::FromBase64String('{content_b64}'))",
        f"    echo {ps_quote(msg)}",
        "}",
    ]
    return lines


def write_file(arg, lang, origin):
    # Backslashes are literal, so escape them before parsing
    args = json.loads(arg.replace("\\", "\\\\"))
    unknown_keys = set(args) - WRITE_FILE_KEYS
    if unknown_keys:
        raise KeyError(f"Unknown keys {unknown_keys} in §writeFile in {origin}")

    src = ROOT / args["src"]
    mtime = src.stat().st_mtime
    if src.suffix == ".klc":
        content = compile_klc(src).read_bytes()
    elif args.get("applyConfigValues"):
        content = apply_config_values(read_text(src), src.name).encode("utf-8")
        mtime = max(mtime, CONFIG_PATH.stat().st_mtime)
    else:
        content = src.read_bytes()

    generate = write_file_bash if lang == "bash" else write_file_ps1
    return generate(args["dest"], base64.b64encode(content).decode("ascii"), int(mtime), args["msg"], args.get("command"), args.get("needsAdmin", False))


def process(path, lang):
    out = []
    for line in read_text(path).split("\n"):
        match = DIRECTIVE_RE.match(line)
        if not match:
            out.append(apply_config_values(line, path.name))
            continue
        indent, directive, arg = match.groups()
        if directive == "include":
            # Do not indent included files, as it would break here-strings
            out.append(process(ROOT / arg.strip(), lang).removesuffix("\n"))
        elif directive == "writeFile":
            out += [indent + generated_line for generated_line in write_file(arg, lang, path.name)]
        else:
            raise ValueError(f"Unknown directive '§{directive}' in {path.name}")
    return "\n".join(out)


def build(src, dest, lang):
    content = process(ROOT / src, lang)
    dest_path = ROOT / dest
    # Only write if changed, as the modification date of bashrc.sh is used by §writeFile in windows-setup.ps1
    if dest_path.exists() and read_text(dest_path) == content:
        print(f"{dest} is up to date")
        return
    with open(dest_path, "w", encoding="utf-8", newline="") as f:
        f.write(content)
    print(f"Wrote {dest}")


# bashrc.sh must be built first, as it is embedded in windows-setup.ps1
build("main.sh", "bashrc.sh", "bash")
build("main.ps1", "windows-setup.ps1", "ps1")
