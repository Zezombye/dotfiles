"""Builds bashrc.sh (from main.sh) and windows-setup.ps1 (from main.ps1).

Directives, which must be alone on their line:
- §include <file>: replaced by the content of <file> (relative to this directory).
- §writeFile {json}: replaced by code that writes the file "src" to "dest", unless "dest" already exists and is more recent than "src".
    "src" is embedded as a string, or in base64 if it is binary (or contains CR, so that its line endings do not depend on the ones of the output).
    - "dest": in windows-setup.ps1, PowerShell variables are expanded (eg $env:APPDATA).
    - "msg": message displayed when writing the file, in past tense (eg "Added .vimrc"). Also used for the "Already ..." and "Cannot ..., needs admin rights" messages. In windows-setup.ps1, PowerShell variables are expanded.
    - "command" (optional): only write the file if this command exists.
    - "needsAdmin" (optional): only write the file if running as admin (root for bash).
    - "applyConfigValues" (optional): replace ###key### placeholders in "src" with the values of config.json.
    - "replace" (optional): {"old": "new"} strings to replace in "src" (eg to reuse a file with another syntax). Each "old" string must be in "src".
    - "defaultUser" (optional, true by default): in windows-setup.ps1, destinations in $env:USERPROFILE, $env:APPDATA or $env:LOCALAPPDATA are also written to the default user profile if $applyToDefaultUser.
    - "ifAlreadyExists" (optional): if "dest" already exists (and is older than "src"), run these commands instead of replacing it (eg to edit a config file with the program it belongs to, keeping the other settings). They must modify "dest", so that they are not run again. Not used for the default user, whose file is replaced.
    - "ifNotExists" (optional): if "dest" does not exist, run these commands before writing it (eg to configure an older version of the program, which uses another file). Not used for the default user.
    - .klc files are compiled to a keyboard layout dll with Microsoft Keyboard Layout Creator.
    - Backslashes are literal, so that Windows paths can be written as is.

###key### placeholders in main.sh, main.ps1 and included files are replaced with the values of config.json.
###DATE### is replaced with the most recent modification date of the files used to build the output, which is also set as the output's modification date.
"""

import base64
import datetime
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
# Control characters other than tab and LF
SH_ESCAPED_CHARS_RE = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")
# Control characters other than tab and LF, and non-ASCII characters
PS_ESCAPED_CHARS_RE = re.compile(r"([^\t\n\x20-\x7e]+)")
WRITE_FILE_KEYS = {"src", "dest", "msg", "command", "needsAdmin", "applyConfigValues", "replace", "defaultUser", "ifAlreadyExists", "ifNotExists"}
DEFAULT_USER_DEST_RE = re.compile(r"^\$env:(USERPROFILE|APPDATA|LOCALAPPDATA)(?=\\)", re.IGNORECASE)
DEFAULT_USER_FOLDERS = {"USERPROFILE": "", "APPDATA": r"\AppData\Roaming", "LOCALAPPDATA": r"\AppData\Local"}
# Used to turn the "msg" of §writeFile into "Cannot <verb> ..., needs admin rights". Add verbs as needed.
PRESENT_TENSE = {"Added": "add", "Applied": "apply", "Installed": "install", "Set": "set"}


