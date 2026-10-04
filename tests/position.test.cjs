const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const position = vm.createContext({});
vm.runInContext(readFileSync(join(__dirname, '..', 'renderer', 'Position.js'), 'utf8'), position);

test('relative positions round-trip across resolutions and logical scales', () => {
  for (const extent of [640, 1080, 1440, 1920, 2560, 3840]) {
    for (const size of [186, 444, 666]) {
      if (extent <= size + 48) continue;
      for (const fraction of [0, 0.1, 0.5, 0.52, 0.9, 1]) {
        const pixel = position.pixel(fraction, extent, size, 24);
        assert.ok(pixel >= 24 && pixel + size <= extent - 24);
        assert.ok(Math.abs(position.fraction(pixel, extent, size, 24) - fraction)
          <= 0.5 / (extent - size - 48) + 1e-12);
      }
    }
  }
});

test('dragging past a monitor edge clamps to the visible travel area', () => {
  assert.equal(position.fraction(-200, 1920, 444, 24), 0);
  assert.equal(position.fraction(4000, 1920, 444, 24), 1);
  assert.equal(position.pixel(-5, 1920, 444, 24), 24);
  assert.equal(position.pixel(5, 1920, 444, 24), 1452);
});

test('small monitors have a stable centered position without division by zero', () => {
  assert.equal(position.pixel(0.9, 444, 444, 24), 0);
  assert.equal(position.fraction(100, 444, 444, 24), 0.5);
  assert.equal(position.pixel(0.1, 460, 444, 24), 8);
});

test('missing or damaged settings use defaults; valid zero stays zero', () => {
  for (const value of [undefined, null, '', 'broken', NaN, Infinity]) {
    assert.equal(position.unit(value, 0.52), 0.52);
  }
  assert.equal(position.unit(0, 0.52), 0);
  assert.equal(position.unit('0.75', 0.52), 0.75);
  assert.equal(position.unit(-1, 0.52), 0);
  assert.equal(position.unit(2, 0.52), 1);
});
