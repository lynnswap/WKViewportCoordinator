#!/usr/bin/env python3
"""Own one CI simulator across preparation, build, test, and cleanup steps."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shlex
import subprocess


def simctl(*arguments):
    command = ["xcrun", "simctl", *arguments]
    print(datetime.datetime.now(datetime.timezone.utc).isoformat(), shlex.join(command), flush=True)
    subprocess.run(command, check=True, timeout=60)


def prepare(state_path, destination, *, preboot):
    fields = dict(component.split("=", 1) for component in destination.split(","))
    udid = fields["id"]
    # Resolve selects an unused Shutdown device on this disposable job runner.
    state_path.write_text(json.dumps({"udid": udid}) + "\n")
    if preboot:
        simctl("boot", udid)


def cleanup(state_path):
    if state_path.exists():
        state = json.loads(state_path.read_text())
        simctl("shutdown", state["udid"])
        state_path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("prepare", "cleanup"))
    parser.add_argument("--preboot", action="store_true")
    arguments = parser.parse_args()
    state_path = Path(os.environ["RUNNER_TEMP"]) / "ci-simulator.json"
    if arguments.operation == "prepare":
        prepare(state_path, os.environ["DESTINATION"], preboot=arguments.preboot)
    else:
        cleanup(state_path)


if __name__ == "__main__":
    main()
