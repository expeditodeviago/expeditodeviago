# Gera os paineis SVG (estilo TV retro) usados no README.
# Uso: powershell -ExecutionPolicy Bypass -File scripts/build-panels.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "assets"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$fontB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root "design\VT323-Regular.ttf")))

function Save-Svg([string]$name, [int]$w, [int]$h, [string]$body, [string]$css = "") {
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="0 0 $w $h">
<defs>
  <style>
    @font-face { font-family: 'VT'; src: url(data:font/ttf;base64,$fontB64) format('truetype'); }
    text { font-family: 'VT', 'Courier New', monospace; }
    .blink { animation: blink 1s steps(1) infinite; }
    @keyframes blink { 50% { opacity: 0; } }
    .flicker { animation: flicker 4s infinite; }
    @keyframes flicker { 0%,100% { opacity: 1; } 92% { opacity: 1; } 93% { opacity: .72; } 94% { opacity: 1; } 96% { opacity: .85; } }
    $css
  </style>
  <pattern id="scan" width="4" height="4" patternUnits="userSpaceOnUse">
    <rect width="4" height="2" fill="#000" opacity=".28"/>
  </pattern>
  <radialGradient id="vig" cx="50%" cy="50%" r="70%">
    <stop offset="60%" stop-color="#000" stop-opacity="0"/>
    <stop offset="100%" stop-color="#000" stop-opacity=".75"/>
  </radialGradient>
  <linearGradient id="wood" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#8a5532"/><stop offset=".5" stop-color="#5c3620"/><stop offset="1" stop-color="#3b2112"/>
  </linearGradient>
  <linearGradient id="woodGrain" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#000" stop-opacity=".0"/><stop offset=".3" stop-color="#000" stop-opacity=".18"/>
    <stop offset=".55" stop-color="#fff" stop-opacity=".06"/><stop offset=".8" stop-color="#000" stop-opacity=".15"/><stop offset="1" stop-color="#000" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="metal" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#e6edf3"/><stop offset=".5" stop-color="#8b949e"/><stop offset="1" stop-color="#484f58"/>
  </linearGradient>
  <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity=".10"/><stop offset=".35" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <filter id="glow" x="-20%" y="-50%" width="140%" height="200%">
    <feGaussianBlur stdDeviation="2.2" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="softglow" x="-10%" y="-30%" width="120%" height="160%">
    <feGaussianBlur stdDeviation="1.2" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
$body
</svg>
"@
    [IO.File]::WriteAllText((Join-Path $out $name), $svg, (New-Object Text.UTF8Encoding($false)))
    Write-Output "ok  $name"
}

function Knob([int]$cx, [int]$cy, [int]$r, [int]$angle) {
    return @"
<g transform="translate($cx $cy)">
  <circle r="$($r + 3)" fill="#161b22"/>
  <circle r="$r" fill="url(#metal)"/>
  <circle r="$($r - 4)" fill="#30363d"/>
  <rect x="-1.5" y="-$($r - 2)" width="3" height="$($r - 4)" fill="#e6edf3" transform="rotate($angle)"/>
</g>
"@
}

