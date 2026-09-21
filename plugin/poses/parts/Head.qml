import QtQuick
import QtQuick.Shapes
import "../Geometry.js" as Geo

/* La cabeza y lo que va pegado a ella: cráneo, hocico, nariz, ojo y
   párpado. Van juntos en una pieza porque en el dibujo son contiguos —
   ninguna otra pieza se mete en el medio — y porque el parpadeo necesita
   al ojo y al párpado del mismo lado.

   `spec` es la pose entera (Geo.STAND, Geo.SIT, …): de ahí toma head,
   muzzle, nose, eye y lid. `eye` en null = duerme, y queda solo el
   párpado cerrado. */
Item {
    id: head

    property real u: 1
    property var spec
    property bool blinking: false
    property color ink: "#ffffff"
    property color fill: "#000000"

    anchors.fill: parent

    /* Cráneo */
    Body {
        u: head.u
        spec: Geo.circleRect(head.spec.head)
        ink: head.ink
        fill: head.fill
    }

    /* Hocico */
    Body {
        u: head.u
        spec: head.spec.muzzle
        ink: head.ink
        fill: head.fill
    }

    /* Nariz: relleno macizo, sin contorno */
    Rectangle {
        readonly property var g: Geo.circleRect(head.spec.nose)
        x: g.x * head.u
        y: g.y * head.u
        width: g.w * head.u
        height: g.h * head.u
        radius: width / 2
        color: head.ink
        antialiasing: true
    }

    /* Ojo: se apaga 130 ms cuando parpadea */
    Rectangle {
        readonly property var g: head.spec.eye ? Geo.circleRect(head.spec.eye) : null
        visible: g !== null && !head.blinking
        x: g ? g.x * head.u : 0
        y: g ? g.y * head.u : 0
        width: g ? g.w * head.u : 0
        height: g ? g.h * head.u : 0
        radius: width / 2
        color: head.ink
        antialiasing: true
    }

    /* Párpado / línea del cachete */
    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            id: lidPath
            readonly property var q: Geo.quad(head.spec.lid)
            strokeColor: head.ink
            strokeWidth: Geo.STROKE.lid * head.u
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: q.sx * head.u
            startY: q.sy * head.u
            PathQuad {
                controlX: lidPath.q.cx * head.u
                controlY: lidPath.q.cy * head.u
                x: lidPath.q.ex * head.u
                y: lidPath.q.ey * head.u
            }
        }
    }
}
