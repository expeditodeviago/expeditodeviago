# Gera o console de estudio retro unificado (console-deck.svg) e botoes de sintonia,
# convertendo titulos VT323 em <path> vetoriais (100% compativel com o CSP do GitHub!).
param(
    [string]$User = "expeditodeviago"
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "assets"
$fontPath = Join-Path $root "design\VT323-Regular.ttf"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# Limpar SVGs antigos poluídos
Get-ChildItem -Path $out -Filter "*.svg" -ErrorAction SilentlyContinue | Remove-Item -Force

# Buscar telemetria real do GitHub (repositorios e contribuicoes)
$pubRepos = 14
$totalContribs = 63
try {
    $u = Invoke-RestMethod "https://api.github.com/users/$User"
    if ($u.public_repos) { $pubRepos = [int]$u.public_repos }
    $chtml = (Invoke-WebRequest -UseBasicParsing "https://github.com/users/$User/contributions").Content
    $tm = [regex]::Match($chtml, '([\d,\.]+)\s+contributions?\s+in the last year')
    if ($tm.Success) { $totalContribs = [int]($tm.Groups[1].Value -replace '[,\.]', '') }
} catch {}

$pathHelper = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Globalization;
using System.Text;

public class VtPathRenderer
{
    static PrivateFontCollection Pfc;
    public static void Init(string fontFile)
    {
        Pfc = new PrivateFontCollection();
        Pfc.AddFontFile(fontFile);
    }

    public static string ToSvgPath(string text, float emSize, float x, float y, bool center)
    {
        using (GraphicsPath gp = new GraphicsPath())
        {
            StringFormat sf = StringFormat.GenericTypographic;
            gp.AddString(text, Pfc.Families[0], 0, emSize, new PointF(0, 0), sf);
            RectangleF bounds = gp.GetBounds();
            float dx = center ? (x - (bounds.Left + bounds.Width / 2f)) : (x - bounds.Left);
            float dy = y - bounds.Top;
            Matrix m = new Matrix();
            m.Translate(dx, dy);
            gp.Transform(m);

            if (gp.PointCount == 0) return "";
            PointF[] pts = gp.PathPoints;
            byte[] types = gp.PathTypes;
            StringBuilder sb = new StringBuilder();
            CultureInfo inv = CultureInfo.InvariantCulture;

            for (int i = 0; i < pts.Length; i++)
            {
                byte t = (byte)(types[i] & 0x07);
                if (t == 0)
                    sb.AppendFormat(inv, "M{0:0.#} {1:0.#}", pts[i].X, pts[i].Y);
                else if (t == 1)
                    sb.AppendFormat(inv, "L{0:0.#} {1:0.#}", pts[i].X, pts[i].Y);
                else if (t == 3 && i + 2 < pts.Length)
                {
                    sb.AppendFormat(inv, "C{0:0.#} {1:0.#} {2:0.#} {3:0.#} {4:0.#} {5:0.#}",
                        pts[i].X, pts[i].Y, pts[i+1].X, pts[i+1].Y, pts[i+2].X, pts[i+2].Y);
                    i += 2;
                }
                if ((types[i] & 0x80) != 0) sb.Append("Z");
            }
            return sb.ToString();
        }
    }
}
'@

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $pathHelper -ReferencedAssemblies System.Drawing
[VtPathRenderer]::Init($fontPath)

function P([string]$txt, [float]$size, [float]$x, [float]$y, [string]$fill, [bool]$center = $false, [string]$extra = "") {
    $d = [VtPathRenderer]::ToSvgPath($txt, $size, $x, $y, $center)
    return "<path d=`"$d`" fill=`"$fill`" $extra/>"
}

# =====================================================================
# 1. CONSOLE DE ESTUDIO UNIFICADO (assets/console-deck.svg) — 860 x 350
# =====================================================================
$consoleSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="860" height="352" viewBox="0 0 860 352">
  <defs>
    <style>
      .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace; }
      .pulse { animation: pulse 1.6s ease-in-out infinite; }
      @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.25; } }
      .scanmove { animation: scan 8s linear infinite; }
      @keyframes scan { 0% { transform: translateY(0px); } 100% { transform: translateY(200px); } }
    </style>
    <pattern id="crtscan" width="4" height="4" patternUnits="userSpaceOnUse">
      <rect width="4" height="1.5" fill="#000" opacity="0.32"/>
    </pattern>
    <linearGradient id="rackBg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1b212c"/>
      <stop offset="100%" stop-color="#11161e"/>
    </linearGradient>
    <linearGradient id="woodSide" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#7a492a"/>
      <stop offset="55%" stop-color="#5c351d"/>
      <stop offset="100%" stop-color="#3b2010"/>
    </linearGradient>
    <linearGradient id="greenScreen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#071510"/>
      <stop offset="100%" stop-color="#040c09"/>
    </linearGradient>
    <linearGradient id="amberScreen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#161105"/>
      <stop offset="100%" stop-color="#0c0903"/>
    </linearGradient>
  </defs>

  <!-- Moldura Externa do Rack Sony PVM + Acabamento Lateral em Nogueira -->
  <rect x="0" y="0" width="860" height="352" rx="14" fill="url(#rackBg)" stroke="#30363d" stroke-width="1.5"/>
  <rect x="0" y="0" width="14" height="352" rx="6" fill="url(#woodSide)"/>
  <rect x="846" y="0" width="14" height="352" rx="6" fill="url(#woodSide)"/>

  <!-- Parafusos de Rack de Estudio -->
  <g fill="#0d1117" stroke="#484f58" stroke-width="1">
    <circle cx="26" cy="20" r="4"/><circle cx="834" cy="20" r="4"/>
    <circle cx="26" cy="332" r="4"/><circle cx="834" cy="332" r="4"/>
  </g>

  <!-- BARRA SUPERIOR: Identificacao da Emissora -->
  <rect x="38" y="14" width="784" height="64" rx="8" fill="#0b0f15" stroke="#262e3b"/>
  <circle cx="62" cy="34" r="5" fill="#ff5f56" class="pulse"/>
  $(P "NO AR // CANAL 04" 18 74 25 "#ff5f56" $false)
  <text x="56" y="63" class="mono" font-size="11.5" fill="#8b949e">SINAL DIRETO · ESTÚDIO EXP.DEV</text>

  $(P "IAGO EXPEDITO" 44 430 18 "#39d353" $true)
  <text x="430" y="68" class="mono" font-size="11.5" font-weight="600" fill="#f0b429" text-anchor="middle" letter-spacing="1.5">PRODUCT ARCHITECT &amp; SOFTWARE ENGINEER</text>

  <rect x="692" y="24" width="116" height="44" rx="6" fill="#111720" stroke="#263140"/>
  $(P "CH-04" 26 750 28 "#7ee787" $true)
  <text x="750" y="61" class="mono" font-size="10" fill="#6e7681" text-anchor="middle">60Hz · NTSC</text>

  <!-- TELA CRT ESQUERDA (Fosforo Verde): Engenharia & Direcao -->
  <rect x="38" y="90" width="384" height="206" rx="10" fill="#090d12" stroke="#30363d" stroke-width="1.5"/>
  <rect x="46" y="98" width="368" height="190" rx="7" fill="url(#greenScreen)" stroke="#1b472d" stroke-width="1"/>

  $(P "MONITOR A // PERFIL TÉCNICO" 20 62 108 "#39d353" $false)
  <line x1="62" y1="132" x2="398" y2="132" stroke="#163b25" stroke-width="1"/>

  <text x="62" y="153" class="mono" font-size="12" fill="#e6edf3" font-weight="700">▸ Arquitetura de Produto</text>
  <text x="76" y="170" class="mono" font-size="11" fill="#8b949e">Sistemas escaláveis orientados a negócio real.</text>

  <text x="62" y="198" class="mono" font-size="12" fill="#e6edf3" font-weight="700">▸ Inteligência Artificial &amp; Dados</text>
  <text x="76" y="215" class="mono" font-size="11" fill="#8b949e">IA generativa, análise estatística e automação.</text>

  <text x="62" y="243" class="mono" font-size="12" fill="#e6edf3" font-weight="700">▸ Celeridade Operacional</text>
  <text x="76" y="260" class="mono" font-size="11" fill="#8b949e">Código limpo que transforma visão em entrega.</text>

  <rect x="46" y="98" width="368" height="190" rx="7" fill="url(#crtscan)"/>

  <!-- TELA CRT DIREITA (Fosforo Ambar): Stack & Frequencias -->
  <rect x="438" y="90" width="384" height="206" rx="10" fill="#090d12" stroke="#30363d" stroke-width="1.5"/>
  <rect x="446" y="98" width="368" height="190" rx="7" fill="url(#amberScreen)" stroke="#523b10" stroke-width="1"/>

  $(P "MONITOR B // STACK SINTONIZADA" 20 462 108 "#f0b429" $false)
  <line x1="462" y1="132" x2="798" y2="132" stroke="#3d2c0b" stroke-width="1"/>

  <text x="462" y="153" class="mono" font-size="11" fill="#f0b429" font-weight="700">CH-01 CORE</text>
  <text x="556" y="153" class="mono" font-size="11.5" fill="#e6edf3">TypeScript · Python · Java · SQL</text>

  <text x="462" y="183" class="mono" font-size="11" fill="#f0b429" font-weight="700">CH-02 UI</text>
  <text x="556" y="183" class="mono" font-size="11.5" fill="#e6edf3">React · Next.js · Tailwind · Motion</text>

  <text x="462" y="213" class="mono" font-size="11" fill="#f0b429" font-weight="700">CH-03 DATA</text>
  <text x="556" y="213" class="mono" font-size="11.5" fill="#e6edf3">FastAPI · Node · Pandas · Prisma</text>

  <text x="462" y="243" class="mono" font-size="11" fill="#f0b429" font-weight="700">CH-04 AI</text>
  <text x="556" y="243" class="mono" font-size="11.5" fill="#e6edf3">LLMs · Groq · OpenAI · Cloud/Edge</text>

  <text x="462" y="271" class="mono" font-size="10.5" fill="#9e7724">▸ Sinal estável · Unifan Software Engineering</text>

  <rect x="446" y="98" width="368" height="190" rx="7" fill="url(#crtscan)"/>

  <!-- BARRA INFERIOR DE TELEMETRIA DO RACK -->
  <rect x="38" y="306" width="784" height="32" rx="6" fill="#0b0f15" stroke="#262e3b"/>
  <circle cx="56" cy="322" r="4" fill="#39d353"/>
  <text x="68" y="326" class="mono" font-size="11.5" fill="#c9d1d9">CATÁLOGO NO AR: <tspan fill="#39d353" font-weight="700">$pubRepos REPOSITÓRIOS PÚBLICOS</tspan></text>
  <text x="430" y="326" class="mono" font-size="11.5" fill="#8b949e" text-anchor="middle">|</text>
  <text x="452" y="326" class="mono" font-size="11.5" fill="#c9d1d9">AUDIÊNCIA ANUAL: <tspan fill="#f0b429" font-weight="700">$totalContribs COMMITS</tspan></text>
  <text x="806" y="326" class="mono" font-size="11" fill="#58a6ff" text-anchor="end">EXPLORE ABAIXO ▼</text>