# ---------------------------------------------------------------- BANNER
$ticker = "&#9733; NO AR: NEXUS DASH &#8212; A IA QUE CONVERSA COM SUAS PLANILHAS   &#9733; LIVRO DAS PALAVRAS &#8212; O GRIM&#211;RIO DO VOCABUL&#193;RIO EM INGL&#202;S   &#9733; VICO-04 CONTINUA DESCONFIADO DA C&#194;MERA   &#9733; A GRADE &#201; ATUALIZADA TODA MADRUGADA &#192;S 03:00   "
$banner = @"
<rect x="0" y="0" width="860" height="170" rx="16" fill="url(#wood)"/>
<rect x="0" y="0" width="860" height="170" rx="16" fill="url(#woodGrain)"/>
<rect x="12" y="12" width="836" height="146" rx="12" fill="#0b0f14" stroke="#30363d" stroke-width="2"/>
<g class="flicker">
  <rect x="14" y="14" width="832" height="142" rx="10" fill="#0d1117"/>
  <circle cx="48" cy="44" r="8" fill="#f85149" class="blink"/>
  <text x="64" y="52" font-size="26" fill="#f85149">AO VIVO</text>
  <text x="36" y="80" font-size="20" fill="#6e7681">CANAL 04 &#183; EXP.DEV</text>
  <text x="430" y="72" font-size="64" fill="#39d353" text-anchor="middle" filter="url(#glow)" letter-spacing="4">IAGO EXPEDITO</text>
  <text x="430" y="102" font-size="24" fill="#f0b429" text-anchor="middle" letter-spacing="3">PRODUCT ARCHITECT &amp; SOFTWARE ENGINEER</text>
  <g transform="translate(748 30)">
    <rect width="72" height="46" rx="6" fill="#010409" stroke="#30363d"/>
    <text x="36" y="34" font-size="32" fill="#39d353" text-anchor="middle" filter="url(#softglow)">04</text>
  </g>
  <g transform="translate(752 86)" fill="#39d353">
    <rect x="0"  y="12" width="8" height="6"><animate attributeName="opacity" values="1;.25;1" dur="1.6s" repeatCount="indefinite"/></rect>
    <rect x="12" y="8"  width="8" height="10"><animate attributeName="opacity" values="1;.25;1" dur="1.6s" begin=".2s" repeatCount="indefinite"/></rect>
    <rect x="24" y="4"  width="8" height="14"><animate attributeName="opacity" values="1;.25;1" dur="1.6s" begin=".4s" repeatCount="indefinite"/></rect>
    <rect x="36" y="0"  width="8" height="18"><animate attributeName="opacity" values="1;.25;1" dur="1.6s" begin=".6s" repeatCount="indefinite"/></rect>
    <text x="52" y="17" font-size="18" fill="#6e7681">SINAL</text>
  </g>
  <rect x="14" y="120" width="832" height="34" fill="#010409"/>
  <rect x="14" y="120" width="120" height="34" fill="#f0b429"/>
  <text x="74" y="144" font-size="22" fill="#010409" text-anchor="middle">PLANT&#195;O</text>
  <svg x="134" y="120" width="712" height="34">
    <g>
      <text x="0" y="24" font-size="22" fill="#e6edf3" textLength="1400" lengthAdjust="spacing">$ticker</text>
      <text x="1400" y="24" font-size="22" fill="#e6edf3" textLength="1400" lengthAdjust="spacing">$ticker</text>
      <animateTransform attributeName="transform" type="translate" from="0 0" to="-1400 0" dur="28s" repeatCount="indefinite"/>
    </g>
  </svg>
  <rect x="14" y="14" width="832" height="142" rx="10" fill="url(#scan)"/>
</g>
"@
Save-Svg "banner.svg" 860 170 $banner

