"""Headless Windows console regression test. Requires pywinpty and installed shell tools."""
import json
import os
from pathlib import Path
import re
import shutil
import socket
import tempfile
import time

from winpty import PtyProcess


ROOT = Path(__file__).resolve().parent
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\].*?(?:\x07|\x1b\\)", re.DOTALL)
SHELL = shutil.which("pwsh")
if not SHELL:
    raise RuntimeError("PowerShell 7 (pwsh) must be on PATH")


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


with tempfile.TemporaryDirectory(prefix="shell-completion-") as directory:
    temp = Path(directory)
    report = temp / "buffer.json"
    setup = temp / "setup.ps1"
    setup.write_text(
        "$ErrorActionPreference = 'Stop'\n"
        "Import-Module PSReadLine\n"
        "Set-PSReadLineOption -HistorySaveStyle SaveNothing -HistorySavePath "
        + quote(temp / "history") + "\n"
        ". " + quote(ROOT / "profile.ps1") + "\n"
        "oh-my-posh init pwsh --config " + quote(ROOT / "chaf.omp.json") + " | Invoke-Expression\n"
        ". " + quote(ROOT / "keybindings.ps1") + "\n"
        "Set-ShellKeyBindings\nInitialize-Completions\n"
        "Set-PSReadLineKeyHandler -Chord Ctrl+g -ScriptBlock {\n"
        "    $line=$null; $cursor=$null\n"
        "    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line,[ref]$cursor)\n"
        "    @{ Line=$line; CodePage=[Console]::OutputEncoding.CodePage } | ConvertTo-Json | "
        "Set-Content -Encoding utf8 -LiteralPath " + quote(report) + "\n}\n"
        # Reproduce Windows' legacy console code page, not the test runner's UTF-8.
        "[Console]::OutputEncoding = [Text.Encoding]::GetEncoding(437)\n"
        "Set-Location " + quote(ROOT.parent) + "\n",
        encoding="utf-8",
    )
    child = PtyProcess.spawn(
        [SHELL, "-NoLogo", "-NoProfile",
         "-NoExit", "-File", str(setup)],
        env=dict(os.environ, TERM="xterm-256color"), dimensions=(40, 120),
    )
    child.fileobj.settimeout(0.1)
    output = ""

    def pump():
        global output
        try:
            chunk = child.read(65536)
            output += chunk
            if "\x1b[6n" in chunk:
                child.write("\x1b[1;1R")
        except socket.timeout:
            pass

    def expect(text, start=0):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            visible = ANSI.sub("", output[start:])
            if re.sub(r"\s+", "", text) in re.sub(r"\s+", "", visible):
                return
            pump()
        raise AssertionError("Missing console output: " + text)

    def state():
        report.unlink(missing_ok=True)
        child.write("\x07")
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if report.exists():
                try:
                    return json.loads(report.read_text(encoding="utf-8-sig"))
                except json.JSONDecodeError:
                    pass
            pump()
        raise AssertionError("No PSReadLine buffer report")

    def check_redraw(start):
        text = ANSI.sub("", output[start:])
        for glyph in ("\u256d", "\u2570", "\u276f"):
            assert glyph in text, "Prompt glyph lost after completion: " + repr(glyph)
        assert "?-" not in text and "?\u2500" not in text, "Prompt was redrawn with replacement characters"

    try:
        expect("\u276f")
        start = len(output)
        child.write("git \t")
        expect("Add file contents to the index", start)
        child.write("\r")
        result = state()
        assert result["Line"] == "git add", result
        assert result["CodePage"] == 437, result
        expect("\u256d", start)
        check_redraw(start)

        child.write("\x03")
        start = len(output)
        child.write("Get-ChildItem -\t")
        expect("Path", start)
        child.write("\x1b")
        result = state()
        assert result["Line"] == "Get-ChildItem -", result
        expect("\u256d", start)
        check_redraw(start)
        print("PASS: real Windows git/fzf help preview, insertion/cancel and Unicode prompt redraw under code page 437.")
    except Exception:
        print("Console output tail:", ascii(ANSI.sub("", output[-6000:])))
        raise
    finally:
        child.terminate(force=True)
