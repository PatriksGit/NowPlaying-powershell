# NowPlaying-powershell

A RuneEmpire kliens (`rune` Fabric mod) **Most szól** HUD widgetjének hídja a Windows médiavezérlőjéhez.
English below.

## Mit csinál?

A Minecraft (Java) nem látja, mi szól éppen a gépen. A Windows ezt a „médiamunkamenetekben” (SMTC) tartja számon,
ugyanott, ahonnan a hangerő-felugró ablak is mutatja a dal címét. Ez a PowerShell-szkript ezt olvassa ki, és átadja a
játéknak.

- **Mit olvas:** csak az éppen szóló médiamunkamenetet: a címet, az előadót (videónál a csatornát), a lejátszás
  állapotát (megy vagy szünetel), a pozíciót és a hosszt, valamint a borítóképet.
- **Mit nem csinál:** nem használ hálózatot, nem ír a lemezre, nem olvas más fájlt, és nem indít más programot.
  Amit kiolvas, azt csak a saját szabványos kimenetére írja, amit a játék olvas. A szerverre semmi nem jut el.
- **Mikor fut:** csak akkor, ha a játékos a HUD menüben bekapcsolja a **Most szól** widgetet, és csak Windowson.
  Kikapcsoláskor a játék leállítja.
- **Mikor áll le magától:** másodpercenként ellenőrzi, hogy fut-e még a játék, és ha nem (akár összeomlás után),
  kilép.

## Hogyan indítja a játék?

A mod a jarban lévő példányt a játékmappába másolja (`.runeempire\game\rune\now-playing.ps1`), és így indítja:

```
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass
    -File <játékmappa>\rune\now-playing.ps1 -ParentPid <a játék folyamatazonosítója>
```

Az `-ExecutionPolicy Bypass` csak erre az egy futtatásra szól, és azért kell, mert a Windows alapból nem futtat
aláíratlan szkriptet. A rendszer beállításain nem változtat.

## Kimenet

Soronként egy JSON objektum, csak ha valami változott:

```
{"type":"track","title":"...","artist":"...","playing":true,"positionMs":42729,"endMs":144070,"updatedMs":1793910035550}
{"type":"cover","png":"<base64 PNG: a borító középső négyzete, legfeljebb 256x256>"}
{"type":"none"}
```

## Ellenőrzés: ugyanez fut nálad?

A játékban futó példány ugyanaz, mint ez a fájl. PowerShellben ellenőrizheted:

```powershell
Get-FileHash "$env:APPDATA\.runeempire\game\rune\now-playing.ps1"
Get-FileHash .\now-playing.ps1
```

A két `Hash` értéknek egyeznie kell. A fájl a mod jarjában is olvasható (`rune/now-playing.ps1`).

---

## English

The bridge between Windows' media sessions (SMTC) and the **Most szól** ("Now playing") HUD widget of the RuneEmpire
client mod `rune`. Minecraft (Java) cannot see what is playing on the PC; this PowerShell script reads it and hands it
to the game.

- **Reads:** only the current media session: title, artist (the channel for a video), playback state, position,
  length and the cover image.
- **Does not:** use the network, write to disk, read other files or start other programs. It writes what it reads
  only to its own standard output, which the game reads. Nothing reaches the server.
- **Runs:** only while the player has enabled the widget in the HUD menu, on Windows. Disabling it stops the script.
- **Stops by itself:** it checks once a second that the game is still running and exits when it is not (also after a
  crash).

The mod copies the copy in its jar to `.runeempire\game\rune\now-playing.ps1` and starts it with Windows PowerShell 5.1
by its full path: `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File <script> -ParentPid <game
pid>`. `-ExecutionPolicy Bypass` applies to this one run only (Windows does not run unsigned scripts by default) and
changes no system setting.

Output: one JSON object per line, only when something changed (`track`, `cover`, `none`; see above).

To check that the game runs this exact file, compare `Get-FileHash` of
`%APPDATA%\.runeempire\game\rune\now-playing.ps1` with this repository's `now-playing.ps1`.
