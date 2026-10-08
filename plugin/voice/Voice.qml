import QtQuick
import Quickshell
import Quickshell.Io
import "../brain/Rules.js" as Rules

// La voz: convierte una regla que disparó en una frase concreta.
//
// Cadena de dos eslabones. Claude escribe la frase cuando puede; el banco
// local contesta siempre. El banco NO es un plan B degradado — está escrito
// con el mismo cuidado que el prompt, y con `useClaude: false` Atom sigue
// siendo un producto entero.
//
// Todo es asincrónico por obligación, no por elegancia: aun sin thinking,
// `claude -p` tarda unos 4 segundos, y un hilo de QML bloqueado es la barra
// congelada.
Item {
  id: root
  visible: false

  property string scriptPath: ""
  property bool useClaude: true
  property bool sendTitles: true
  property string model: ""          // vacío: el que trae atom-say
  property int timeoutSeconds: 90

  // (ruleId, texto, origen) — origen es "claude" o "local".
  signal said(string ruleId, string text, string source)

  readonly property bool busy: proc.running

  property string _ruleId: ""
  property var _rule: null
  property var _ctx: null

  function request(rule, ctx) {
    if (!rule) return false
    if (proc.running) return false          // uno por vez: no encolamos

    root._rule = rule
    root._ruleId = String(rule.id)
    root._ctx = ctx

    if (!root.useClaude || root.scriptPath === "") {
      root._fallback("local")
      return true
    }

    var payload = {
      app: String(ctx.app || ""),
      streakMinutes: Number(ctx.streakMinutes || 0),
      sessionMinutes: Number(ctx.sessionMinutes || 0),
      hour: Number(ctx.hour || 0),
      clock: String(ctx.clock || ""),
      agents: Number(ctx.agents || 0),
      justReturned: ctx.justReturned === true,
      awayMinutes: Number(ctx.awayMinutes || 0),
      intent: Rules.render(rule.intent, ctx)
    }
    // El título es lo más sensible que sale de la máquina, y se puede apagar.
    if (root.sendTitles) payload.title = String(ctx.title || "")

    var cmd = [root.scriptPath, "--timeout", String(root.timeoutSeconds)]
    if (root.model !== "") cmd.push("--model", root.model)
    cmd.push(JSON.stringify(payload))
    proc.command = cmd
    proc.running = true
    return true
  }

  function _fallback(reason) {
    var text = ""
    try { text = Rules.fallback(root._rule, root._ctx) } catch (e) { text = "" }
    if (text !== "") root.said(root._ruleId, text, "local")
  }

  Process {
    id: proc

    stdout: StdioCollector { waitForEnd: true }

    onExited: function (code, status) {
      var text = String(proc.stdout.text || "").replace(/^\s+|\s+$/g, "")
      if (code === 0 && text !== "") root.said(root._ruleId, text, "claude")
      else root._fallback("exit=" + code)
    }
  }
}
