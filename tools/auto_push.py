#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Auto Push Script
Automatically commits and pushes changes to GitHub with descriptive messages.

Usage:
    python3 tools/auto_push.py [optional_codename] [optional_notes]

Examples:
    python3 tools/auto_push.py                          # Auto-detect changes
    python3 tools/auto_push.py "DEBATE LAYER"           # With codename
    python3 tools/auto_push.py "DEBATE LAYER" "Integrated all 12 strategies"
"""

import subprocess
import sys
import os
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MEMORY_DIR = REPO_ROOT / "memory"
LOG_FILE = MEMORY_DIR / "auto_push.log"


def run(cmd, cwd=REPO_ROOT):
    """Run a shell command and return output."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    return result.stdout.strip(), result.returncode


def log(msg):
    """Append to session log."""
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}\n"
    with open(LOG_FILE, "a") as f:
        f.write(line)
    print(line.strip())


def get_changed_files():
    """Get list of changed/new/deleted files."""
    staged, _ = run("git diff --cached --name-status")
    unstaged, _ = run("git diff --name-status")
    untracked, _ = run("git ls-files --others --exclude-standard")

    changes = {"modified": [], "added": [], "deleted": []}

    for line in (staged + "\n" + unstaged).strip().split("\n"):
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            status, filepath = parts[0], parts[1]
            if status == "M":
                changes["modified"].append(filepath)
            elif status == "A":
                changes["added"].append(filepath)
            elif status == "D":
                changes["deleted"].append(filepath)

    for f in untracked.split("\n"):
        if f.strip():
            changes["added"].append(f.strip())

    return changes


def generate_description(changes):
    """Generate a brief description of what changed."""
    parts = []
    if changes["added"]:
        parts.append(f"added {len(changes['added'])} file(s)")
    if changes["modified"]:
        parts.append(f"modified {len(changes['modified'])} file(s)")
    if changes["deleted"]:
        parts.append(f"removed {len(changes['deleted'])} file(s)")

    if not parts:
        return "no changes detected"
    return ", ".join(parts)


def get_latest_version():
    """Get the latest version tag to increment from."""
    tag, code = run("git describe --tags --abbrev=0 2>/dev/null")
    if code == 0 and tag.startswith("V"):
        try:
            return float(tag[1:])
        except ValueError:
            pass
    # Fallback: parse from recent commits
    log_out, _ = run('git log --oneline -20 --format="%s"')
    for line in log_out.split("\n"):
        if line.startswith("V"):
            try:
                ver = float(line.split()[0][1:])
                return ver
            except (ValueError, IndexError):
                continue
    return 28.0


def build_commit_body(changes):
    """Build a detailed commit body."""
    lines = []
    lines.append("Changes in this commit:")
    lines.append("")

    if changes["added"]:
        lines.append("New files:")
        for f in changes["added"]:
            lines.append(f"  + {f}")
        lines.append("")

    if changes["modified"]:
        lines.append("Modified files:")
        for f in changes["modified"]:
            lines.append(f"  ~ {f}")
        lines.append("")

    if changes["deleted"]:
        lines.append("Removed files:")
        for f in changes["deleted"]:
            lines.append(f"  - {f}")
        lines.append("")

    return "\n".join(lines)


def main():
    codename = sys.argv[1] if len(sys.argv) > 1 else None
    notes = sys.argv[2] if len(sys.argv) > 2 else None

    log("=== AUTO PUSH STARTED ===")

    # Stage all changes
    run("git add -A")

    # Check for changes
    status, _ = run("git status --porcelain")
    if not status:
        log("No changes to commit. Exiting.")
        print("No changes to commit.")
        return

    changes = get_changed_files()
    description = generate_description(changes)

    # Determine version
    version = get_latest_version() + 0.01
    version_str = f"V{version:.2f}"

    # Build commit message
    if codename:
        subject = f"{version_str} {codename} — {description}"
    else:
        subject = f"{version_str} — {description}"

    body = build_commit_body(changes)
    if notes:
        body = f"{notes}\n\n{body}"

    commit_msg = f"{subject}\n\n{body}"

    # Commit
    log(f"Committing: {subject}")
    _, rc = run(f'git commit -m "{commit_msg}"')
    if rc != 0:
        # Try with heredoc for multiline
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as tf:
            tf.write(commit_msg)
            tf_path = tf.name
        _, rc = run(f'git commit -F "{tf_path}"')
        os.unlink(tf_path)

    if rc != 0:
        log("ERROR: Commit failed!")
        sys.exit(1)

    # Push
    log("Pushing to GitHub...")
    output, rc = run("git push origin main 2>&1")
    log(f"Push output: {output}")

    if rc != 0:
        # Try pushing to current branch
        branch, _ = run("git branch --show-current")
        output, rc = run(f"git push origin {branch} 2>&1")
        log(f"Push output (branch={branch}): {output}")

    if rc == 0:
        log(f"SUCCESS: {subject}")
    else:
        log(f"WARNING: Push may have failed. Check output above.")

    log("=== AUTO PUSH COMPLETE ===")
    print(f"\n✅ Committed: {subject}")


if __name__ == "__main__":
    main()
