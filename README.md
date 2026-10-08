# Jarvis (grivera.jarvis)

**A voice assistant for Omarchy.** Press the Copilot key, say what you want, and
Jarvis does it: open and arrange apps, switch workspaces, play music, change
settings, answer questions, and even design you a new theme.

Speech recognition and Jarvis's voice run locally on your laptop. Simple
commands happen instantly; anything else is planned by Claude, which can only
choose from a fixed set of safe actions that Jarvis checks before running.

![Jarvis: the panel, the on-screen bubble and the bar icon](preview.png)

## Install

Use Omarchy's plugin manager:

```
omarchy plugin add https://github.com/grivera82/omarchy-jarvis.git --enable
```

This clones the plugin into `~/.config/omarchy/plugins/grivera.jarvis` and adds
the arc reactor icon to your bar. Then:

1. **Download the speech models.** Click the icon and press **Set up**, or run
   `~/.config/omarchy/plugins/grivera.jarvis/bin/jarvis setup`. It creates a
   Python environment with faster-whisper and Kokoro and downloads the models
   (about 1.5 GB, in `~/.local/share/grivera-jarvis/`). A few minutes, once.
2. **Bind the Copilot key.** Add this to `~/.config/hypr/bindings.lua`:

   ```lua
   -- Omarchy binds the Copilot key (code:201 = F23) to its menu; free it first.
   hl.unbind("SUPER + SHIFT + code:201")
   local jarvis = os.getenv("HOME") .. "/.config/omarchy/plugins/grivera.jarvis/bin/jarvis"
   o.bind("SUPER + SHIFT + F23", "Jarvis", jarvis .. " press")
   o.bind("SUPER + SHIFT + F23", nil, jarvis .. " release", { release = true })
   ```

   Most laptops' Copilot key sends Super+Shift+F23. No Copilot key? Bind any
   key you like. You can also right-click the bar icon to talk, or type a
   request in the panel.
3. **Make sure Claude Code is installed and signed in** (`claude` on your PATH).
   Jarvis uses it in print mode with the fast Haiku model to plan requests the
   built-in commands don't cover. Your subscription or API key works as is.

To update or remove it: `omarchy plugin update grivera.jarvis`,
`omarchy plugin remove grivera.jarvis`.

## What it can do

**Talk to your desktop**
- Tap the Copilot key and speak; Jarvis stops when you stop. Or hold the key
  while you talk and let go to send. Press it again to interrupt.
- Say "Hey Jarvis, …" if you like: the name is understood and ignored.
- A bubble at the bottom of the screen shows what it heard, that it's
  thinking, and what it did. Music pauses while you speak and resumes after.

**Apps, windows and workspaces**
- "Open Firefox on workspace 2", "close this window", "move this to workspace 3
  and make it full screen", "switch to Chromium", "float it".
- "Close all the terminals": anything that closes three or more windows asks
  first, and you answer by voice.

**All of Omarchy**
- Jarvis reads Omarchy's own command catalog (`omarchy commands --json`), so it
  can run 135 of its commands: screen recording, screenshots and OCR, Bluetooth,
  night light, do not disturb, power profiles, fonts, themes and backgrounds,
  menus and switchers, keyboard backlight, brightness, audio outputs,
  reminders, webapps, network status and speed tests, and more.
- Questions get spoken answers from real data: "how much battery do I have?",
  "what's the weather?", "what version of Omarchy am I running?",
  "how fast is my internet?" Plus the time, the date and quick math.

