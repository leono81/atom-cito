.pragma library

/* ════════════════════════════════════════════════════════════════════════
   Geometry.js — las constantes del dibujo de Atom.

   Transcripción de PERSONAJE.md §2 y del prototipo docs/perro.html.
   Un solo lugar: ningún .qml escribe un número de dibujo a mano.

   Sistema: viewBox de 34 × 24 unidades, piso en y = 21, mira a la derecha.
   Sintaxis conservadora a propósito (var / function, sin arrow ni template
   literals) para que node pueda evaluar este archivo tal cual y contrastarlo
   contra la tabla de la spec.
   ════════════════════════════════════════════════════════════════════════ */

var UNITS_W = 34;
var UNITS_H = 24;
var FLOOR = 21;

/* Grosores (PERSONAJE.md §2, última línea de la tabla) */
var STROKE = {
    body: 1.05,   // cuerpo y cabeza
    leg: 2.1,     // patas, con punta redonda
    tail: 1.7,    // cola
    lid: 0.9      // párpado
};

/* Las patas del fondo: profundidad sin una línea nueva. */
var FAR_OPACITY = 0.45;

/* ── Timings y amplitudes (PERSONAJE.md §3, tabla de animaciones) ─────── */
var ANIM = {
    breath: { stand: 3200, sit: 3800, lie: 4600, sleep: 6000 },
    breathDy: -0.35,          // unidades
    breathScaleY: 1.02,

    walkPeriod: 500,          // patas, rebote y flopeo
    legSwing: 17,             // ± grados
    bobDy: -0.45,             // unidades
    flopFrom: -4,             // grados
    flopTo: 7,

    wagHappyPeriod: 380,
    wagHappySwing: 13,        // ± grados
    wagCalmPeriod: 1900,
    wagCalmSwing: 7,

    speakPeriod: 300,         // cola alegre + orejas mientras habla

    blinkMs: 130,
    blinkGapMin: 3000,
    blinkGapMax: 7500,

    zzzPeriod: 3000,
    zzzDx: 2,
    zzzDy: -5,

    crossFadeMs: 160
};

/* ── PARADO / CAMINANDO ───────────────────────────────────────────────── */
var STAND = {
    body: { x: 5.4, y: 8.8, w: 17.6, h: 7.8, r: 3.9 },
    bodyPivot: { x: 14, y: 17 },
    head: { cx: 24.8, cy: 8, r: 3.9 },
    muzzle: { x: 26.8, y: 7.6, w: 5.3, h: 3.7, r: 1.6 },
    nose: { cx: 31.5, cy: 8.7, r: 0.78 },
    eye: { cx: 25.3, cy: 7.1, r: 0.85 },
    lid: { sx: 24.6, sy: 7.1, dcx: 0.7, dcy: 0.8, dx: 1.4, dy: 0 },
    ear: { cx: 23.2, cy: 7.7, rx: 1.55, ry: 3.1, rot: -11, px: 23.2, py: 4.8 },
    tail: { sx: 6.4, sy: 10.2, dcx: -3.2, dcy: -0.6, dx: -3.1, dy: -4.3,
            px: 6.2, py: 10.2 },
    legs: {
        backFar:   { x: 8.6,  y1: 15.4, y2: 20.6 },
        frontFar:  { x: 19.4, y1: 15.4, y2: 20.6 },
        backNear:  { x: 10.4, y1: 15.4, y2: 20.8 },
        frontNear: { x: 21.2, y1: 15.4, y2: 20.8 }
    }
};

/* ── SENTADO: grupa en el piso, pecho arriba ──────────────────────────── */
var SIT = {
    haunch: { x: 5.2, y: 11.4, w: 10.6, h: 9.6, r: 4.6 },
    chest: { x: 11.6, y: 9.2, w: 10.8, h: 8, r: 3.9 },
    bodyPivot: { x: 14, y: 19 },
    paw: { cx: 13.4, cy: 20.1, rx: 2.3, ry: 1.1 },
    head: { cx: 24.6, cy: 6.6, r: 3.9 },
    muzzle: { x: 26.6, y: 6.2, w: 5.3, h: 3.7, r: 1.6 },
    nose: { cx: 31.3, cy: 7.3, r: 0.78 },
    eye: { cx: 25.1, cy: 5.7, r: 0.85 },
    lid: { sx: 24.4, sy: 5.7, dcx: 0.7, dcy: 0.8, dx: 1.4, dy: 0 },
    ear: { cx: 23, cy: 6.4, rx: 1.55, ry: 3.1, rot: -9, px: 23, py: 3.6 },
    tail: { sx: 6.4, sy: 19.4, dcx: -3.4, dcy: 0.5, dx: -3.6, dy: -1.9,
            px: 6.4, py: 19.4 },
    legs: {
        frontFar:  { x: 19.2, y1: 15.6, y2: 20.6 },
        frontNear: { x: 21,   y1: 15.8, y2: 20.8 }
    }
};

