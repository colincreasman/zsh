"""Run with python3 in WSL; requires python3-pexpect and the installed profile."""
import os
import re
import shlex
import tempfile
import time

import pexpect


with tempfile.TemporaryDirectory(prefix="shell-parity-") as temp:
    for name in ("preview-one", "preview-two", "working-directory"):
        os.mkdir(os.path.join(temp, name))
        if name.startswith("preview-"):
            with open(os.path.join(temp, name, name + "-child.txt"), "w"):
                pass
    environment = dict(
        os.environ, TERM="xterm-256color", ZSHZ_DATA=os.path.join(temp, ".z")
    )
    child = pexpect.spawn(
        "/usr/bin/zsh", ["-il"], env=environment, encoding="utf-8",
        timeout=30, dimensions=(40, 160),
    )
    report = os.path.join(temp, "report")

    def state():
        if os.path.exists(report):
            os.unlink(report)
        child.send("\x07")
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if os.path.exists(report):
                with open(report) as stream:
                    value = stream.read()
                if "GHOST:" in value:
                    return value
            try:
                child.read_nonblocking(4096, timeout=0.1)
            except pexpect.TIMEOUT:
                pass
        raise RuntimeError("No ZLE state report received")

    try:
        child.sendline(
            "HISTFILE=" + shlex.quote(os.path.join(temp, ".history"))
            + "; print -r -- SHELL_PTY_$((20+22))"
        )
        child.expect("SHELL_PTY_42")
        child.sendline(
            "function _parity_report() { printf '%s\\n' \"BUFFER:$BUFFER\" "
            "\"GHOST:$POSTDISPLAY\" > " + shlex.quote(report) + "; }; "
            "function _parity_clear() { BUFFER=''; POSTDISPLAY=''; zle -R; }; "
            "zle -N _parity-report _parity_report; zle -N _parity-clear _parity_clear; "
            "bindkey '^G' _parity-report; bindkey '^O' _parity-clear; "
            "print -r -- WIDGET_$((20+22))"
        )
        child.expect("WIDGET_42")
        for name in ("preview-one", "preview-two"):
            child.sendline("cd " + shlex.quote(os.path.join(temp, name)))
        child.sendline(
            "cd " + shlex.quote(os.path.join(temp, "working-directory"))
            + "; print -r -- SETUP_$((20+22))"
        )
        child.expect("SETUP_42")
        child.send("z preview-\t")
        child.expect(r"preview-(one|two)-child\.txt")
        child.send("\r")
        selected = state()
        assert re.search(
            r"BUFFER:z " + re.escape(temp) + r"/preview-(one|two)", selected
        ), selected
        child.send("\x0f")
        child.sendline("print -r -- history-parity-$((40+2))")
        child.expect("history-parity-42")
        child.send("print -r -- history-parity-\x1b[A")
        ghost = state()
        assert ghost == "BUFFER:print -r -- history-parity-\nGHOST:$((40+2))\n", ghost
        child.send("\x00")
        accepted = state()
        assert accepted == "BUFFER:print -r -- history-parity-$((40+2))\nGHOST:\n", accepted
        child.send("\x0f")
        child.sendline("exit")
        child.expect(pexpect.EOF)
        print("PASS: live z<Tab> ranking, eza preview, path insertion, ghost history and Ctrl+Space accept.")
    except pexpect.TIMEOUT:
        output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", child.before)
        print("Last terminal output:", repr(output[-4000:]))
        raise
    finally:
        if child.isalive():
            child.terminate(force=True)
