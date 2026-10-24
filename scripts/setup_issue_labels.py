#!/usr/bin/env python3
"""Preview or explicitly apply Boorusama's label catalog; never edit issues."""

import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys


REPOSITORY = "github.com/timberpile/Boorusama"
CATALOG = Path(__file__).resolve().parents[1] / ".github" / "labels.json"


def load_labels(path=CATALOG):
    labels = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(labels, list) or not labels:
        raise ValueError("The label catalog must be a nonempty list.")
    seen = set()
    for label in labels:
        if not isinstance(label, dict) or set(label) != {"name", "color", "description"}:
            raise ValueError("Each label needs name, color, and description only.")
        name, color, description = (label[key] for key in ("name", "color", "description"))
        if not all(isinstance(value, str) for value in (name, color, description)):
            raise ValueError("Label fields must be strings.")
        if not re.fullmatch(r"[a-z][a-z0-9:-]*", name) or len(name) > 50 or name in seen:
            raise ValueError("Label names must be unique, lowercase, and at most 50 characters.")
        if not re.fullmatch(r"[0-9a-fA-F]{6}", color) or not 1 <= len(description) <= 100:
            raise ValueError("Labels need a six-digit hex color and a 1-100 character description.")
        seen.add(name)
    return labels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Create/update catalog labels on GitHub.")
    args = parser.parse_args()
    try:
        labels = load_labels()
        if not args.apply:
            print(f"Preview for {REPOSITORY}; pass --apply to write labels.")
        for label in labels:
            command = ["gh", "label", "create", label["name"], "--repo", REPOSITORY,
                       "--color", label["color"], "--description", label["description"], "--force"]
            if args.apply:
                # --force updates matching labels, not issue memberships or unrelated labels.
                subprocess.run(command, check=True, timeout=60)
                print(f"Prepared {label['name']}", flush=True)
            else:
                print(shlex.join(command))
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Label setup failed: {error}. Correct the problem and rerun; existing issues are unchanged.",
              file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
