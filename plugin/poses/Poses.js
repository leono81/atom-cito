.pragma library

/* ════════════════════════════════════════════════════════════════════════
   Poses.js — el registro.

   Agregar una pose es crear el archivo y sumar una línea acá. El renderer
   (Atom.qml) no se toca: no conoce ninguna pose por su nombre.

   `canMove` NO vive acá: es un dato de cada pose (ARQUITECTURA.md §4.2),
   para que el Mover consulte a la pose activa y no a una tabla paralela que
   se puede desincronizar.
   ════════════════════════════════════════════════════════════════════════ */

var POSES = [
    { id: "stand", file: "Stand.qml" },
    { id: "walk",  file: "Walk.qml"  },
    { id: "sit",   file: "Sit.qml"   },
    { id: "lie",   file: "Lie.qml"   },
    { id: "sleep", file: "Sleep.qml" },
    { id: "scratch", file: "Scratch.qml" },
    { id: "play",    file: "Play.qml"    },
    { id: "jump",    file: "Jump.qml"    },
    { id: "pee",     file: "Pee.qml"     }
];

function ids() {
    var out = [];
    for (var i = 0; i < POSES.length; i++) out.push(POSES[i].id);
    return out;
}

function byId(id) {
    for (var i = 0; i < POSES.length; i++) {
        if (POSES[i].id === id) return POSES[i];
    }
    return null;
}

function first() {
    return POSES.length ? POSES[0].id : "";
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { POSES: POSES, ids: ids, byId: byId, first: first };
}
