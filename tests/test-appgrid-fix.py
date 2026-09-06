#!/usr/bin/env python3
"""Installer safety smoke: fake build/Plasma, real file staging and replacement."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="appgrid-install-check-") as temp:
    root = Path(temp)
    home, tools, project, scratch = (root / name for name in ("home", "bin", "repo", "tmp"))
    for directory in (home, tools, project / "patches", scratch):
        directory.mkdir(parents=True)
    script = project / "install-appgrid-fix.sh"
    shutil.copy2(repo / script.name, script)
    (project / "patches/appgrid-panel-input.patch").write_text("fixture patch\n")
    fake = '''#!/usr/bin/env python3
import os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CALLS"], "a") as log:
    log.write(name + " " + " ".join(args) + "\\n")
if name == "qdbus6":
    print(os.environ.get("AVAILABLE", "true"))
elif name == "git" and "rev-parse" in args:
    print(os.environ.get("COMMIT", "7843b094d6a2f1b7f9d02df1f67fa5f1fd0a7053"))
elif name == "cmake" and "--build" in args:
    if os.environ.get("FAIL_BUILD"):
        sys.exit(1)
    output = Path(args[1]) / "bin/plasma/applets/dev.xarbit.appgrid.so"
    output.parent.mkdir(parents=True)
    output.write_bytes(b"new binary")
'''
    for name in ("git", "cmake", "qdbus6"):
        executable = tools / name
        executable.write_text(fake)
        executable.chmod(0o755)
    plugin_root = home / ".local/lib/qt6/plugins"
    destination = plugin_root / "plasma/applets/dev.xarbit.appgrid.so"
    calls = root / "calls"
    env = dict(os.environ, HOME=str(home), TMPDIR=str(scratch),
               PATH=f"{tools}:{os.environ['PATH']}", CALLS=str(calls),
               XDG_STATE_HOME=str(root / "state"), QT_PLUGIN_PATH=str(plugin_root))

    def run(*args, **changes):
        return subprocess.run(["bash", str(script), *args], env=env | changes,
                              text=True, capture_output=True)

    before = sorted(root.rglob("*"))
    result = run("--dry-run")
    assert result.returncode == 0, result.stderr
    assert sorted(root.rglob("*")) == before, "dry-run mutated filesystem"
    assert not calls.exists(), "dry-run contacted external tools"
    assert run().returncode != 0, "missing installed AppGrid accepted"
    assert not calls.exists(), "download attempted before prerequisites"
    destination.parent.mkdir(parents=True)
    destination.write_bytes(b"old binary")
    panel = destination.with_name("dev.xarbit.appgrid.panel.so")
    panel.write_bytes(b"panel binary")
    assert run(QT_PLUGIN_PATH="").returncode != 0
    assert not calls.exists(), "missing plugin path allowed download"
    assert run(AVAILABLE="false").returncode != 0
    assert "git " not in calls.read_text(), "unavailable AppGrid allowed download"
    assert run(COMMIT="wrong").returncode != 0
    assert "cmake " not in calls.read_text(), "wrong source commit allowed build"
    assert run(FAIL_BUILD="1").returncode != 0
    assert destination.read_bytes() == b"old binary"
    assert not (root / "state").exists()
    # An already-open reader must retain the old inode, not see truncated data.
    with destination.open("rb") as old_reader:
        old_inode = destination.stat().st_ino
        result = run()
        assert result.returncode == 0, result.stderr
        assert destination.stat().st_ino != old_inode
        assert old_reader.read() == b"old binary"
    assert destination.read_bytes() == b"new binary"
    backups = list((root / "state/nothingos-kde-rice/backups").glob("appgrid.*/dev.xarbit.appgrid.so"))
    assert len(backups) == 1 and backups[0].read_bytes() == b"old binary"
    assert panel.read_bytes() == b"panel binary"
    assert set(destination.parent.iterdir()) == {destination, panel}, "extra discoverable plugin or staging file"
    assert not list(scratch.iterdir()), "temporary workspace leaked"
    print("PASS: offline dry-run, fail-closed prerequisites/pin/build, atomic replacement, backup, panel preservation")
