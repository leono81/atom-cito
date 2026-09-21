// Tests de voice/atom-say. Nada de esto llama a `claude`: se prueba el prompt
// que armaria (--dry-run), el saneado de la salida y — sobre todo — que cuando
// falla no imprima nada y salga con codigo != 0, que es el contrato del que
// depende la caida al banco de frases local.

var h = require("./harness")
var path = require("path")
var fs = require("fs")
var os = require("os")
var cp = require("child_process")

var SAY = path.join(__dirname, "..", "voice", "atom-say")
var TMP = fs.mkdtempSync(path.join(os.tmpdir(), "atom-test-"))

function run(args, opts) {
  var o = opts || {}
  var env = {}
  for (var k in process.env) env[k] = process.env[k]
  env.ATOM_STATE_DIR = o.stateDir || TMP
  if (o.path !== undefined) env.PATH = o.path
  var r = cp.spawnSync(SAY, args, { env: env, encoding: "utf8", timeout: 20000 })
  return { code: r.status, out: r.stdout || "", err: r.stderr || "" }
}

var CTX = JSON.stringify({
  rule: "stretch",
  intent: "Lleva {streakMinutes} minutos seguidos sin salir de {app}.",
  app: "herdr",
  title: "herdr — ~/Projects/kenos",
  streakMinutes: 47,
  sessionMinutes: 112,
  clock: "23:14"
})

h.suite("atom-say / --dry-run arma el prompt sin llamar a nadie")
var dry = run(["--dry-run", CTX])
h.eq(dry.code, 0, "sale con 0")
h.ok(dry.out.indexOf("47 minutos seguidos sin salir de herdr") !== -1,
     "los {placeholders} del intent se renderizan igual que en Rules.js")
h.ok(dry.out.indexOf("voseo") !== -1, "manda la personalidad como system prompt")
h.ok(dry.out.indexOf("140 caracteres") !== -1, "y el limite de largo")
h.ok(dry.out.indexOf("herdr — ~/Projects/kenos") !== -1, "manda el titulo por defecto")

h.suite("atom-say / privacidad")
var sinTitulo = run(["--dry-run", JSON.stringify({ intent: "x", app: "herdr",
                                                   title: "cosas privadas", sendTitles: false })])
h.ok(sinTitulo.out.indexOf("cosas privadas") === -1, "con sendTitles:false el titulo no sale de la maquina")

h.suite("atom-say / no repetirse")
var histDir = fs.mkdtempSync(path.join(os.tmpdir(), "atom-hist-"))
fs.writeFileSync(path.join(histDir, "history.jsonl"),
  [JSON.stringify({ ts: 1, rule: "a", text: "Frase vieja uno." }),
   JSON.stringify({ ts: 2, rule: "b", text: "Frase vieja dos." }),
   "{ esto no es json }",
   JSON.stringify({ ts: 3, rule: "c", text: "Frase vieja tres." })].join("\n") + "\n")
var conHist = run(["--dry-run", CTX], { stateDir: histDir })
h.ok(conHist.out.indexOf("Frase vieja uno.") !== -1, "manda las frases previas como 'no repitas'")
h.ok(conHist.out.indexOf("Frase vieja tres.") !== -1, "todas las que encuentra")
h.eq(conHist.code, 0, "una linea corrupta en el historial no rompe nada")

h.suite("atom-say / degrada bien (nada por stdout, exit != 0)")
var sinClaude = run([CTX], { path: "/usr/bin:/bin" })   // claude no esta ahi
h.ok(sinClaude.code !== 0, "sin `claude` en el PATH sale con codigo != 0")
h.eq(sinClaude.out, "", "y no imprime nada por stdout")
h.ok(sinClaude.err.indexOf("PATH") !== -1, "el motivo va por stderr")

var malJson = run(["{ no soy json"])
h.ok(malJson.code !== 0, "JSON invalido: codigo != 0")
h.eq(malJson.out, "", "y stdout vacio")

var sinArgs = run([])
h.ok(sinArgs.code !== 0, "sin contexto: codigo != 0")
h.eq(sinArgs.out, "", "y stdout vacio")

var flagRara = run(["--que-es-esto", CTX])
h.ok(flagRara.code !== 0, "opcion desconocida: codigo != 0")
h.eq(flagRara.out, "", "y stdout vacio")

h.suite("atom-say / saneado de la salida del modelo")
// Se importa el script como modulo de python para probar sanitize() sola.
function sanitize(raw) {
  var code = [
    "import importlib.machinery, importlib.util, json, sys",
    // El script no termina en .py, asi que hay que cargarlo con el loader a mano.
    "loader = importlib.machinery.SourceFileLoader('atom_say', " + JSON.stringify(SAY) + ")",
    "spec = importlib.util.spec_from_loader('atom_say', loader)",
    "m = importlib.util.module_from_spec(spec); loader.exec_module(m)",
    "print(json.dumps(m.sanitize(json.loads(sys.argv[1]))))"
  ].join("\n")
  // Sin .pyc al lado del script: el directorio del plugin es fuente, no build.
  var penv = {}
  for (var e in process.env) penv[e] = process.env[e]
  penv.PYTHONDONTWRITEBYTECODE = "1"
  var r = cp.spawnSync("python3", ["-c", code, JSON.stringify(raw)], { encoding: "utf8", env: penv })
  if (r.status !== 0) throw new Error(r.stderr)
  return JSON.parse(r.stdout)
}

h.eq(sanitize("Tomá agua, che."), "Tomá agua, che.", "una frase limpia pasa igual")
h.eq(sanitize('"Tomá agua, che."'), "Tomá agua, che.", "saca las comillas envolventes")
h.eq(sanitize("“Tomá agua”"), "Tomá agua", "tambien las tipograficas")
h.eq(sanitize("  Tomá agua  \n"), "Tomá agua", "recorta los bordes")
h.eq(sanitize("Tomá agua.\n\nEsto lo dije porque lleva 112 minutos."), "Tomá agua.",
     "se queda con la primera linea y tira la explicacion")
h.eq(sanitize("- **Tomá** agua"), "Tomá agua", "saca bullets y markdown")
h.eq(sanitize("Tomá\nagua"), "Tomá", "colapsa: el globo dibuja una sola linea")
h.eq(sanitize(""), "", "salida vacia queda vacia (el llamador falla)")
h.eq(sanitize("   \n  "), "", "solo espacios, idem")

var largo = sanitize("Pará un cachito y tomá agua porque hace ciento doce minutos que no te levantás de la silla y ya se te nota en los hombros y en la cara, posta que si.")
h.ok(largo.length <= 140, "trunca a 140 caracteres (quedo en " + largo.length + ")")
h.ok(largo.indexOf(" ") === -1 || largo.charAt(largo.length - 1) !== " ", "sin espacio colgando")
h.ok(!/\w$/.test(largo) || largo.charAt(largo.length - 1) === ".", "no corta al medio de una palabra")

var dosOraciones = sanitize("Par\u00e1 un cachito y tom\u00e1 agua, que hace ciento doce minutos que no te levant\u00e1s de esa silla incomoda, posta. Y despues seguimos con lo que estabas haciendo, tranquilo.")
h.eq(dosOraciones, "Par\u00e1 un cachito y tom\u00e1 agua, que hace ciento doce minutos que no te levant\u00e1s de esa silla incomoda, posta.",
     "si hay un punto cerca del limite, corta ahi y no deja la frase colgada")

h.report()