</svg>
"@

[IO.File]::WriteAllText((Join-Path $out "console-deck.svg"), $consoleSvg, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  console-deck.svg"

# =====================================================================
# 2. BOTOES TATEIS DE ESTUDIO (3 switches lado a lado — 276 x 52)
# =====================================================================
function Save-Switch([string]$file, [string]$code, [string]$label, [string]$led) {
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="276" height="52" viewBox="0 0 276 52">
  <rect x="1" y="1" width="274" height="50" rx="8" fill="#161b22" stroke="#30363d" stroke-width="1.5"/>
  <rect x="6" y="6" width="264" height="40" rx="5" fill="#0d1117" stroke="#21262d" stroke-width="1"/>
  <rect x="16" y="14" width="38" height="24" rx="4" fill="#161c26" stroke="#30363d"/>
  $(P $code 19 35 17 $led $true)
  <circle cx="68" cy="26" r="4" fill="$led"/>
  $(P $label 24 166 14 "#e6edf3" $true)
</svg>
"@
    [IO.File]::WriteAllText((Join-Path $out $file), $svg, (New-Object Text.UTF8Encoding($false)))
    Write-Output "ok  $file"
}

Save-Switch "sw-repos.svg"    "CH1" "TODOS OS PROJETOS" "#39d353"
Save-Switch "sw-linkedin.svg" "CH2" "LINKEDIN"          "#58a6ff"
Save-Switch "sw-insta.svg"    "CH3" "INSTAGRAM"         "#f0b429"
