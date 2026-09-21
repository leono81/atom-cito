// Pure rule engine for the sidekick. No QML types in here on purpose: the rules
// are the part most likely to be tweaked, and keeping them side-effect free
// means they can be reasoned about (and unit-tested with node) on their own.
.pragma library

// Terminals host the interesting work, so "which app" is rarely the whole
// answer -- the TUI running inside the terminal is. We recognize the usual
// suspects from the window title and report those instead.
var TERMINALS = ["alacritty", "foot", "footclient", "kitty", "ghostty",
                 "com.mitchellh.ghostty", "org.wezfurlong.wezterm", "wezterm",
                 "xterm", "st", "terminal", "console"]

var TUIS = {
  "herdr": "herdr",
  "nvim": "neovim",
  "vim": "vim",
  "hx": "helix",
  "helix": "helix",
  "claude": "claude code",
  "lazygit": "lazygit",
  "lazydocker": "lazydocker",
  "btop": "btop",
  "htop": "htop",
  "top": "top",
  "tmux": "tmux",
  "ssh": "una sesion ssh",
  "psql": "psql",
  "yazi": "yazi",
  "ranger": "ranger"
}

var APPS = {
  "chromium": "Chromium",
  "google-chrome": "Chrome",
  "firefox": "Firefox",
  "zen": "Zen",
  "brave-browser": "Brave",
  "code": "VS Code",
  "cursor": "Cursor",
  "zed": "Zed",
  "obsidian": "Obsidian",
  "spotify": "Spotify",
  "discord": "Discord",
  "slack": "Slack",
  "signal": "Signal",
  "org.telegram.desktop": "Telegram",
  "thunderbird": "Thunderbird",
  "steam": "Steam",
  "mpv": "mpv",
  "vlc": "VLC",
  "org.gnome.Nautilus": "el explorador de archivos",
  "1password": "1Password",
  "figma": "Figma",
  "postman": "Postman",
  "dbeaver": "DBeaver"
}

function isTerminal(appId) {
  return TERMINALS.indexOf(String(appId || "").toLowerCase()) !== -1
}

// A friendly name for whatever has focus. For terminals we dig into the title
// looking for a known TUI, because "Alacritty" says nothing and "herdr" says
// everything.
function appLabel(appId, title) {
  var id = String(appId || "").trim()
  if (id === "") return "la nada"

  if (isTerminal(id)) {
    var tui = tuiFromTitle(title)
    if (tui) return tui
    return "la terminal"
  }

  if (APPS[id]) return APPS[id]
  var lower = id.toLowerCase()
  if (APPS[lower]) return APPS[lower]

  // org.foo.BarBaz -> BarBaz; otherwise just capitalize.
  var tail = id.split(".").pop()
  return tail.charAt(0).toUpperCase() + tail.slice(1)
}

function tuiFromTitle(title) {
  var words = String(title || "").toLowerCase().split(/[^a-z0-9_-]+/)
  for (var i = 0; i < words.length; i++) {
    var w = words[i]
    if (TUIS[w]) return TUIS[w]
  }
  return ""
}

// ---------------------------------------------------------------- the rules
//
// priority   higher wins when several rules match at once
// gapMinutes per-rule cooldown, on top of the global quiet window
// test       (ctx) -> bool
// intent     what we ask Claude to write about, with {placeholders}
// lines      local phrase bank, used when Claude is off or unreachable