# ---------------------------------------------------------------- SOBRE (monitor CRT)
$lines = @(
  @{ t = "C:\CANAL04&gt; whoami"; c = "#7ee787" },
  @{ t = "IAGO EXPEDITO  //  Exp.dev"; c = "#e6edf3" },
  @{ t = "Estudante na Unifan &#183; Product Architect &amp; Software Engineer"; c = "#8b949e" },
  @{ t = "C:\CANAL04&gt; type foco.txt"; c = "#7ee787" },
  @{ t = "[&#9632;] ARQUITETURA DE PRODUTO &#8212; sistemas escal&#225;veis guiados por objetivo de neg&#243;cio"; c = "#39d353" },
  @{ t = "[&#9632;] DADOS &amp; IA &#8212; IA generativa e estat&#237;stica a servi&#231;o da decis&#227;o"; c = "#39d353" },
  @{ t = "[&#9632;] CELERIDADE OPERACIONAL &#8212; software que entrega agilidade de verdade"; c = "#39d353" }
)
$css = ""
$txt = ""
for ($i = 0; $i -lt $lines.Count; $i++) {
    $y = 78 + $i * 27
    $d = [math]::Round($i * 0.55, 2)
    $css += ".l$i { opacity: 0; animation: type$i 14s infinite; }`n"
    $start = [math]::Round(($d / 14) * 100, 1); $s2 = $start + 0.1
    $css += "@keyframes type$i { 0%, $start% { opacity: 0; } $s2%, 93% { opacity: 1; } 96%, 100% { opacity: 0; } }`n"
    $txt += "<text class=`"l$i`" x=`"62`" y=`"$y`" font-size=`"23`" fill=`"$($lines[$i].c)`">$($lines[$i].t)</text>`n"
}
$cursorY = 78 + $lines.Count * 27
$about = @"
<rect x="0" y="0" width="860" height="300" rx="22" fill="#c9c1ad"/>
<rect x="0" y="0" width="860" height="300" rx="22" fill="url(#glass)"/>
<rect x="6" y="6" width="848" height="288" rx="18" fill="none" stroke="#e8e1cf" stroke-width="2"/>
<rect x="26" y="24" width="700" height="252" rx="26" fill="#2d2a24"/>
<rect x="38" y="36" width="676" height="228" rx="20" fill="#06110a"/>
<g class="flicker">
$txt
<text x="62" y="$cursorY" font-size="23" fill="#7ee787">C:\CANAL04&gt; <tspan class="blink">&#9608;</tspan></text>
</g>
<rect x="38" y="36" width="676" height="228" rx="20" fill="url(#scan)"/>
<rect x="38" y="36" width="676" height="228" rx="20" fill="url(#vig)"/>
<rect x="38" y="36" width="676" height="228" rx="20" fill="url(#glass)"/>
<text x="793" y="58" font-size="20" fill="#5a5446" text-anchor="middle">EXP-04</text>
<text x="793" y="76" font-size="14" fill="#7a7362" text-anchor="middle">MONITOR</text>
$(Knob 793 118 20 -40)
$(Knob 793 176 15 60)
<g fill="#8f8775">
  <rect x="760" y="214" width="66" height="4" rx="2"/><rect x="760" y="224" width="66" height="4" rx="2"/>
  <rect x="760" y="234" width="66" height="4" rx="2"/><rect x="760" y="244" width="66" height="4" rx="2"/>
</g>
<circle cx="793" cy="266" r="5" fill="#39d353" filter="url(#softglow)"/>
"@
Save-Svg "about.svg" 860 300 $about $css

# ---------------------------------------------------------------- CANAIS (projetos)
function Channel-Tv([string]$file, [string]$ch, [string]$title, [int]$titleSize, [string]$tagline, [string[]]$bullets, [string[]]$chips,
                    [string]$fg, [string]$fgDim, [string]$screenBg, [string]$accent, [string]$icon) {
    $bl = ""
    for ($i = 0; $i -lt $bullets.Count; $i++) {
        $bl += "<text x=`"52`" y=`"$(200 + $i * 26)`" font-size=`"21`" fill=`"#e6edf3`"><tspan fill=`"$fg`">&#9656;</tspan> $($bullets[$i])</text>`n"
    }
    $cx = 52; $chipsSvg = ""
    foreach ($c in $chips) {
        $w = [math]::Round($c.Length * 9.2 + 20)
        $chipsSvg += "<rect x=`"$cx`" y=`"286`" width=`"$w`" height=`"24`" rx=`"4`" fill=`"none`" stroke=`"$fgDim`"/><text x=`"$($cx + $w / 2)`" y=`"304`" font-size=`"19`" fill=`"$fg`" text-anchor=`"middle`">$c</text>`n"
        $cx += $w + 8
    }
    $body = @"
<g stroke="#8b949e" stroke-width="3" stroke-linecap="round">
  <line x1="210" y1="34" x2="140" y2="2"/><line x1="210" y1="34" x2="290" y2="4"/>