/* ── ECHADO: cuerpo en el piso, cabeza levantada ──────────────────────── */
var LIE = {
    body: { x: 4.8, y: 14.2, w: 19, h: 6.9, r: 3.4 },
    bodyPivot: { x: 14, y: 20 },
    paw: { cx: 23.4, cy: 19.9, rx: 3.1, ry: 1.25 },
    head: { cx: 25.4, cy: 12.6, r: 3.8 },
    muzzle: { x: 27.3, y: 12.2, w: 5.2, h: 3.6, r: 1.6 },
    nose: { cx: 31.9, cy: 13.3, r: 0.76 },
    eye: { cx: 25.9, cy: 11.7, r: 0.83 },
    lid: { sx: 25.2, sy: 11.7, dcx: 0.7, dcy: 0.8, dx: 1.4, dy: 0 },
    ear: { cx: 23.7, cy: 12.3, rx: 1.5, ry: 3, rot: -16, px: 23.6, py: 9.6 },
    tail: { sx: 5.6, sy: 19.2, dcx: -3.3, dcy: 0.4, dx: -3.5, dy: -1.5,
            px: 5.6, py: 19.2 }
};

/* ── DORMIDO: cabeza sobre las patas, ojos cerrados ───────────────────── */
var SLEEP = {
    body: { x: 4.8, y: 14.6, w: 18.4, h: 6.5, r: 3.2 },
    bodyPivot: { x: 14, y: 20 },
    paw: { cx: 27.4, cy: 20.2, rx: 3.2, ry: 1.1 },
    head: { cx: 25.2, cy: 16.9, r: 3.7 },
    muzzle: { x: 27.1, y: 16.8, w: 5.2, h: 3.5, r: 1.6 },
    nose: { cx: 31.7, cy: 17.9, r: 0.76 },
    eye: null,                                   // duerme: no hay ojo, hay párpado
    lid: { sx: 24.4, sy: 16.6, dcx: 0.9, dcy: 0.9, dx: 1.8, dy: 0 },
    ear: { cx: 23.4, cy: 16.8, rx: 1.5, ry: 3, rot: -22, px: 23.4, py: 14 },
    tail: { sx: 5.6, sy: 19.4, dcx: -3.3, dcy: 0.3, dx: -3.4, dy: -1.4,
            px: 5.6, py: 19.4 },
    zzz: [ { x: 27.5, y: 10.5, size: 4.4 },
           { x: 30.2, y: 7.2,  size: 3.2 } ]
};

/* ════════════════════════════════════════════════════════════════════════
   Helpers — la aritmética que en SVG hace el renderer y en QML hay que
   hacer a mano.
   ════════════════════════════════════════════════════════════════════════ */

/* Un `q` de SVG es relativo al punto inicial; acá lo pasamos a absoluto. */
function quad(t) {
    return {
        sx: t.sx, sy: t.sy,
        cx: t.sx + t.dcx, cy: t.sy + t.dcy,
        ex: t.sx + t.dx, ey: t.sy + t.dy
    };
}

/* SVG pinta el trazo a caballo del borde; Rectangle de QML lo pinta para
   adentro. Para que el contorno caiga donde la spec dice, el rectángulo de
   QML se agranda media línea por lado. */
function strokedRect(r, sw) {
    return { x: r.x - sw / 2, y: r.y - sw / 2,
             w: r.w + sw, h: r.h + sw,
             r: r.r + sw / 2 };
}

/* Un círculo como rectángulo con radio = mitad del lado. */
function circleRect(c) {
    return { x: c.cx - c.r, y: c.cy - c.r, w: c.r * 2, h: c.r * 2, r: c.r };
}

/* Una pata: línea con punta redonda = cápsula. La punta sobresale media
   línea de cada extremo, igual que `stroke-linecap: round`. */
function legRect(l, sw) {
    return { x: l.x - sw / 2, y: l.y1 - sw / 2,
             w: sw, h: (l.y2 - l.y1) + sw, r: sw / 2 };
}

/* Elipse en 4 cúbicas (QML no tiene primitiva de elipse). */
var KAPPA = 0.5522847498307936;

function ellipseSegments(cx, cy, rx, ry) {
    var ox = rx * KAPPA, oy = ry * KAPPA;
    return [
        { c1x: cx + rx, c1y: cy + oy, c2x: cx + ox, c2y: cy + ry, x: cx,      y: cy + ry },
        { c1x: cx - ox, c1y: cy + ry, c2x: cx - rx, c2y: cy + oy, x: cx - rx, y: cy },
        { c1x: cx - rx, c1y: cy - oy, c2x: cx - ox, c2y: cy - ry, x: cx,      y: cy - ry },
        { c1x: cx + ox, c1y: cy - ry, c2x: cx + rx, c2y: cy - oy, x: cx + rx, y: cy }
    ];
}

/* El equivalente de un @keyframes `0%,100% A · 50% B` con ease-in-out:
   devuelve 0 en los bordes y 1 en el medio del período. */
function wave(ms, period) {
    if (!period) return 0;
    return 0.5 - 0.5 * Math.cos(2 * Math.PI * (ms / period));
}

/* Interpola con esa misma onda: de `a` a `b` y vuelta. */
function swing(ms, period, a, b) {
    return a + (b - a) * wave(ms, period);
}

/* Escala: cuántos píxeles mide una unidad dentro de una caja, sin deformar. */
function unitFor(w, h) {
    return Math.min(w / UNITS_W, h / UNITS_H);
}

/* Para que node pueda importar este archivo sin ceremonia. */
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        UNITS_W: UNITS_W, UNITS_H: UNITS_H, FLOOR: FLOOR,
        STROKE: STROKE, FAR_OPACITY: FAR_OPACITY, ANIM: ANIM,
        STAND: STAND, SIT: SIT, LIE: LIE, SLEEP: SLEEP,
        quad: quad, strokedRect: strokedRect, circleRect: circleRect,
        legRect: legRect, ellipseSegments: ellipseSegments,
        wave: wave, swing: swing, unitFor: unitFor
    };
}
