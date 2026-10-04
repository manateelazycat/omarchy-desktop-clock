// Shared positions use the available travel area, keeping the entire clock
// inside every monitor even when resolutions or scale factors differ.
function number(value, fallback) {
    if (value === undefined || value === null || value === "") return fallback;
    var result = Number(value);
    return isFinite(result) ? result : fallback;
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function unit(value, fallback) {
    return clamp(number(value, fallback), 0, 1);
}

function pixel(fraction, extent, size, margin) {
    var inset = Math.min(margin, Math.max(0, (extent - size) / 2));
    var travel = Math.max(0, extent - size - 2 * inset);
    return Math.round(inset + unit(fraction, 0.5) * travel);
}

function fraction(pixelPosition, extent, size, margin) {
    var inset = Math.min(margin, Math.max(0, (extent - size) / 2));
    var travel = Math.max(0, extent - size - 2 * inset);
    return travel > 0 ? unit((pixelPosition - inset) / travel, 0.5) : 0.5;
}
