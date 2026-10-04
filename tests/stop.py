#!/usr/bin/env python3
"""Inspect real compositor layer identity and geometry before/after drag release."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expect-stable', action='store_true')
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='clock-drag-stop-') as directory:
        runtime = Path(directory)
        (runtime / 'Plugin').mkdir()
        shutil.copytree(args.source / 'renderer', runtime / 'Plugin/renderer')
        shutil.copy2(ROOT / 'tests/Stop.qml', runtime / 'shell.qml')
        env = dict(os.environ, QT_QUICK_BACKEND='software', QSG_RENDER_LOOP='basic', WAYLAND_DEBUG='client')
        log_path = args.output.with_suffix('.log')
        with log_path.open('w') as log:
            proc = subprocess.Popen(['quickshell', '-p', str(runtime), '--no-color'], env=env,
                                    stdout=log, stderr=subprocess.STDOUT)
            def call(method):
                return subprocess.check_output(['qs', 'ipc', '--pid', str(proc.pid), 'call',
                                                'drag-stop-test', method], text=True, timeout=3).strip()
            def layers():
                data = json.loads(subprocess.check_output(['hyprctl', '-j', 'layers']))
                return [dict(monitor=name, **layer) for name, monitor in data.items()
                        for level in monitor['levels'].values() for layer in level
                        if layer.get('pid') == proc.pid]
            try:
                time.sleep(0.8)
                before = layers()
                call('press')
                time.sleep(0.05)
                call('move')
                time.sleep(0.05)
                moving = layers()
                samples = []
                stopped_at = time.monotonic()
                for delay in (0.01, 0.04, 0.08, 0.16):
                    time.sleep(delay)
                    samples.append({'afterSeconds': round(time.monotonic() - stopped_at, 4),
                                    'layers': layers()})
                stop_state = json.loads(call('status'))
                call('release')
                time.sleep(0.02)
                released = layers()
                release_state = json.loads(call('status'))
                time.sleep(0.2)
                settled = layers()
                visual = lambda values: [p for p in values if p['namespace'] == 'omarchy-desktop-clock']
                stable = (len(visual(before)) == len(visual(moving)) == len(visual(released)) == len(visual(settled)) == 1
                          and visual(before)[0]['address'] == visual(moving)[0]['address']
                          == visual(released)[0]['address'] == visual(settled)[0]['address'])
                stop_geometry = [[{k: p[k] for k in ['address', 'x', 'y', 'w', 'h', 'alpha']}
                                  for p in sorted(visual(sample['layers']), key=lambda p: p['address'])]
                                 for sample in samples]
                stopped = bool(stop_geometry[0]) and all(p == stop_geometry[0] for p in stop_geometry)
                position_stable = stop_state['positionX'] == release_state['positionX'] and stop_state['positionY'] == release_state['positionY']
                result = dict(source=str(args.source), before=before, moving=moving,
                              stopSamples=samples, released=released, settled=settled,
                              visibleWindowStable=stable, stoppedGeometryStable=stopped,
                              releasePositionStable=position_stable)
                args.output.write_text(json.dumps(result, indent=2) + '\n')
                print(json.dumps({k:result[k] for k in ['visibleWindowStable', 'stoppedGeometryStable', 'releasePositionStable']}, indent=2))
                if args.expect_stable:
                    assert stable, 'Visible layer was remapped during the gesture'
                    assert stopped and position_stable, 'Stopped/released clock moved'
                call('quit')
                proc.wait(timeout=3)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    proc.wait(timeout=3)


if __name__ == '__main__':
    main()
