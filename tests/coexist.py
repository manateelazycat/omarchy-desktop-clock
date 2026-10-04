#!/usr/bin/env python3
"""Measure actual Wave animation/rendering alongside the clock without user config writes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def cpu(pid):
    fields = Path(f'/proc/{pid}/stat').read_text().split(') ', 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['alone', 'shared', 'separate'], required=True)
    parser.add_argument('--drag', action='store_true')
    parser.add_argument('--duration', type=int, default=5000)
    parser.add_argument('--clock-source', type=Path, default=ROOT / 'profiles/shared-v011-source')
    parser.add_argument('--wave-source', type=Path, default=Path.home() / 'omarchy-wave')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    samples = []
    clock_samples = []
    clock_result = None
    with tempfile.TemporaryDirectory(prefix='clock-wave-bench-') as directory:
        runtime = Path(directory)
        for name, source in [('Plugin', args.clock_source), ('Wave', args.wave_source)]:
            (runtime / name).mkdir()
            if (source / 'renderer').exists():
                shutil.copytree(source / 'renderer', runtime / name / 'renderer')
            for pattern in ['*.qml', '*.js', 'settings.json']:
                for file in source.glob(pattern):
                    shutil.copy2(file, runtime / name / file.name)
        # Backend fixture drives the original Wave.Service at a fixed level.
        (runtime / 'Wave/wave_backend.py').write_text('''import json, subprocess, time
names = [m['name'] for m in json.loads(subprocess.check_output(['hyprctl', '-j', 'monitors']))]
packet = json.dumps(dict(screens={n: True for n in names}, bands=[0.65] * 24, level=0.8, active=True))
while True:
    print(packet, flush=True)
    time.sleep(1 / 30)
''')
        shutil.copy2(ROOT / 'tests/Coexist.qml', runtime / 'shell.qml')
        for module in ['Commons', 'Ui']:
            (runtime / module).symlink_to(Path('/usr/share/omarchy/shell') / module, target_is_directory=True)
        env = dict(os.environ, CLOCK_BENCH_MODE=args.mode, CLOCK_BENCH_DURATION=str(args.duration),
                   CLOCK_BENCH_DRAG='1' if args.drag else '0', QSG_INFO='1')
        log_path = args.output.with_suffix('.log')
        with log_path.open('w') as log:
            proc = subprocess.Popen(['quickshell', '-p', str(runtime), '--no-color'], env=env,
                                    stdout=log, stderr=subprocess.STDOUT)
            clock_proc = None
            if args.mode == 'separate':
                shutil.copy2(ROOT / 'tests/ClockBench.qml', runtime / 'ClockBench.qml')
                clock_env = dict(env, QT_QUICK_BACKEND='software', QSG_RENDER_LOOP='basic')
                clock_proc = subprocess.Popen(['quickshell', '-p', str(runtime / 'ClockBench.qml'), '--no-color'],
                                              env=clock_env, stdout=log, stderr=subprocess.STDOUT)
            started = time.monotonic()
            try:
                while proc.poll() is None:
                    if time.monotonic() - started > args.duration / 1000 + 10:
                        raise TimeoutError('Benchmark timed out')
                    try:
                        samples.append((time.monotonic(), cpu(proc.pid)))
                        if clock_proc:
                            clock_samples.append((time.monotonic(), cpu(clock_proc.pid)))
                    except FileNotFoundError:
                        break
                    time.sleep(0.05)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                proc.wait(timeout=5)
                if clock_proc:
                    report = subprocess.run(['qs', 'ipc', '--pid', str(clock_proc.pid), 'call', 'clock-bench', 'finish'],
                                            capture_output=True, text=True, timeout=3)
                    if report.returncode == 0:
                        clock_result = json.loads(report.stdout)
                    clock_proc.terminate()
                    clock_proc.wait(timeout=5)
        text = log_path.read_text()
        match = re.search(r'COEXIST_RESULT (\{[^\n]*\})', text)
        if not match or proc.returncode:
            raise RuntimeError(f'Benchmark failed: {log_path}')
        result = json.loads(match[1])
        steady = [s for s in samples if s[0] - started > 1.7]
        if len(steady) > 1:
            result['waveProcessCpuPercentOneCore'] = round(100 * (steady[-1][1] - steady[0][1])
                                                          / (steady[-1][0] - steady[0][0]), 2)
        result.update(mode=args.mode, drag=args.drag, clockSource=str(args.clock_source), log=str(log_path))
        result['waveSourceSha256'] = {f: hashlib.sha256((args.wave_source / f).read_bytes()).hexdigest()
                                     for f in ['Service.qml', 'WaveSurface.qml']}
        if clock_result is not None:
            result['clock'] = clock_result
        clock_steady = [s for s in clock_samples if s[0] - started > 1.7]
        if len(clock_steady) > 1:
            result['clockProcessCpuPercentOneCore'] = round(100 * (clock_steady[-1][1] - clock_steady[0][1])
                                                           / (clock_steady[-1][0] - clock_steady[0][0]), 2)
        args.output.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