</g>
<circle cx="140" cy="3" r="3" fill="#f85149"/><circle cx="290" cy="5" r="3" fill="#f85149"/>
<rect x="180" y="26" width="60" height="14" rx="6" fill="#30363d"/>
<rect x="6" y="36" width="408" height="378" rx="24" fill="url(#wood)"/>
<rect x="6" y="36" width="408" height="378" rx="24" fill="url(#woodGrain)"/>
<rect x="22" y="52" width="376" height="280" rx="22" fill="#161b22"/>
<rect x="32" y="62" width="356" height="260" rx="26" fill="$screenBg"/>
<g class="flicker">
  <text x="52" y="94" font-size="22" fill="$fgDim">CH $ch</text>
  <circle cx="300" cy="87" r="5" fill="#f85149" class="blink"/>
  <text x="312" y="94" font-size="20" fill="#f85149">AO VIVO</text>
  <text x="52" y="140" font-size="$titleSize" fill="$fg" filter="url(#glow)" letter-spacing="2">$icon$title</text>
  <text x="52" y="166" font-size="21" fill="$accent">$tagline</text>
  <line x1="52" y1="176" x2="368" y2="176" stroke="$fgDim" stroke-dasharray="4 4"/>
  $bl
  $chipsSvg
</g>
<rect x="32" y="62" width="356" height="260" rx="26" fill="url(#scan)"/>
<rect x="32" y="62" width="356" height="260" rx="26" fill="url(#vig)"/>
<rect x="32" y="62" width="356" height="260" rx="26" fill="url(#glass)"/>
<rect x="22" y="342" width="376" height="58" rx="10" fill="#21262d"/>
<rect x="36" y="354" width="150" height="34" rx="6" fill="#010409" stroke="$fgDim"/>
<text x="111" y="378" font-size="22" fill="$fg" text-anchor="middle" filter="url(#softglow)">&#9654; ASSISTIR</text>
<g fill="#484f58">
  <rect x="204" y="358" width="70" height="3" rx="1"/><rect x="204" y="366" width="70" height="3" rx="1"/>
  <rect x="204" y="374" width="70" height="3" rx="1"/><rect x="204" y="382" width="70" height="3" rx="1"/>
</g>
$(Knob 314 371 15 -30)
$(Knob 364 371 15 45)
<rect x="60" y="414" width="40" height="8" rx="2" fill="#2b170c"/><rect x="320" y="414" width="40" height="8" rx="2" fill="#2b170c"/>
"@
    Save-Svg $file 420 424 $body
}

Channel-Tv "ch-nexus.svg" "05" "NEXUS DASH" 50 "Plataforma de an&#225;lise de dados com IA" `
    @("Planilha CSV/XLSX vira insight em segundos", "Chat com os dados: Llama-3.1 via Groq", "Gr&#225;ficos reativos + PDF, tudo em RAM") `
    @("React", "TypeScript", "FastAPI", "Pandas") "#39d353" "#238636" "#03100a" "#f0b429" ""

Channel-Tv "ch-livro.svg" "06" "LIVRO DAS PALAVRAS" 40 "Grim&#243;rio de vocabul&#225;rio em ingl&#234;s" `
    @("Repeti&#231;&#227;o espa&#231;ada (sistema Leitner)", "Minigames com voz e &#225;udio TTS", "Or&#225;culo de IA comenta seus erros") `
    @("Next.js", "React 19", "Prisma", "Turso") "#ffb000" "#9e6a03" "#140c02" "#d2a8ff" ""