def read_text(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def apply_config_values(text, origin, inputs, keep_date=False):
    def replace(match):
        if keep_date and match.group(1) == "DATE":
            # Replaced in build(), once all the inputs are known
            return match.group(0)
        if match.group(1) not in CONFIG:
            raise KeyError(f"Unknown placeholder '{match.group(0)}' in {origin}")
        inputs.add(CONFIG_PATH)
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


def ps_dquote(s):
    # Double-quoted so that variables are expanded
    return '"' + s.replace("`", "``").replace('"', '`"') + '"'


def decode_text(content):
    # Returns None if the content must be embedded in base64
    if b"\0" in content or b"\r" in content:
        return None
    try:
        return content.decode("utf-8")
    except UnicodeDecodeError:
        return None


def sh_text(text):
    # Control characters (eg ESC) are escaped in $'...', as they would be invisible
    if not SH_ESCAPED_CHARS_RE.search(text):
        return sh_quote(text)
    text = re.sub(r"[\\']", lambda match: "\\" + match.group(), text)
    return "$'" + SH_ESCAPED_CHARS_RE.sub(lambda match: f"\\x{ord(match.group()):02x}", text) + "'"


def ps_text(text):
    # Windows PowerShell reads scripts without BOM with the ANSI code page, so non-ASCII characters are concatenated as [char], like control characters (eg ESC), which would be invisible
    parts = []
    for i, part in enumerate(PS_ESCAPED_CHARS_RE.split(text)):
        if i % 2 == 0:
            # Starts with a string, so that + concatenates strings
            if part or i == 0:
                parts.append(ps_quote(part))
        else:
            utf16 = part.encode("utf-16-le")
            parts += [f"[char]0x{int.from_bytes(utf16[j:j + 2], 'little'):02X}" for j in range(0, len(utf16), 2)]
    return " + ".join(parts)


def sh_run_commands(commands):
    # Braces so that commands containing || are not mixed with the &&
    return " && ".join(f"{{ {command}; }}" for command in commands)


def ps_run_commands(commands):
    lines = []
    for command in commands:
        lines += [
            f"    {command}",
            f"    if ($LASTEXITCODE -ne 0) {{throw {ps_quote('Failed to run: ' + command)}}}",
        ]
    return lines


def write_file_bash(dest, content, mtime, msg, command, needs_admin, if_already_exists, if_not_exists):
    dest = '"' + re.sub(r"^~/", "$HOME/", dest) + '"'
    text = decode_text(content)
    if text is not None:
        write_content = f"printf '%s' {sh_text(text)} > {dest}"
    else:
        write_content = f"echo '{base64.b64encode(content).decode('ascii')}' | base64 -d > {dest}"
    body = [
        f'mkdir -p "$(dirname {dest})"',
        write_content,
        f"echo {sh_quote('[.bashrc] ' + msg)}",
    ]
    if if_not_exists:
        body = [f"if {sh_run_commands(if_not_exists)}; then", *["    " + line for line in body], "fi"]
    if if_already_exists:
        body = [
            f"if [[ -f {dest} ]]; then",
            f"    {sh_run_commands(if_already_exists)} && echo {sh_quote('[.bashrc] ' + msg)}",
            "else",
            *["    " + line for line in body],
            "fi",
        ]
    if needs_admin:
        body = [
            "if [[ $EUID -ne 0 ]]; then",
            f"    echo {sh_quote(f'[.bashrc] Cannot {present_tense(msg)}, needs root rights')}",
            "else",
            *["    " + line for line in body],
            "fi",
        ]
    # command -v is a builtin, so it is checked first to avoid forking stat when the command is not installed. [[ ]] does not run stat if dest does not exist
    conditions = [f"command -v {sh_quote(command)} >/dev/null"] if command else []
    conditions.append(f"[[ ! -f {dest} || $(stat -c %Y {dest}) -lt {mtime} ]]")
    return [f"if {' && '.join(conditions)}; then", *["    " + line for line in body], "fi"]


def write_file_ps1(dest, mtime, msg, command, needs_admin, if_already_exists, if_not_exists):
    # The content is in $writeFileContent, so that it is not duplicated for the default user
    # [IO.File]::Exists returns false when access is denied (eg the SYSTEM profile without admin rights), whereas Test-Path throws
    lines = [
        f'$writeFileDest = "{dest}"',
        f"if ([IO.File]::Exists($writeFileDest) -and (Get-Item -LiteralPath $writeFileDest -Force).LastWriteTimeUtc -ge [DateTimeOffset]::FromUnixTimeSeconds({mtime}).UtcDateTime) {{",
        f"    Write-Host {ps_dquote('Already ' + msg[0].lower() + msg[1:])} -ForegroundColor DarkGray",
    ]
    if needs_admin:
        lines += [
            "} elseif (-not $isAdmin) {",
            f"    Write-Host {ps_dquote(f'Cannot {present_tense(msg)}, needs admin rights')} -ForegroundColor Yellow",
        ]
    if command:
        lines += [
            f"}} elseif (-not (Get-Command {ps_quote(command)} -ErrorAction SilentlyContinue)) {{",
            f"    # {command} is not installed",
        ]
    if if_already_exists:
        lines += [
            "} elseif ([IO.File]::Exists($writeFileDest)) {",
            *ps_run_commands(if_already_exists),
            f"    echo {ps_dquote(msg)}",
        ]
    lines += [
        "} else {",
        *ps_run_commands(if_not_exists or []),
        "    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $writeFileDest) | Out-Null",
        "    [IO.File]::WriteAllBytes($writeFileDest, $writeFileContent)",
        f"    echo {ps_dquote(msg)}",
        "}",
    ]
    return lines


def write_file(arg, lang, origin, inputs):
    # Backslashes are literal, so escape them before parsing
    args = json.loads(arg.replace("\\", "\\\\"))
    unknown_keys = set(args) - WRITE_FILE_KEYS
    if unknown_keys:
        raise KeyError(f"Unknown keys {unknown_keys} in §writeFile in {origin}")

    src = ROOT / args["src"]
    inputs.add(src)
    mtime = src.stat().st_mtime
    if src.suffix == ".klc":
        content = compile_klc(src).read_bytes()
    elif args.get("applyConfigValues") or args.get("replace"):
        text = read_text(src)
        if args.get("applyConfigValues"):
            text = apply_config_values(text, src.name, inputs)
            mtime = max(mtime, CONFIG_PATH.stat().st_mtime)
        for old, new in args.get("replace", {}).items():
            if old not in text:
                raise ValueError(f"'{old}' of §writeFile replace not found in {src.name}")
            text = text.replace(old, new)
        content = text.encode("utf-8")
    else:
        content = src.read_bytes()

    dest, msg, command, needs_admin = args["dest"], args["msg"], args.get("command"), args.get("needsAdmin", False)
    if_already_exists, if_not_exists = args.get("ifAlreadyExists"), args.get("ifNotExists")
    if lang == "bash":
        return write_file_bash(dest, content, int(mtime), msg, command, needs_admin, if_already_exists, if_not_exists)

    text = decode_text(content)
    if text is not None:
        lines = [
            f"$writeFileContent = {ps_text(text)}",
            # In case the line endings of the output were converted to CRLF
            '$writeFileContent = [Text.Encoding]::UTF8.GetBytes($writeFileContent.Replace("`r`n", "`n"))',
        ]
    else:
        lines = [f"$writeFileContent = [Convert]::FromBase64String('{base64.b64encode(content).decode('ascii')}')"]
    lines += write_file_ps1(dest, int(mtime), msg, command, needs_admin, if_already_exists, if_not_exists)
    match = DEFAULT_USER_DEST_RE.match(dest)
    if match and args.get("defaultUser", True):
        default_user_dest = "$defaultUserProfile" + DEFAULT_USER_FOLDERS[match.group(1).upper()] + dest[match.end():]
        lines.append("if ($applyToDefaultUser) {")
        # The commands would edit the config of the current user
        lines += ["    " + line for line in write_file_ps1(default_user_dest, int(mtime), msg + " for default user", command, needs_admin, None, None)]
        lines.append("}")
    return lines


def process(path, lang, inputs):
    inputs.add(path)
    out = []
    for line in read_text(path).split("\n"):
        match = DIRECTIVE_RE.match(line)
        if not match:
            out.append(apply_config_values(line, path.name, inputs, keep_date=True))
            continue
        indent, directive, arg = match.groups()
        if directive == "include":
            # Do not indent included files, as it would break here-strings
            out.append(process(ROOT / arg.strip(), lang, inputs).removesuffix("\n"))
        elif directive == "writeFile":
            out += [indent + generated_line for generated_line in write_file(arg, lang, path.name, inputs)]
        else:
            raise ValueError(f"Unknown directive '§{directive}' in {path.name}")
    return "\n".join(out)


def build(src, dest, lang):
    inputs = set()
    content = process(ROOT / src, lang, inputs)
    # Use the date of the inputs rather than the current date, so that the output only changes when an input changes
    date = max(path.stat().st_mtime for path in inputs)
    iso_date = datetime.datetime.fromtimestamp(date, datetime.timezone.utc).strftime("%Y-%m-%d")
    content = content.replace("###DATE###", iso_date)

    dest_path = ROOT / dest
    if dest_path.exists() and read_text(dest_path) == content:
        print(f"{dest} is up to date")
    else:
        with open(dest_path, "w", encoding="utf-8", newline="") as f:
            f.write(content)
        print(f"Wrote {dest}")
    # The modification date of bashrc.sh is used by §writeFile in windows-setup.ps1
    os.utime(dest_path, (date, date))


# bashrc.sh must be built first, as it is embedded in windows-setup.ps1
build("main.sh", "bashrc.sh", "bash")
build("main.ps1", "windows-setup.ps1", "ps1")
