#!/usr/bin/env python3
"""Profile the real QML drag path without changing the user's configuration."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def cpu_seconds(pid):
    fields = Path(f'/proc/{pid}/stat').read_text().split(') ', 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--duration', type=int, default=5000, help='Drag duration in milliseconds')
    parser.add_argument('--source', type=Path, default=ROOT)
    parser.add_argument('--trace', action='store_true', help='Record Wayland and Qt render timing')
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    log_path = args.output.with_suffix('.log')
    samples = []
    with tempfile.TemporaryDirectory(prefix='desktop-clock-profile-') as directory:
        runtime = Path(directory)
        plugin = runtime / 'Plugin'
        plugin.mkdir()
        for file in args.source.glob('*.qml'):
            shutil.copy2(file, plugin / file.name)
        shutil.copytree(args.source / 'renderer', plugin / 'renderer')
        shutil.copy2(ROOT / 'tests/Profile.qml', runtime / 'shell.qml')
        shell = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
        for module in ['Commons', 'Ui']:
            (runtime / module).symlink_to(shell / module, target_is_directory=True)
        env = dict(os.environ, DESKTOP_CLOCK_PROFILE_DURATION=str(args.duration), QSG_INFO='1',
                   QT_QUICK_BACKEND='software', QSG_RENDER_LOOP='basic')
        if args.trace:
            env.update(WAYLAND_DEBUG='client', QSG_RENDER_TIMING='1')
        with log_path.open('w') as log:
            proc = subprocess.Popen(['quickshell', '-p', str(runtime), '--no-color'],
                                    env=env, stdout=log, stderr=subprocess.STDOUT)
            started = time.monotonic()
            try:
                while proc.poll() is None:
                    if time.monotonic() - started > args.duration / 1000 + 15:
                        raise TimeoutError('Profiling process did not finish')
                    try:
                        status = Path(f'/proc/{proc.pid}/status').read_text()
                        rss = re.search(r'VmRSS:\s+(\d+)', status)
                        samples.append({'time': time.monotonic(), 'cpu': cpu_seconds(proc.pid),
                                        'rssKiB': int(rss[1]) if rss else 0})
                    except FileNotFoundError:
                        break
                    time.sleep(0.05)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                proc.wait(timeout=5)
        text = log_path.read_text()
        match = re.search(r'CLOCK_PROFILE_RESULT (\{[^\n]*\})', text)
        if not match or proc.returncode:
            raise RuntimeError(f'Profiling failed; see {log_path}')
        result = json.loads(match[1])
        if args.trace:
            drag_log = text.split('CLOCK_PROFILE_START', 1)[1].split('CLOCK_PROFILE_RESULT', 1)[0]
            layers = {}
            for layer, surface, namespace in re.findall(
                r'get_layer_surface\(new id zwlr_layer_surface_v1#(\d+), wl_surface#(\d+), '
                r'[^\n]*?, "([^"]+)"\)', text
            ):
                configure = re.findall(rf'zwlr_layer_surface_v1#{layer}\.configure\(\d+, (\d+), (\d+)\)', text)
                if configure:
                    width, height = map(int, configure[-1])
                    layers[surface] = {'namespace': namespace, 'width': width, 'height': height}
            rectangles = re.findall(r'wl_surface#(\d+)\.damage(?:_buffer)?\((-?\d+), (-?\d+), (\d+), (\d+)\)', drag_log)
            damages = Counter(rect[0] for rect in rectangles)
            damaged_pixels = 0
            for surface, x, y, width, height in rectangles:
                if surface not in layers:
                    continue
                x, y, width, height = map(int, (x, y, width, height))
                dimensions = layers[surface]
                damaged_pixels += max(0, min(x + width, dimensions['width']) - max(x, 0)) * max(
                    0, min(y + height, dimensions['height']) - max(y, 0))
            result['trace'] = {
                'inputRegionUpdates': drag_log.count('.set_input_region('),
                'surfaceCommits': drag_log.count('.commit('),
                'damageSubmissions': sum(damages.values()),
                'damageBufferSubmissions': drag_log.count('.damage_buffer('),
                'damagedPixels': damaged_pixels,
                'nativeSurfaces': list(layers.values()),
            }
        # Exclude startup from CPU calculation, sample the steady drag phase.
        drag_samples = [sample for sample in samples if sample['time'] >= started + 1.2]
        if len(drag_samples) > 1:
            first, last = drag_samples[0], drag_samples[-1]
            result['cpuPercentOneCore'] = round(100 * (last['cpu'] - first['cpu'])
                                                / (last['time'] - first['time']), 2)
            result['rssPeakMiB'] = round(max(s['rssKiB'] for s in drag_samples) / 1024, 2)
        result['log'] = str(log_path)
        result['source'] = str(args.source.resolve())
        args.output.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
