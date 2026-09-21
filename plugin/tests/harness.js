// Arnes minimo para correr los modulos del cerebro con `node`, sin dependencias.
//
// Los archivos de brain/ arrancan con `.pragma library`, que es directiva de
// QML y no JavaScript valido, asi que no se pueden `require`. Se leen, se les
// saca la directiva y se evaluan en un contexto propio: el objeto resultante
// tiene los mismos nombres de arriba que ve QML con
// `import "brain/Gaps.js" as Geometry`, asi que el test toca exactamente la
// misma superficie que el shell.

var fs = require("fs")
var vm = require("vm")
var path = require("path")

function load(relPath) {
  var file = path.join(__dirname, "..", relPath)
  var src = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+\w+\s*$/gm, "")
  var sandbox = {
    Math: Math, JSON: JSON, Date: Date, console: console,
    String: String, Number: Number, Boolean: Boolean, Array: Array,
    Object: Object, RegExp: RegExp, Error: Error,
    parseInt: parseInt, parseFloat: parseFloat, isNaN: isNaN
  }
  vm.createContext(sandbox)
  vm.runInContext(src, sandbox, { filename: file })
  return sandbox
}

var passed = 0
var failed = []
var currentSuite = ""

function suite(name) {
  currentSuite = name
  console.log("\n" + name)
}

function ok(cond, label) {
  if (cond) {
    passed++
    console.log("  ok   " + label)
  } else {
    failed.push(currentSuite + " / " + label)
    console.log("  FAIL " + label)
  }
}

function eq(actual, expected, label) {
  var a = JSON.stringify(actual)
  var b = JSON.stringify(expected)
  if (a === b) {
    passed++
    console.log("  ok   " + label)
  } else {
    failed.push(currentSuite + " / " + label)
    console.log("  FAIL " + label)
    console.log("       esperado: " + b)
    console.log("       obtenido: " + a)
  }
}

function report() {
  console.log("\n" + passed + " ok, " + failed.length + " fallando")
  for (var i = 0; i < failed.length; i++) console.log("  - " + failed[i])
  process.exit(failed.length === 0 ? 0 : 1)
}

// Random determinista: devuelve los numeros que le pases, en orden, y cicla.
function seq() {
  var values = Array.prototype.slice.call(arguments)
  var i = 0
  return function () {
    var v = values[i % values.length]
    i++
    return v
  }
}

module.exports = { load: load, suite: suite, ok: ok, eq: eq, report: report, seq: seq }
