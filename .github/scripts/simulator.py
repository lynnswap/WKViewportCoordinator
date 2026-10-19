#!/usr/bin/env python3
"""Own one CI simulator across preparation, build, test, and cleanup steps."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shlex
import subprocess


def simctl(*arguments, timeout=60):
    command = ["xcrun", "simctl", *arguments]
    print(datetime.datetime.now(datetime.timezone.utc).isoformat(), shlex.join(command), flush=True)
    subprocess.run(command, check=True, timeout=timeout)


def prepare(state_path, destination):
    fields = dict(component.split("=", 1) for component in destination.split(","))
    udid = fields["id"]
    # Resolve selects an unused Shutdown device on this disposable job runner.
    state_path.write_text(json.dumps({"udid": udid}) + "\n")
    simctl("boot", udid)


def wait(state_path):
    state = json.loads(state_path.read_text())
    simctl("bootstatus", state["udid"], "-b", timeout=300)


def cleanup(state_path):
    if state_path.exists():
        state = json.loads(state_path.read_text())
        simctl("shutdown", state["udid"])
        state_path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("prepare", "wait", "cleanup"))
    operation = parser.parse_args().operation
    state_path = Path(os.environ["RUNNER_TEMP"]) / "ci-simulator.json"
    if operation == "prepare":
        prepare(state_path, os.environ["DESTINATION"])
    elif operation == "wait":
        wait(state_path)
    else:
        cleanup(state_path)


if __name__ == "__main__":
    main()