**Music**
- **Spotify through [Spotifast](https://spotifast.rocks)**: "play Radiohead",
  "play Blinding Lights by The Weeknd", "play the album OK Computer",
  "play my workout playlist", "play my liked songs", "what song is this?",
  "like this song", shuffle, repeat, volume.
- **Internet radio in [cliamp](https://github.com/bjarneo/cliamp)**: "play Groove
  Salad in cliamp", "play some jazz radio on cliamp". Stations come from
  radio-browser.info by name or genre.
- Play, pause, next and previous for any player through MPRIS.

**Make things**
- "Make me a new background of a misty pine forest at dawn": Codex paints a
  wallpaper, saves it with your theme's backgrounds and sets it.
- "Make me a theme inspired by a rainy night in Tokyo": Claude designs a full
  Omarchy theme (palette, icons, bar and menu colors) and Codex paints a
  matching wallpaper. It's saved to `~/.config/omarchy/themes/` and applied,
  about a minute later.
- "Change the keyboard to sunset orange" on laptops with RGB keyboards (needs
  the `asus-kbd-rgb` tool; see Requirements).

**Your own commands**
- Add phrases in `~/.config/grivera-jarvis/phrases.toml` (panel: Edit phrases):

  ```toml
  [[phrase]]
  say = ["work mode", "start work mode"]
  run = "omarchy launch browser https://mail.hey.com && uwsm-app -- obsidian"
  reply = "Work mode on."

  [[phrase]]
  say = "note *"                       # * captures words, passed as {1}
  run = "echo {1} >> ~/notes.txt"      # captures are shell-quoted for you
  ```

  Your phrases are checked before anything else and reload when you save.

**It gets better as you use it**
- **Learned requests**: when Claude handles something successfully, Jarvis
  remembers the plan, so the next time you say it, it runs instantly.
- **Corrections**: "no, I said Chromium" right after a mishearing fixes the
  request and teaches Jarvis that "card running" means Chromium from then on.
  Rephrasing a failed request teaches it too.
- **Your vocabulary**: artists, playlists, stations and apps you use are fed to
  the speech recognizer as hints.
- **"That's wrong"** makes it forget how it handled the last request.
- **Self-tuning**: if requests keep getting cut off, it waits longer for
  pauses; if your mic is distorting, it tells you.
- The panel lists **what it couldn't do**, so you know what to add.

## Use cases

- **Start your day in one sentence**: a "work mode" phrase that opens your mail,
  notes and editor and moves them where you like them.
- **Hands busy**: cooking, eating or holding a guitar. "Pause", "next song",
  "volume to 40", "what song is this?"
- **Window wrangling without shortcuts**: "put Spotify on workspace 4 and close
  the other terminals".
- **Quick answers without leaving what you're doing**: battery, weather, time,
  "what's 18 percent of 64?"
- **Recording and presenting**: "start a screen recording", "turn on do not
  disturb", "hide the bar".
- **Making the desktop yours**: "make me a theme inspired by the Mediterranean
  in summer", then "make me a new background of an olive grove at sunset".
- **Fewer keystrokes**: helpful for RSI, accessibility, or when you can't
  remember the shortcut for something you do twice a year.

## How it works

```
Copilot key ─► jarvis press ─► daemon: microphone (PipeWire) + Silero VAD
                                   │
                       faster-whisper, on your laptop (~0.7 s)
                                   │
   your phrases ─► built-in matcher ─► learned requests ─► Claude (claude -p, Haiku)
     (instant)       (instant)           (instant)          plans with tools only, ~2 s
                                   │
       actions, each checked: real window addresses, installed apps,
       http(s) URLs, Omarchy commands by safety tier
                                   │
      a chime, or a spoken reply in Kokoro's "George" voice (local), + the bubble
```

Requests take about 1 second when handled locally and 2 to 4 seconds when
Claude plans them.

## Safety

Claude never runs anything itself. It returns a plan made of named actions,
and Jarvis checks each one before running it, without a shell:

- **Allowed**: window and app control, media, toggles, capture, menus,
  brightness, audio, theme and fonts, status questions.
- **Asks first** (you say "yes"): restarts, default apps, DNS, display scaling,
  turning off the laptop screen, closing three or more windows, webapps.
- **Blocked, and not even shown to Claude**: anything needing sudo, installing
  or removing software, updates, refresh/reinstall, shutdown, reboot and
  logout, and arbitrary shell commands.

Only your own phrases run shell commands, and they're yours to write.

## Privacy

- Your voice is recognized on your laptop and never uploaded. Jarvis's voice
  is generated locally too.
- When a request goes to Claude, the text of what you said, your open window
  titles and installed app names are sent along so it can plan.
- **Instant start** (off by default; turn it on in the panel) keeps the
  microphone open with only the last second held in memory, so a word said
  as you press the key isn't lost. Nothing is saved or transcribed until you
  press the key, but your system shows the mic as in use. With it off, the
  mic opens only when you press the key, and a word said in that first
  fraction of a second can be lost.
- History, learned data and the Spotify sign-in stay in
  `~/.local/state/grivera-jarvis/` (files readable only by you).

## Requirements

- Omarchy 4 (Hyprland 0.56 with the Lua config), PipeWire, Python 3.
- [Claude Code](https://claude.com/claude-code) for planning, signed in.
- Optional:
  - The [Codex CLI](https://github.com/openai/codex) with image generation, for
    backgrounds and themes.
  - Spotifast, with a personal Spotify app set up in its Settings → Account, for
    playing Spotify by name. Jarvis signs in with that app's client ID: add
    `http://127.0.0.1:8989/login` to the app's redirect URIs in the Spotify
    developer dashboard (or set `spotifyRedirect` to one already registered),
    then click **Connect Spotify** in the panel once.
  - cliamp, for internet radio.
  - `asus-kbd-rgb` on your PATH for keyboard colors (ASUS Vivobook-style HID
    LampArray keyboards).

## Settings

Most settings are in the panel: spoken replies (when useful, always, off), the
voice (11 English voices), fast or accurate recognition, instant start, sounds,
pausing music while listening, listening for an answer after a question, and
the on-screen bubble. Everything lives in
`~/.local/state/grivera-jarvis/config.json`; a few more keys:

| Key | Default | |
|---|---|---|
| `claudeModel` | `haiku` | Model that plans requests |
| `themeModel` | `sonnet` | Model that designs themes |
| `silence` | `1.0` | Seconds of quiet that end a request (self-tunes) |
| `maxSeconds` | `15` | Longest request |
| `spotifyRedirect` | `http://127.0.0.1:8989/login` | Redirect URI registered in your Spotify app |

## Command line

```
jarvis press | release | toggle | cancel   # what the key does
jarvis ask "open firefox on workspace 2"    # a typed request
jarvis say "hello"                          # speak with Jarvis's voice
jarvis status [--json]
jarvis setup                                # create the venv, download models
jarvis spotify-login                        # connect Spotify search
```

The CLI is `~/.config/omarchy/plugins/grivera.jarvis/bin/jarvis`.

## Troubleshooting

- **"Didn't catch that" every time**: check that your microphone isn't muted.
  Jarvis says so when it is.
- **It mishears a lot**: if Jarvis warns that your mic is distorting, lower the
  input level (about 45 to 50 percent on many laptops). Correct it ("no, I said
  …") and it learns.
- **The Copilot key opens the Omarchy menu too**: add the `hl.unbind` line above.
- **Panel changes don't show after an update**: run `omarchy restart shell`.

## Files

- `~/.local/share/grivera-jarvis/`: Python environment and models
- `~/.local/state/grivera-jarvis/`: settings, history, learned data, Spotify sign-in
- `~/.config/grivera-jarvis/phrases.toml`: your phrases
- `$XDG_RUNTIME_DIR/grivera-jarvis.sock`: the CLI's socket

## License

MIT