# ---------------------------------------------------------------- FITAS VHS (outros projetos)
function Vhs([string]$file, [string]$label, [string]$sub, [string]$stripe) {
    $body = @"
<rect x="4" y="4" width="412" height="132" rx="10" fill="#161616" stroke="#30363d" stroke-width="2"/>
<rect x="18" y="16" width="384" height="58" rx="4" fill="#f0ead6"/>
<rect x="18" y="16" width="384" height="12" rx="2" fill="$stripe"/>
<text x="30" y="52" font-size="26" fill="#1b1f24">$label</text>
<text x="30" y="68" font-size="17" fill="#57606a">$sub</text>
<text x="390" y="26" font-size="12" fill="#fff" text-anchor="end">REPRISE &#183; SP</text>
<rect x="110" y="84" width="200" height="42" rx="6" fill="#0b0b0b"/>
<rect x="150" y="92" width="120" height="26" rx="3" fill="#2a2016" opacity=".9"/>
<g transform="translate(140 105)"><circle r="16" fill="#e6edf3"/><circle r="6" fill="#161616"/>
  <g fill="#161616"><rect x="-2" y="-14" width="4" height="7"/><rect x="-2" y="7" width="4" height="7"/><rect x="-14" y="-2" width="7" height="4"/><rect x="7" y="-2" width="7" height="4"/></g>
  <animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="3s" repeatCount="indefinite" additive="sum"/></g>
<g transform="translate(280 105)"><circle r="16" fill="#e6edf3"/><circle r="6" fill="#161616"/>
  <g fill="#161616"><rect x="-2" y="-14" width="4" height="7"/><rect x="-2" y="7" width="4" height="7"/><rect x="-14" y="-2" width="7" height="4"/><rect x="7" y="-2" width="7" height="4"/></g>
  <animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="3s" repeatCount="indefinite" additive="sum"/></g>
<g fill="#30363d"><circle cx="40" cy="110" r="6"/><circle cx="380" cy="110" r="6"/></g>
"@
    Save-Svg $file 420 140 $body
}
Vhs "vhs-lousa.svg" "LOUSA IA &#8212; AULA AO VIVO" "IA e matem&#225;tica interativas &#183; React &#183; TypeScript &#183; XYFlow" "#1f6feb"
Vhs "vhs-dashfacil.svg" "DASHF&#193;CIL IA ULTRA" "BI 100% no navegador: planilha vira gr&#225;fico + an&#225;lise com IA" "#da3633"