var RULES = [
  {
    id: "marathon",
    priority: 40,
    gapMinutes: 45,
    test: function (c) { return c.sessionMinutes >= c.cfg.marathonMinutes },
    intent: "Lleva {sessionMinutes} minutos sin una sola pausa de verdad, clavado en la maquina (ahora en {app}). Deciselo sin sermon: que se levante, camine, salga del cuarto un rato.",
    lines: [
      "{sessionMinutes} minutos sin frenar. Esto ya no rinde igual, en serio.",
      "Van {sessionMinutes} minutos seguidos. Cinco caminando y volves mejor, te lo firmo.",
      "Dos horas largas sin moverte. El problema que estas peleando se resuelve solo si te vas un rato.",
      "{sessionMinutes} minutos. Levantate, aunque sea hasta la cocina y volves."
    ]
  },
  {
    id: "late",
    priority: 35,
    gapMinutes: 90,
    test: function (c) { return c.hour >= 0 && c.hour < 5 && c.sessionMinutes >= 20 },
    intent: "Son las {clock} de la madrugada y sigue laburando en {app}. Sugerile cerrar, sin drama.",
    lines: [
      "Son las {clock} y seguis. Manana esto se va a ver peor de lo que se ve ahora.",
      "{clock} de la madrugada. Guarda y anda a dormir, manana lo resolves en diez minutos.",
      "A esta hora el codigo que escribis es el que vas a borrar manana.",
      "{clock}. Lo que estas por commitear no lo entiende nadie, ni vos."
    ]
  },
  {
    id: "stretch",
    priority: 30,
    gapMinutes: 30,
    test: function (c) { return c.streakMinutes >= c.cfg.stretchMinutes },
    intent: "Lleva {streakMinutes} minutos seguidos sin salir de {app}. Sugerile parar un toque: estirarse, tomar agua, o simplemente parpadear.",
    lines: [
      "Van {streakMinutes} minutos clavado en {app}. No te parece que podriamos parar para estirar y tomar agua... o parpadear?",
      "{streakMinutes} minutos sin levantarte. Agua, ventana, dos respiraciones. Te espero.",
      "Che, {streakMinutes} minutos en {app}. Los hombros te lo van a agradecer.",
      "Hace {streakMinutes} minutos que no mirás mas alla de 60cm. Mira algo lejos un rato."
    ]
  },
  {
    id: "water",
    priority: 20,
    gapMinutes: 60,
    test: function (c) { return c.sessionMinutes >= c.cfg.waterMinutes },
    intent: "Hace {sessionMinutes} minutos que no para. Recordatorio corto de tomar agua, con humor, sin ser una app de bienestar.",
    lines: [
      "Hora de agua. Si, otra vez.",
      "El vaso esta vacio, no? Llenalo.",
      "Un carpincho toma agua cada tanto. Sugerencia de carpincho.",
      "Pausa hidratacion. Son diez segundos."
    ]
  },
  {
    id: "welcome",
    priority: 10,
    gapMinutes: 15,
    test: function (c) { return c.justReturned && c.awayMinutes >= 25 },
    intent: "Acaba de volver despues de {awayMinutes} minutos lejos de la maquina. Saludalo corto, sin ceremonia, y anda a {app} con el.",
    lines: [
      "Volviste. {awayMinutes} minutos de pausa, bien ahi.",
      "Buenas de nuevo. Contador en cero.",
      "{awayMinutes} minutos afuera. Asi se hace.",
      "Ahi estas. Arrancamos limpios."
    ]
  },
  {
    // Never fires on its own -- this is what a click on the carpincho asks for
    // when nothing else applies.
    id: "ondemand",
    priority: 0,
    gapMinutes: 0,
    test: function () { return false },
    intent: "Te pregunto directamente, clickeandote. Lleva {streakMinutes} minutos en {app} y {sessionMinutes} minutos desde la ultima pausa. Tirale un comentario corto sobre como viene la cosa.",
    lines: [
      "Vas {streakMinutes} minutos en {app}. Todo bien por ahora.",
      "{sessionMinutes} minutos de sesion. Vamos bien.",
      "Aca ando, mirando. Segui.",
      "Sin novedades. {streakMinutes} minutos en {app} y el mundo sigue girando."
    ]
  }
]

function ruleById(id) {
  for (var i = 0; i < RULES.length; i++) if (RULES[i].id === id) return RULES[i]
  return null
}

// Pick the highest-priority rule that both matches and is off cooldown.
function pick(ctx, lastFired, nowMs) {
  var best = null
  for (var i = 0; i < RULES.length; i++) {
    var rule = RULES[i]
    var last = lastFired[rule.id] || 0
    if (nowMs - last < rule.gapMinutes * 60000) continue
    var matches = false
    try { matches = !!rule.test(ctx) } catch (e) { matches = false }
    if (!matches) continue
    if (!best || rule.priority > best.priority) best = rule
  }
  return best
}

function render(template, ctx) {
  return String(template || "").replace(/\{(\w+)\}/g, function (match, key) {
    var v = ctx[key]
    return (v === undefined || v === null) ? match : String(v)
  })
}

function fallback(rule, ctx) {
  var lines = rule.lines || []
  if (lines.length === 0) return ""
  var pickIndex = Math.floor(Math.random() * lines.length)
  return render(lines[pickIndex], ctx)
}
