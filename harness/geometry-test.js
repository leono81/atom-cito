/* Contrasta plugin/poses/Geometry.js contra la tabla de PERSONAJE.md §2.
   Se corre con:  node harness/geometry-test.js
   (el .pragma library de la primera línea se saca antes de evaluar) */

var fs = require("fs");
var path = require("path");
var vm = require("vm");

var root = path.resolve(__dirname, "..");
var src = fs.readFileSync(path.join(root, "plugin/poses/Geometry.js"), "utf8")
            .replace(/^\s*\.pragma\s+library\s*$/m, "");

var ctx = { module: { exports: {} }, Math: Math, console: console };
ctx.exports = ctx.module.exports;
vm.createContext(ctx);
vm.runInContext(src, ctx);
var G = ctx.module.exports;

var fails = 0;
function check(name, got, want) {
    var ok = Math.abs(got - want) < 1e-9;
    if (!ok) { fails++; console.log("FALLA  " + name + ": " + got + " ≠ " + want); }
    else console.log("ok     " + name + " = " + got);
}

/* §2 — sistema de coordenadas */
check("viewBox ancho", G.UNITS_W, 34);
check("viewBox alto", G.UNITS_H, 24);
check("piso", G.FLOOR, 21);

/* §2 — piezas y pivotes (parado) */
var S = G.STAND;
check("cuerpo.x", S.body.x, 5.4);
check("cuerpo.y", S.body.y, 8.8);
check("cuerpo.w", S.body.w, 17.6);
check("cuerpo.h", S.body.h, 7.8);
check("cuerpo.r", S.body.r, 3.9);
check("cuerpo pivote x", S.bodyPivot.x, 14);
check("cuerpo pivote y", S.bodyPivot.y, 17);
check("cabeza cx", S.head.cx, 24.8);
check("cabeza cy", S.head.cy, 8);
check("cabeza r", S.head.r, 3.9);
check("hocico x", S.muzzle.x, 26.8);
check("nariz r", S.nose.r, 0.78);
check("ojo r", S.eye.r, 0.85);
check("oreja rot", S.ear.rot, -11);
check("oreja pivote x", S.ear.px, 23.2);
check("oreja pivote y", S.ear.py, 4.8);
check("cola pivote x", S.tail.px, 6.2);
check("cola pivote y", S.tail.py, 10.2);
check("pata del. cercana x", S.legs.frontNear.x, 21.2);
check("pata del. cercana y2", S.legs.frontNear.y2, 20.8);
check("pata del. lejana x", S.legs.frontFar.x, 19.4);
check("pata del. lejana y2", S.legs.frontFar.y2, 20.6);
check("pata tras. cercana x", S.legs.backNear.x, 10.4);
check("pata tras. lejana x", S.legs.backFar.x, 8.6);

/* §2 — grosores */
check("trazo cuerpo", G.STROKE.body, 1.05);
check("trazo pata", G.STROKE.leg, 2.1);
check("trazo cola", G.STROKE.tail, 1.7);
check("patas del fondo", G.FAR_OPACITY, 0.45);

/* §3 — respiración por pose */
check("respira parado", G.ANIM.breath.stand, 3200);
check("respira sentado", G.ANIM.breath.sit, 3800);
check("respira echado", G.ANIM.breath.lie, 4600);
check("respira dormido", G.ANIM.breath.sleep, 6000);

/* §3 — animaciones */
check("caminar período", G.ANIM.walkPeriod, 500);
check("patas ±grados", G.ANIM.legSwing, 17);
check("rebote", G.ANIM.bobDy, -0.45);
check("flopeo desde", G.ANIM.flopFrom, -4);
check("flopeo hasta", G.ANIM.flopTo, 7);
check("cola alegre período", G.ANIM.wagHappyPeriod, 380);
check("cola alegre ±", G.ANIM.wagHappySwing, 13);
check("cola tranquila período", G.ANIM.wagCalmPeriod, 1900);
check("cola tranquila ±", G.ANIM.wagCalmSwing, 7);
check("respirar dy", G.ANIM.breathDy, -0.35);
check("respirar escala", G.ANIM.breathScaleY, 1.02);
check("parpadeo", G.ANIM.blinkMs, 130);
check("parpadeo mín", G.ANIM.blinkGapMin, 3000);
check("parpadeo máx", G.ANIM.blinkGapMax, 7500);
check("zzz", G.ANIM.zzzPeriod, 3000);

/* Helpers */
var q = G.quad(S.tail);           // M6.4 10.2 q−3.2 −.6 −3.1 −4.3
check("cola control x", q.cx, 3.2);
check("cola control y", q.cy, 9.6);
check("cola fin x", q.ex, 3.3000000000000007);
check("cola fin y", q.ey, 5.9);

var sr = G.strokedRect({ x: 10, y: 10, w: 20, h: 8, r: 4 }, 1);
check("trazo afuera x", sr.x, 9.5);
check("trazo afuera w", sr.w, 21);
check("trazo afuera r", sr.r, 4.5);

var lr = G.legRect({ x: 21.2, y1: 15.4, y2: 20.8 }, 2.1);
check("pata ancho", lr.w, 2.1);
check("pata alto", lr.h, 7.5);
check("pata radio", lr.r, 1.05);

check("onda en 0", G.wave(0, 500), 0);
check("onda en medio", G.wave(250, 500), 1);
check("onda al final", G.wave(500, 500), 0);
check("swing en medio", G.swing(250, 500, -17, 17), 17);
/* 34×24 en 28×20 no es la misma proporción (1.4167 vs 1.4): manda el ancho. */
check("unidad 28x20", G.unitFor(28, 20), 28 / 34);

/* Las patas apoyan en el piso: la punta redonda llega a y2 + media línea. */
var pieY = S.legs.frontNear.y2 + G.STROKE.leg / 2;
console.log(pieY <= G.FLOOR + 1
    ? "ok     la pata cercana apoya en " + pieY + " (piso " + G.FLOOR + ")"
    : "FALLA  la pata queda en el aire: " + pieY);

console.log(fails ? "\n" + fails + " fallas" : "\nTodo en orden");
process.exit(fails ? 1 : 0);