# ---------------------------------------------------------------- GUIA DE PROGRAMACAO (stack)
$rows = @(
  @("06:00", "LINGUAGENS", "TypeScript &#183; Python &#183; JavaScript &#183; Java &#183; SQL"),
  @("09:00", "FRONT-END", "React 19 &#183; Next.js &#183; Vite &#183; Tailwind &#183; Framer Motion &#183; Recharts"),
  @("13:00", "BACK-END &amp; DADOS", "FastAPI &#183; Node.js &#183; Pandas &#183; NumPy &#183; Prisma &#183; PostgreSQL &#183; Turso"),
  @("19:00", "IA &amp; INTEGRA&#199;&#213;ES", "Llama-3.1 &#183; Groq &#183; OpenAI SDK &#183; Web Speech API &#183; TTS"),
  @("22:00", "ARQUITETURA", "Product Architecture &#183; REST APIs &#183; Git &#183; Vercel"),
  @("03:00", "MADRUGAD&#195;O", "Vico-04 atualiza a grade de contribui&#231;&#245;es (reprise di&#225;ria)")
)
$rowSvg = ""
for ($i = 0; $i -lt $rows.Count; $i++) {
    $y = 92 + $i * 40
    $fill = if ($i % 2 -eq 0) { "#0f1620" } else { "#0b1018" }
    $rowSvg += "<rect x=`"24`" y=`"$y`" width=`"812`" height=`"38`" fill=`"$fill`"/>`n"
    $rowSvg += "<text x=`"44`" y=`"$($y + 27)`" font-size=`"26`" fill=`"#f0b429`">$($rows[$i][0])</text>`n"
    $rowSvg += "<text x=`"128`" y=`"$($y + 27)`" font-size=`"24`" fill=`"#39d353`">$($rows[$i][1])</text>`n"
    $rowSvg += "<text x=`"350`" y=`"$($y + 27)`" font-size=`"21`" fill=`"#c9d1d9`">$($rows[$i][2])</text>`n"
}
$hl = ""
for ($i = 0; $i -lt $rows.Count; $i++) { $hl += "$(92 + $i * 40);" }
$hl += "92"
$guide = @"
<rect width="860" height="356" rx="16" fill="#010409" stroke="#30363d" stroke-width="2"/>
<rect x="24" y="22" width="812" height="56" rx="8" fill="#1f2a6e"/>
<rect x="24" y="22" width="812" height="56" rx="8" fill="url(#scan)"/>
<text x="44" y="60" font-size="34" fill="#f0f6fc" letter-spacing="3">GUIA DE PROGRAMA&#199;&#195;O</text>
<text x="816" y="60" font-size="24" fill="#f0b429" text-anchor="end">CANAL 04 &#183; STACK</text>
$rowSvg
<rect x="24" y="92" width="6" height="38" fill="#f85149">
  <animate attributeName="y" values="$hl" dur="9s" calcMode="discrete" repeatCount="indefinite"/>
</rect>
<rect x="24" y="22" width="812" height="312" fill="url(#scan)" opacity=".5"/>
"@
Save-Svg "guide.svg" 860 356 $guide

# ---------------------------------------------------------------- BOTOES (controle remoto)
function Button([string]$file, [string]$label, [string]$color) {
    $body = @"
<rect x="2" y="2" width="276" height="58" rx="29" fill="#21262d" stroke="#484f58" stroke-width="2"/>
<rect x="8" y="8" width="264" height="46" rx="23" fill="#161b22"/>
<circle cx="38" cy="31" r="14" fill="$color" filter="url(#softglow)"/>
<circle cx="34" cy="27" r="4" fill="#fff" opacity=".5"/>
<text x="160" y="40" font-size="28" fill="#e6edf3" text-anchor="middle" letter-spacing="3">$label</text>
"@
    Save-Svg $file 280 62 $body
}
Button "btn-linkedin.svg" "LINKEDIN" "#0a66c2"
Button "btn-instagram.svg" "INSTAGRAM" "#e4405f"
Button "btn-github.svg" "SEGUIR" "#39d353"

# ---------------------------------------------------------------- CABECALHOS DE SECAO
function Header([string]$file, [string]$left, [string]$right, [string]$color) {
    $body = @"
<rect y="22" width="860" height="2" fill="#30363d"/>
<rect x="0" y="6" width="$([math]::Round($left.Length * 12 + 40))" height="34" rx="4" fill="$color"/>
<text x="16" y="31" font-size="26" fill="#010409" letter-spacing="2">$left</text>
<rect x="$([math]::Round(860 - $right.Length * 10.5 - 30))" y="10" width="$([math]::Round($right.Length * 10.5 + 30))" height="26" rx="4" fill="#0d1117" stroke="#30363d"/>
<text x="845" y="30" font-size="21" fill="#8b949e" text-anchor="end">$right</text>
"@
    Save-Svg $file 860 46 $body
}
Header "h-cartaz.svg" "EM CARTAZ" "CANAIS 05 E 06" "#39d353"
Header "h-reprises.svg" "REPRISES" "FITAS VHS DO ARQUIVO" "#f0b429"
Header "h-contato.svg" "SINTONIZE" "CONTATO" "#d2a8ff"

# ---------------------------------------------------------------- RODAPE (barras de cor)
$cols = "#c0c0c0", "#c0c000", "#00c0c0", "#00c000", "#c000c0", "#c00000", "#0000c0"
$bars = ""
for ($i = 0; $i -lt 7; $i++) { $bars += "<rect x=`"$([math]::Round($i * 860 / 7))`" y=`"0`" width=`"$([math]::Ceiling(860 / 7) + 1)`" height=`"70`" fill=`"$($cols[$i])`"/>" }
$footer = @"
<clipPath id="r"><rect width="860" height="150" rx="14"/></clipPath>
<g clip-path="url(#r)">
$bars
<g>$(for ($i = 0; $i -lt 7; $i++) { "<rect x=`"$([math]::Round($i * 860 / 7))`" y=`"70`" width=`"$([math]::Ceiling(860 / 7) + 1)`" height=`"12`" fill=`"$($cols[6 - $i])`"/>" })</g>
<rect y="82" width="860" height="68" fill="#010409"/>
<text x="430" y="112" font-size="28" fill="#f0f6fc" text-anchor="middle" letter-spacing="3">FIM DA TRANSMISS&#195;O</text>
<text x="430" y="138" font-size="20" fill="#8b949e" text-anchor="middle">Se voc&#234; chegou at&#233; aqui, o Vico-04 j&#225; sabe que voc&#234; estava olhando.</text>
<rect width="860" height="150" fill="url(#scan)"/>
</g>
"@
Save-Svg "footer.svg" 860 150 $footer
