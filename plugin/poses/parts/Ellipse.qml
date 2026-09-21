import QtQuick
import QtQuick.Shapes
import "../Geometry.js" as Geo

/* La primitiva de elipse contorneada: la oreja y las patas apoyadas
   (la grupa del sentado, las manos del echado y del dormido).

   QML no tiene elipse, así que se arma con cuatro cúbicas (Geometry.js).
   El Item mide la caja de la elipse más media línea de trazo por lado, y
   `rot` gira alrededor de su centro — el ángulo fijo que trae la spec. */
Item {
    id: part

    property real u: 1
    property var spec: ({ cx: 0, cy: 0, rx: 0, ry: 0 })
    property real rot: 0
    property real strokeWidth: Geo.STROKE.body
    property color ink: "#ffffff"
    property color fill: "#000000"

    readonly property real pad: strokeWidth * u / 2

    x: (spec.cx - spec.rx) * u - pad
    y: (spec.cy - spec.ry) * u - pad
    width: spec.rx * 2 * u + pad * 2
    height: spec.ry * 2 * u + pad * 2

    rotation: rot
    transformOrigin: Item.Center

    readonly property var segs: Geo.ellipseSegments(width / 2, height / 2,
                                                    spec.rx * u, spec.ry * u)

    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeColor: part.ink
            strokeWidth: part.strokeWidth * part.u
            fillColor: part.fill
            joinStyle: ShapePath.RoundJoin
            startX: part.width / 2 + part.spec.rx * part.u
            startY: part.height / 2

            PathCubic {
                control1X: part.segs[0].c1x; control1Y: part.segs[0].c1y
                control2X: part.segs[0].c2x; control2Y: part.segs[0].c2y
                x: part.segs[0].x;           y: part.segs[0].y
            }
            PathCubic {
                control1X: part.segs[1].c1x; control1Y: part.segs[1].c1y
                control2X: part.segs[1].c2x; control2Y: part.segs[1].c2y
                x: part.segs[1].x;           y: part.segs[1].y
            }
            PathCubic {
                control1X: part.segs[2].c1x; control1Y: part.segs[2].c1y
                control2X: part.segs[2].c2x; control2Y: part.segs[2].c2y
                x: part.segs[2].x;           y: part.segs[2].y
            }
            PathCubic {
                control1X: part.segs[3].c1x; control1Y: part.segs[3].c1y
                control2X: part.segs[3].c2x; control2Y: part.segs[3].c2y
                x: part.segs[3].x;           y: part.segs[3].y
            }
        }
    }
}
