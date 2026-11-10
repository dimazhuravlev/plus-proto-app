#!/usr/bin/env python3
"""Record opt-in native carousel scenarios; preserve app data and user settings."""
import argparse
import pathlib
import select
import signal
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUNDLE = "com.dima.PlusProtoAppTwo"
SCENARIOS = ["petal-wave", "petal-press", "petal-breath", "swipe-flat",
             "swipe-depth", "like", "dislike", "save", "glow", "petal-pause",
             "neighbor", "entrance", "toast", "intro", "open"]


def sim(*args, check=True):
    return subprocess.run(["xcrun", "simctl", *args], check=check, capture_output=True, text=True)


def capture(name, output, encoder):
    sim("terminate", "booted", BUNDLE, check=False)
    container = pathlib.Path(sim("get_app_container", "booted", BUNDLE, "data").stdout.strip())
    ready = container / "Documents/mix-capture-ready"
    go = container / "Documents/mix-capture-go"
    ready.unlink(missing_ok=True)
    go.unlink(missing_ok=True)
    sim("launch", "booted", BUNDLE, "-debugNoSplash", "-debugFrozenFeed",
        "-debugTab", "plus", "-debugMixCapture", name)
    deadline = time.monotonic() + 45
    while not ready.exists() or ready.read_text() != name:
        if time.monotonic() > deadline:
            raise TimeoutError(f"Scenario did not become ready: {name}")
        time.sleep(0.1)
    sim("io", "booted", "screenshot", str(output / "previews" / f"{name}-ready.png"))
    raw = output / "raw" / f"{name}.mov"
    recording = subprocess.Popen(["xcrun", "simctl", "io", "booted", "recordVideo",
                                  "--codec=h264", "--force", str(raw)],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    try:
        deadline = time.monotonic() + 15
        while True:
            if recording.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError(f"Recorder failed: {name}")
            if select.select([recording.stderr], [], [], 0.2)[0]:
                line = recording.stderr.readline()
                if "Recording started" in line:
                    break
        go.write_text("go")
        time.sleep(5.3)
    finally:
        recording.send_signal(signal.SIGINT)
        recording.communicate(timeout=20)
    if recording.returncode != 0:
        raise RuntimeError(f"Recorder exited with {recording.returncode}: {name}")
    subprocess.run([encoder, "encode", str(raw), str(output / f"{name}.mp4")], check=True)
    subprocess.run([encoder, "frames", str(output / f"{name}.mp4"),
                    str(output / "previews" / name)], check=True)
    print(f"CAPTURED {name}", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("scenarios", nargs="*", default=SCENARIOS)
    parser.add_argument("--encoder")
    parser.add_argument("--restore", action="store_true")
    args = parser.parse_args()
    output = ROOT / "output/mix-motion"
    for directory in (output, output / "raw", output / "previews"):
        directory.mkdir(parents=True, exist_ok=True)
    if args.encoder is None:
        args.encoder = str(output / "video-tool")
        subprocess.run(["swiftc", "-parse-as-library", "-module-cache-path", str(output / "module-cache"),
                        str(ROOT / "scripts/mix-motion-video.swift"), "-o", args.encoder], check=True)
    for name in args.scenarios:
        if name not in SCENARIOS:
            raise ValueError(name)
        capture(name, output, args.encoder)
    if args.restore:
        sim("terminate", "booted", BUNDLE, check=False)
        sim("launch", "booted", BUNDLE, "-debugMixRestore", "-debugNoSplash", "-debugTab", "plus")
        print("RESTORED preferences; Recently remains hidden", flush=True)


if __name__ == "__main__":
    main()
