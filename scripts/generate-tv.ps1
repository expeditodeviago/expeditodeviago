# Gera assets/tv-truman-grid.gif usando as contribuicoes REAIS do GitHub
# Com 5 cenas completas de interacao do Vico-04 com os quadradinhos verdes.
param(
    [string]$User = "expeditodeviago",
    [string]$OutPath = "",
    [string]$PreviewDir = ""
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutPath) { $OutPath = Join-Path $root "assets\tv-truman-grid.gif" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
if ($PreviewDir) { New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null }

# ---------- 1. Contribuicoes reais (pagina publica do calendario) ----------
$html = (Invoke-WebRequest -UseBasicParsing "https://github.com/users/$User/contributions").Content
$cells = @{}
foreach ($m in [regex]::Matches($html, 'data-date="(\d{4}-\d{2}-\d{2})"[^>]*?data-level="(\d)"')) {
    $cells[$m.Groups[1].Value] = [int]$m.Groups[2].Value
}
if ($cells.Count -eq 0) { throw "Nao consegui ler o calendario de contribuicoes." }
$totalMatch = [regex]::Match($html, '([\d,\.]+)\s+contributions?\s+in the last year')
$total = if ($totalMatch.Success) { [int]($totalMatch.Groups[1].Value -replace '[,\.]', '') } else { 0 }

$WEEKS = 21
$lastDate = [datetime]::ParseExact(($cells.Keys | Sort-Object | Select-Object -Last 1), "yyyy-MM-dd", $null)
$lastWeekStart = $lastDate.AddDays(-[int]$lastDate.DayOfWeek)
$firstWeekStart = $lastWeekStart.AddDays(-7 * ($WEEKS - 1))
$levels = New-Object int[] ($WEEKS * 7)
for ($w = 0; $w -lt $WEEKS; $w++) {
    for ($d = 0; $d -lt 7; $d++) {
        $key = $firstWeekStart.AddDays($w * 7 + $d).ToString("yyyy-MM-dd")
        $levels[$w * 7 + $d] = if ($cells.ContainsKey($key)) { $cells[$key] } else { -1 }
    }
}
Write-Output "Contribuicoes no ano: $total | janela: $($firstWeekStart.ToString('yyyy-MM-dd')) -> $($lastDate.ToString('yyyy-MM-dd'))"

# ---------- 2. Renderizador pixel art (5 cenas de interacao) ----------
$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.IO;
using System.Windows.Media.Imaging;

public class PixelTvRich
{
    const int W = 220, H = 128, SCALE = 3, WEEKS = 21;
    static Color C(string h) { return ColorTranslator.FromHtml(h); }

    static readonly Color BgDark = C("#0d1117"), BgStars = C("#161b22");
    static readonly Color GhEmpty = C("#161b22"), GhG1 = C("#0e4429"), GhG2 = C("#006d32"), GhG3 = C("#26a641"), GhG4 = C("#39d353"), GhHi = C("#7ee787");
    static readonly Color WoodDark = C("#3b2112"), WoodMid = C("#5c3620"), WoodLight = C("#7a492c");
    static readonly Color BezelDark = C("#1c2128"), BezelMid = C("#2d333b"), BezelLight = C("#444c56"), PanelBg = C("#22272e");
    static readonly Color MetalLight = C("#adbac7"), MetalDark = C("#636e7b");
    static readonly Color SkyTop = C("#090d16"), SkyBot = C("#111827"), WireBlue = C("#1f6feb");
    static readonly Color Cyan = C("#58a6ff"), Amber = C("#f0883e"), Red = C("#f85149"), Yellow = C("#f1e05a"), White = C("#f0f6fc"), Purple = C("#d2a8ff");
    static readonly Color CoatDark = C("#161922"), CoatMid = C("#262b38"), CoatTrim = C("#3b4354");
    static readonly Color BotHead = C("#373e47"), BotHeadLight = C("#545d68"), VisorBg = C("#0a0c10");

    static Dictionary<char, string[]> Font = new Dictionary<char, string[]>();
    static void A(char c, params string[] r) { Font[c] = r; }
    static PixelTvRich()
    {
        A('A',"010","101","111","101","101"); A('B',"110","101","110","101","110"); A('C',"011","100","100","100","011");
        A('D',"110","101","101","101","110"); A('E',"111","100","110","100","111"); A('F',"111","100","110","100","100");
        A('G',"011","100","101","101","011"); A('H',"101","101","111","101","101"); A('I',"111","010","010","010","111");
        A('J',"001","001","001","101","010"); A('K',"101","101","110","101","101"); A('L',"100","100","100","100","111");
        A('M',"10001","11011","10101","10001","10001"); A('N',"1001","1101","1011","1001","1001"); A('O',"010","101","101","101","010");
        A('P',"110","101","110","100","100"); A('Q',"010","101","101","111","001"); A('R',"110","101","110","101","101");
        A('S',"011","100","010","001","110"); A('T',"111","010","010","010","010"); A('U',"101","101","101","101","111");
        A('V',"101","101","101","101","010"); A('W',"10001","10001","10101","11011","10001"); A('X',"101","101","010","101","101");
        A('Y',"101","101","010","010","010"); A('Z',"111","001","010","100","111");
        A('0',"111","101","101","101","111"); A('1',"010","110","010","010","111"); A('2',"110","001","010","100","111");
        A('3',"110","001","010","001","110"); A('4',"101","101","111","001","001"); A('5',"111","100","110","001","110");
        A('6',"011","100","111","101","111"); A('7',"111","001","010","010","010"); A('8',"111","101","111","101","111");
        A('9',"111","101","111","001","110"); A(':',"0","1","0","1","0"); A('.',"0","0","0","0","1"); A(',',"0","0","0","1","1");
        A('+',"000","010","111","010","000");
        A('!',"1","1","1","0","1"); A('?',"110","001","010","000","010"); A('-',"000","000","111","000","000");
        A('/',"001","001","010","100","100"); A('$',"00100","00100","10101","01110","00100"); A(' ',"00","00","00","00","00");
    }

    static void Px(Bitmap b, int x, int y, Color c) { if (x >= 0 && x < W && y >= 0 && y < H) b.SetPixel(x, y, c); }
    static void Fill(Bitmap b, int x, int y, int w, int h, Color c) { for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) Px(b, x + i, y + j, c); }
    static void Rect(Bitmap b, int x, int y, int w, int h, Color c)
    {
        for (int i = 0; i < w; i++) { Px(b, x + i, y, c); Px(b, x + i, y + h - 1, c); }
        for (int j = 0; j < h; j++) { Px(b, x, y + j, c); Px(b, x + w - 1, y + j, c); }
    }
    static int Measure(string t)
    {
        int w = 0;
        foreach (char r in t.ToUpperInvariant()) { char ch = Font.ContainsKey(r) ? r : ' '; w += Font[ch][0].Length + 1; }
        return w > 0 ? w - 1 : 0;
    }
    static void Text(Bitmap b, string t, int x, int y, Color c)
    {
        int cx = x;
        foreach (char r in t.ToUpperInvariant())
        {
            char ch = Font.ContainsKey(r) ? r : ' ';
            string[] rows = Font[ch];
            for (int j = 0; j < 5; j++) for (int i = 0; i < rows[j].Length; i++) if (rows[j][i] == '1') Px(b, cx + i, y + j, c);
            cx += rows[0].Length + 1;
        }
    }
    static void TextC(Bitmap b, string t, int cx, int y, Color c) { Text(b, t, cx - Measure(t) / 2, y, c); }

    static Color Lvl(int l)
    {
        switch (l) { case 1: return GhG1; case 2: return GhG2; case 3: return GhG3; case 4: return GhG4; default: return GhEmpty; }
    }

    static int[] Levels;
    static int Total;
    static int TargetA, TargetB, TargetC;

    const int TILE = 5, PITCH = 6;
    static int GridX(int sx) { return sx + (130 - (WEEKS * PITCH - 1)) / 2; }
    static int GridY(int sy) { return sy + 33; }
    static void CellCenter(int idx, int sx, int sy, out int cx, out int cy)
    {
        int w = idx / 7, d = idx % 7;
        cx = GridX(sx) + w * PITCH + TILE / 2;
        cy = GridY(sy) + d * PITCH + TILE / 2;
    }

    static void ChooseTargets()
    {
        List<int> active = new List<int>();
        for (int i = 0; i < Levels.Length; i++) if (Levels[i] > 0) active.Add(i);

        if (active.Count >= 3)
        {
            TargetA = active[active.Count / 4];
            TargetB = active[active.Count / 2];
            TargetC = active[active.Count - 1];
        }
        else
        {
            TargetA = 4 * 7 + 3;
            TargetB = 10 * 7 + 2;
            TargetC = 16 * 7 + 4;
        }
    }

    static void DrawTv(Bitmap b, int f, int ox, int oy, bool glitch, bool alert, string chText)
    {
        Fill(b, 0, 0, W, H, BgDark);
        int[,] stars = { {8,20}, {14,88}, {208,30}, {212,95}, {10,112}, {204,14} };
        for (int i = 0; i < stars.GetLength(0); i++) Px(b, stars[i,0], stars[i,1], ((f + i * 3) % 8 < 4) ? GhG1 : BgStars);
        Fill(b, 28, 121, 164, 4, C("#06080b"));

        int ax = 95 + ox, ay = 12 + oy;
        Fill(b, ax - 8, ay - 2, 16, 3, BezelMid);
        for (int i = 0; i < 10; i++)
        {
            Px(b, ax - 4 - i * 2, ay - 2 - i, MetalDark); Px(b, ax - 3 - i * 2, ay - 2 - i, MetalLight);
            Px(b, ax + 4 + i * 2, ay - 2 - i, MetalDark); Px(b, ax + 3 + i * 2, ay - 2 - i, MetalLight);
        }
        Fill(b, ax - 24, ay - 12, 2, 2, Red); Fill(b, ax + 22, ay - 12, 2, 2, Red);
        if (glitch) for (int x = ax - 18; x <= ax + 18; x += 3) Px(b, x, ay - 10 + ((x + f) % 3 - 1), Cyan);

        Fill(b, 38 + ox, 118 + oy, 12, 4, WoodDark); Fill(b, 170 + ox, 118 + oy, 12, 4, WoodDark);
        int tx = 22 + ox, ty = 12 + oy, tw = 176, th = 106;
        Fill(b, tx + 2, ty, tw - 4, th, WoodMid); Fill(b, tx, ty + 2, tw, th - 4, WoodMid);
        for (int y = ty + 4; y < ty + th - 4; y += 6) { Fill(b, tx + 2, y, tw - 4, 1, WoodDark); Fill(b, tx + 2, y + 2, tw - 4, 1, WoodLight); }
        Fill(b, tx + 3, ty + 1, tw - 6, 2, WoodLight); Fill(b, tx + 3, ty + th - 3, tw - 6, 2, WoodDark);
        Fill(b, tx + 6, ty + 6, tw - 12, th - 12, BezelDark); Rect(b, tx + 6, ty + 6, tw - 12, th - 12, BezelLight);

        int px = tx + 140, py = ty + 8;
        Fill(b, px, py, 28, th - 16, PanelBg); Rect(b, px, py, 28, th - 16, BezelMid);
        Fill(b, px + 4, py + 5, 20, 11, VisorBg); Rect(b, px + 4, py + 5, 20, 11, BezelLight);
        Text(b, glitch ? "ER" : chText, px + 9, py + 8, glitch ? Red : GhG4);

        // Knobs rotate slightly by scene
        Fill(b, px + 9, py + 21, 10, 14, MetalDark); Fill(b, px + 8, py + 22, 12, 12, MetalLight);
        if ((f / 18) % 2 == 0) Fill(b, px + 13, py + 23, 2, 10, BezelDark);
        else Fill(b, px + 9, py + 27, 10, 2, BezelDark);

        Fill(b, px + 8, py + 40, 12, 12, MetalDark); Fill(b, px + 9, py + 41, 10, 10, MetalLight);
        Fill(b, px + 10, py + 45, 8, 2, BezelDark);

        for (int sy = py + 58; sy < py + 76; sy += 3) Fill(b, px + 5, sy, 18, 1, VisorBg);
        Fill(b, px + 12, py + 80, 4, 4, alert ? ((f % 2 == 0) ? Red : Amber) : GhG4);
    }

    // Pose: 0=normal/walk, 1=blade slash, 2=pushing block, 3=sitting with coffee
    static void Vico(Bitmap b, int x, int y, int dir, int step, int pose, bool mug, bool sus, bool swordOut)
    {
        int py = y + ((step % 2 == 1) ? -1 : 0);
        if (pose == 3) py = y + 3; // sitting lower on a green cube!

        Fill(b, x + 2, y + 20, 12, 2, C("#090c10"));

        // Katana-wrench on back if not drawn in hand
        if (!swordOut)
        {
            Px(b, x + 1, py + 1, Cyan); Px(b, x + 2, py + 2, MetalLight); Px(b, x + 3, py + 3, MetalDark); Px(b, x + 4, py + 4, MetalLight);
            Px(b, x + 13, py + 14, MetalDark); Px(b, x + 14, py + 15, Cyan);
        }

        if (pose == 3)
        {
            // Sitting legs swinging!
            int swing = (step % 2 == 0) ? 1 : 0;
            Fill(b, x + 4, y + 17 + swing, 3, 3, VisorBg);
            Fill(b, x + 9, y + 18 - swing, 3, 3, VisorBg);
        }
        else
        {
            Fill(b, x + 4, y + 18 + ((step == 1) ? -1 : 0), 3, 3, VisorBg);
            Fill(b, x + 9, y + 18 + ((step == 3) ? -1 : 0), 3, 3, VisorBg);
        }

        Fill(b, x + 3, py + 9, 10, 9, CoatDark); Fill(b, x + 2, py + 14, 12, 4, CoatDark); Fill(b, x + 4, py + 9, 8, 7, CoatMid);
        Fill(b, x + 3, py + 8, 10, 2, CoatTrim); Fill(b, x + 7, py + 10, 2, 7, VisorBg);
        Fill(b, x + 3, py + 1, 10, 7, BotHead); Fill(b, x + 4, py, 8, 1, BotHeadLight);
        Px(b, x + 2, py + 3, MetalLight); Px(b, x + 13, py + 3, MetalLight);
        Fill(b, x + 4, py + 3, 8, 3, VisorBg);

        Color eye = sus ? Amber : Cyan;
        if (dir == 1) { Fill(b, x + 8, py + 4, 3, 2, eye); Px(b, x + 9, py + 4, White); }
        else if (dir == -1) { Fill(b, x + 5, py + 4, 3, 2, eye); Px(b, x + 6, py + 4, White); }
        else if (dir == 2) { Fill(b, x + 6, py + 3, 4, 2, Amber); Px(b, x + 7, py + 3, White); }
        else if (sus) { Fill(b, x + 5, py + 4, 6, 1, Red); Fill(b, x + 7, py + 4, 2, 1, White); }
        else { Fill(b, x + 6, py + 4, 4, 2, eye); Fill(b, x + 7, py + 4, 2, 1, White); }

        // Sword/blade slash animation!
        if (swordOut)
        {
            int sx = (dir >= 0) ? x + 13 : x - 8;
            Fill(b, sx, py + 6, 7, 2, Cyan);
            Fill(b, sx + 1, py + 5, 5, 1, White);
            // Slash arc
            Px(b, sx + 6, py + 3, Cyan); Px(b, sx + 7, py + 4, White); Px(b, sx + 7, py + 8, Cyan); Px(b, sx + 5, py + 10, GhHi);
        }

        // Pushing arms extended
        if (pose == 2)
        {
            int ax = (dir >= 0) ? x + 13 : x - 4;
            Fill(b, ax, py + 10, 4, 2, BotHeadLight);
            Fill(b, ax, py + 13, 4, 2, BotHeadLight);
        }

        if (mug)
        {
            int mx = x - 3, my = py + 9;
            Fill(b, mx, my, 4, 4, White); Px(b, mx - 1, my + 1, White); Px(b, mx - 1, my + 2, White);
            if (step % 2 == 0) Px(b, mx + 1, my - 2, MetalLight); else Px(b, mx + 2, my - 3, MetalLight);
        }
    }

    static void CloseUp(Bitmap b, int sx, int sy, bool knock, bool remote, int f)
    {
        int cx = sx + 65, by = sy + 14;
        for (int i = 0; i < 14; i++) { Fill(b, cx + 16 + i, by + 18 - i, 4, 4, MetalDark); Fill(b, cx + 17 + i, by + 18 - i, 2, 2, Cyan); }
        Fill(b, cx - 28, by + 30, 56, 36, CoatDark); Fill(b, cx - 24, by + 26, 48, 8, CoatTrim);
        Fill(b, cx - 20, by + 32, 40, 34, CoatMid); Fill(b, cx - 4, by + 32, 8, 34, VisorBg);
        Fill(b, cx - 20, by + 2, 40, 28, BotHead); Fill(b, cx - 18, by, 36, 3, BotHeadLight); Rect(b, cx - 20, by + 2, 40, 28, CoatDark);
        Fill(b, cx - 23, by + 10, 3, 8, MetalLight); Fill(b, cx + 20, by + 10, 3, 8, MetalLight);
        Fill(b, cx - 16, by + 9, 32, 12, VisorBg); Rect(b, cx - 16, by + 9, 32, 12, CoatTrim);
        Fill(b, cx - 12, by + 13, 24, 4, Red); Fill(b, cx - 6, by + 13, 12, 4, Amber); Fill(b, cx - 3, by + 14, 6, 2, White);

        if (knock)
        {
            int kx = cx + 18, ky = by + 18;
            Fill(b, kx - 5, ky - 5, 10, 10, BotHeadLight); Rect(b, kx - 5, ky - 5, 10, 10, VisorBg);
            Fill(b, kx - 6, ky - 9, 12, 1, White); Fill(b, kx - 6, ky + 8, 12, 1, White);
            Fill(b, kx - 9, ky - 6, 1, 12, White); Fill(b, kx + 8, ky - 6, 1, 12, White);
            Fill(b, kx - 8, ky - 13, 16, 1, Cyan); Fill(b, kx - 8, ky + 12, 16, 1, Cyan);
            Fill(b, kx - 13, ky - 8, 1, 16, Cyan); Fill(b, kx + 12, ky - 8, 1, 16, Cyan);
            Text(b, "TOC!", sx + 8, sy + 18, White);
            if (f % 2 == 1) Text(b, "TOC!", sx + 96, sy + 18, Yellow);
        }

        if (remote)
        {
            int rx = cx - 26, ry = by + 22;
            Fill(b, rx, ry, 12, 18, VisorBg); Rect(b, rx, ry, 12, 18, MetalLight);
            Fill(b, rx + 3, ry + 3, 3, 3, Red); Fill(b, rx + 7, ry + 3, 3, 3, GhG4);
            Fill(b, rx + 3, ry + 8, 6, 2, MetalDark); Fill(b, rx + 3, ry + 12, 6, 2, MetalDark);
            // IR beam firing at viewer!
            Fill(b, rx + 4, ry - 4, 4, 4, Red);
            Rect(b, rx + 1, ry - 7, 10, 10, Yellow);
            Text(b, "CLICK!", sx + 8, sy + 20, Red);
        }
    }

    static void Subtitle(Bitmap b, int sx, int sy, string t, Color c)
    {
        int y = sy + 88 - 11;
        Fill(b, sx + 2, y, 126, 9, C("#0a0e14")); Rect(b, sx + 2, y, 126, 9, BezelMid);
        TextC(b, t, sx + 65, y + 2, c);
    }

    static void Sparkle(Bitmap b, int cx, int cy, int r, Color c1, Color c2)
    {
        Px(b, cx - r, cy - r, c1); Px(b, cx + r, cy - r, c1); Px(b, cx - r, cy + r, c2); Px(b, cx + r, cy + r, c2);
        Px(b, cx, cy - r - 1, c1); Px(b, cx, cy + r + 1, c2); Px(b, cx - r - 1, cy, c1); Px(b, cx + r + 1, cy, c2);
    }

    // 84 Frames across 5 distinct interactive scenes:
    // 0..17:  Cena 1 - Ronda & Polimento do commit TargetA com lamina energetica (+1 COMMIT)
    // 18..39: Cena 2 - Bloco verde cai do ceu; Vico-04 EMPURRA o bloco ate TargetB, senta nele e toma cafe!
    // 40..57: Cena 3 - Um BUG vermelho aparece em TargetC! Vico-04 da um dash com a espada e conserta (FIXED!)
    // 58..70: Cena 4 - O holofote do estudio DESPENCA no chao + ceu mostra fios e grade azul (Show de Truman!)
    // 71..80: Cena 5 - Vico-04 encosta no vidro (TOC! TOC!), pega o controle remoto (CLICK!) e puxa a persiana
    // 81..83: Reset das barras de cor SMPTE
    static Bitmap Frame(int f)
    {
        Bitmap b = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        bool glitch = (f == 41 || f == 59 || f == 60 || f >= 81);
        bool shake = (f == 19 || f == 59 || f == 72 || f == 74);
        int ox = shake ? ((f % 2 == 0) ? -1 : 1) : 0, oy = shake ? 1 : 0;
        string ch = (f < 18) ? "01" : (f < 40) ? "02" : (f < 58) ? "03" : "04";
        DrawTv(b, f, ox, oy, glitch, f >= 40, ch);
        int sx = 30 + ox, sy = 20 + oy, sw = 130, sh = 88;

        Fill(b, sx, sy, sw, 32, SkyTop); Fill(b, sx, sy + 20, sw, 12, SkyBot);

        if (f >= 81)
        {
            Color[] bars = { White, Yellow, Cyan, GhG4, Purple, Red, WireBlue };
            int bw = sw / bars.Length;
            for (int i = 0; i < bars.Length; i++) Fill(b, sx + i * bw, sy, (i == bars.Length - 1) ? sw - i * bw : bw, sh, bars[i]);
            Random rng = new Random(f * 997);
            for (int n = 0; n < 180; n++) Fill(b, sx + rng.Next(sw), sy + rng.Next(sh), 3, 1, (n % 2 == 0) ? VisorBg : White);
            Fill(b, sx + 12, sy + 32, sw - 24, 22, VisorBg); Rect(b, sx + 12, sy + 32, sw - 24, 22, White);
            TextC(b, "REINICIANDO TURNO...", sx + 65, sy + 36, Yellow);
            TextC(b, "POR FAVOR AGUARDE", sx + 65, sy + 44, White);
            Finish(b, sx, sy, sw, sh);
            return Up(b);
        }

        // Lua falsa pendurada num fio
        int mx = sx + 104, my = sy + 9;
        Fill(b, mx + 3, sy, 1, 9, MetalDark); Fill(b, mx, my, 7, 7, Yellow); Fill(b, mx + 4, my + 1, 3, 5, SkyTop);

        // Refletor de estudio (cai do teto no frame 58!)
        int spx = sx + 62;
        if (f < 58)
        {
            Fill(b, spx + 2, sy, 2, 4, MetalDark); Fill(b, spx, sy + 4, 6, 4, BezelLight); Fill(b, spx + 1, sy + 8, 4, 1, Yellow);
        }

        Text(b, "IBOPE " + Total, sx + 4, sy + 12, (f % 8 < 6) ? GhHi : GhG3);

        // Wireframe azul de simulacao na Cena 4
        if (f >= 58 && f <= 69)
        {
            for (int gx = sx + 8; gx < sx + sw; gx += 16) Fill(b, gx, sy, 1, 32, WireBlue);
            for (int gy = sy + 8; gy < sy + 32; gy += 8) Fill(b, sx, gy, sw, 1, WireBlue);
        }

        // Grade REAL de contribuicoes (ultimas 21 semanas)
        Fill(b, sx, sy + 32, sw, sh - 32, BgDark);
        Fill(b, sx, sy + 31, sw, 1, GhG2);
        int gx0 = GridX(sx), gy0 = GridY(sy);
        for (int i = 0; i < Levels.Length; i++)
        {
            int l = Levels[i];
            if (l < 0) continue;
            int x = gx0 + (i / 7) * PITCH, y = gy0 + (i % 7) * PITCH;
            Color c = Lvl(l);

            if (i == TargetA && f >= 8 && f <= 14) c = (f % 2 == 0) ? GhHi : GhG4;
            if (i == TargetB && f >= 29) c = GhG4;
            if (i == TargetC && f >= 40 && f <= 49) c = (f % 2 == 0) ? Red : Amber; // BUG!
            if (i == TargetC && f >= 50) c = (f <= 54 && f % 2 == 0) ? Cyan : GhHi; // FIXED!

            Fill(b, x, y, TILE, TILE, c);
            if ((l == 4 || (i == TargetB && f >= 29)) && !(i == TargetC && f >= 40 && f <= 49))
                Fill(b, x, y, TILE, 1, GhHi);
        }

        int ax, ay, bx, by2, cx, cy;
        CellCenter(TargetA, sx, sy, out ax, out ay);
        CellCenter(TargetB, sx, sy, out bx, out by2);
        CellCenter(TargetC, sx, sy, out cx, out cy);

        // ----- CENA 1: Ronda & Polimento do Commit TargetA (0..17) -----
        if (f <= 17)
        {
            int startX = sx + 8;
            int vx = (f < 7) ? startX + (ax - 14 - startX) * f / 7 : ax - 14;
            int vy = ay - 18;
            bool slash = (f >= 8 && f <= 12);
            Vico(b, vx, vy, 1, (f < 7) ? f % 4 : 0, slash ? 1 : 0, f >= 14, false, slash);
            if (slash)
            {
                Sparkle(b, ax, ay, 4, Cyan, GhHi);
                Text(b, "POLINDO!", ax - 10, vy - 7, Cyan);
            }
            else if (f >= 13)
            {
                Sparkle(b, ax, ay, 3, GhHi, Yellow);
                Text(b, "+1 COMMIT", ax - 12, vy - 7, GhHi);
            }
            Subtitle(b, sx, sy, "ATO 1 // POLINDO OS COMMITS REAIS", GhG4);
        }
        // ----- CENA 2: Empurrando um bloco novo + Pausa pro Cafe (18..39) -----
        else if (f <= 39)
        {
            int dropStartX = Math.Max(sx + 18, bx - 32);
            int vy = by2 - 18;
            if (f <= 21)
            {
                // Bloco cai do ceu em dropStartX
                int blockY = sy + 4 + (f - 18) * (by2 - 2 - (sy + 4)) / 3;
                Fill(b, dropStartX, blockY, TILE + 1, TILE + 1, GhG4);
                Rect(b, dropStartX, blockY, TILE + 1, TILE + 1, GhHi);
                Vico(b, dropStartX - 14, vy, 1, 0, 0, false, true, false);
                Text(b, "THUD!", dropStartX - 4, blockY - 7, Yellow);
            }
            else if (f <= 29)
            {
                // Vico empurra o bloco verde pela grade ate bx!
                int prog = f - 21;
                int curBx = dropStartX + (bx - 2 - dropStartX) * prog / 8;
                Fill(b, curBx, by2 - 2, TILE + 1, TILE + 1, GhG4);
                Rect(b, curBx, by2 - 2, TILE + 1, TILE + 1, GhHi);
                Vico(b, curBx - 13, vy, 1, f % 4, 2, false, false, false);
                if (f % 2 == 0) Text(b, "EMPURRA!", curBx - 12, vy - 7, Yellow);
            }
            else
            {
                // Sentado em cima do bloco verde tomando cafe!
                Sparkle(b, bx, by2, 4, GhHi, Yellow);
                Vico(b, bx - 7, vy - 2, 0, f % 4, 3, true, false, false);
                Text(b, "CAFEZINHO", bx - 18, vy - 9, White);
            }
            Subtitle(b, sx, sy, "ATO 2 // EMPILHANDO BLOCOS E CAFE", Yellow);
        }
        // ----- CENA 3: Caça ao Bug na Grade com Espada (40..57) -----
        else if (f <= 57)
        {
            int vy = cy - 18;
            if (f <= 44)
            {
                // Bug piscando em TargetC; Vico se assusta
                Vico(b, bx - 7, by2 - 18, 1, 0, 0, false, true, true);
                Sparkle(b, cx, cy, 4, Red, Amber);
                Text(b, "BUG!", cx - 8, cy - 10, Red);
            }
            else if (f <= 49)
            {
                // Dash veloz ate TargetC com rastro ciano!
                int prog = f - 44;
                int vx = (bx - 7) + ((cx - 14) - (bx - 7)) * prog / 5;
                int curVy = (by2 - 18) + (vy - (by2 - 18)) * prog / 5;
                Fill(b, vx - 8, curVy + 8, 8, 2, Cyan); // speed trail
                Vico(b, vx, curVy, 1, f % 4, 1, false, true, true);
                Sparkle(b, cx, cy, 4, Red, Yellow);
            }
            else
            {
                // Golpe final: Bug eliminado!
                Vico(b, cx - 14, vy, 1, 0, 1, false, false, true);
                Sparkle(b, cx, cy, 5, Cyan, GhHi);
                Text(b, "GIT FIX!", cx - 14, vy - 8, GhHi);
            }
            Subtitle(b, sx, sy, "ATO 3 // ELIMINANDO BUG DA GRADE!", Red);
        }
        // ----- CENA 4: O Holofote Cai do Ceu + Fios da Simulacao (58..70) -----
        else if (f <= 70)
        {
            int spotLandY = sy + 52;
            int curSpotY = (f < 61) ? sy + 6 + (f - 58) * (spotLandY - (sy + 6)) / 3 : spotLandY;
            // Fios pendurados no ceu
            for (int y = sy; y < curSpotY; y += 2) Px(b, spx + 3, y, Cyan);
            for (int y = sy; y < cy; y += 2) Px(b, cx, y, White);

            // Holofote caido no chao soltando faiscas
            Fill(b, spx, curSpotY, 7, 5, BezelLight);
            Fill(b, spx + 1, curSpotY + 1, 5, 3, Yellow);
            if (f >= 61)
            {
                Sparkle(b, spx + 3, spotLandY + 2, 4, Yellow, Cyan);
                Text(b, "CRASH!", spx + 6, spotLandY - 9, Yellow);
            }

            int vx = spx - 18, vy = spotLandY - 14;
            Vico(b, vx, vy, (f < 65) ? 2 : 0, 0, 0, false, true, false);
            Fill(b, vx + 6, vy - 9, 5, 7, VisorBg);
            Text(b, "?", vx + 7, vy - 8, Yellow);
            Subtitle(b, sx, sy, "ATO 4 // O CEU E FALSO?! FIOS?!", Amber);
        }
        // ----- CENA 5: Quebra da 4a Parede + Controle Remoto + Persiana (71..80) -----
        else
        {
            bool knock = (f >= 71 && f <= 74);
            bool remote = (f >= 75 && f <= 76);
            CloseUp(b, sx, sy, knock, remote, f);
            if (f <= 76)
            {
                Subtitle(b, sx, sy, "EI! CLICA NOS BOTOES AI EMBAIXO!", Yellow);
            }
            else
            {
                int bh = (f == 77) ? sh / 2 : sh;
                for (int y = sy; y < sy + bh; y += 4)
                {
                    if (f >= 78 && y >= sy + 24 && y <= sy + 28) continue;
                    Fill(b, sx, y, sw, 3, BezelMid); Fill(b, sx, y, sw, 1, BezelLight);
                }
                Fill(b, sx + sw - 12, sy, 1, bh - 6, White); Fill(b, sx + sw - 13, sy + bh - 6, 3, 4, Yellow);
                Fill(b, sx + 8, sy + 42, sw - 16, 28, VisorBg); Rect(b, sx + 8, sy + 42, sw - 16, 28, GhG4);
                TextC(b, "404: PRIVACIDADE", sx + 65, sy + 47, Red);
                TextC(b, "$ USE O CONTROLE ABAIXO $", sx + 65, sy + 58, GhHi);
            }
        }

        if (f < 77)
        {
            Text(b, "REC", sx + 4, sy + 3, Red);
            if (f % 4 < 2) Fill(b, sx + 18, sy + 4, 3, 3, Red);
            Text(b, "CH-" + ch, sx + sw - 24, sy + 3, GhG4);
        }
        Finish(b, sx, sy, sw, sh);
        return Up(b);
    }

    static void Finish(Bitmap b, int sx, int sy, int sw, int sh)
    {
        for (int y = sy; y < sy + sh; y += 2)
            for (int x = sx; x < sx + sw; x++)
            {
                Color c = b.GetPixel(x, y);
                b.SetPixel(x, y, Color.FromArgb(255, (int)(c.R * 0.86), (int)(c.G * 0.86), (int)(c.B * 0.86)));
            }
        int[,] k = { {sx,sy},{sx+1,sy},{sx,sy+1},{sx+sw-1,sy},{sx+sw-2,sy},{sx+sw-1,sy+1},
                     {sx,sy+sh-1},{sx+1,sy+sh-1},{sx,sy+sh-2},{sx+sw-1,sy+sh-1},{sx+sw-2,sy+sh-1},{sx+sw-1,sy+sh-2} };
        for (int i = 0; i < k.GetLength(0); i++) Px(b, k[i,0], k[i,1], BezelDark);
    }

    static Bitmap Up(Bitmap src)
    {
        Bitmap dst = new Bitmap(W * SCALE, H * SCALE, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(dst))
        {
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.DrawImage(src, new Rectangle(0, 0, W * SCALE, H * SCALE), new Rectangle(0, 0, W, H), GraphicsUnit.Pixel);
        }
        src.Dispose();
        return dst;
    }

    [System.Runtime.InteropServices.DllImport("gdi32.dll")]
    static extern bool DeleteObject(IntPtr h);

    public static void Generate(int[] levels, int total, string gifPath, string previewDir)
    {
        Levels = levels; Total = total; ChooseTargets();
        const int N = 84;
        int[] delays = new int[N];
        GifBitmapEncoder enc = new GifBitmapEncoder();
        for (int f = 0; f < N; f++)
        {
            delays[f] = (f == 16 || f == 38 || f == 55 || f == 68 || f == 76) ? 26 : (f >= 78 && f <= 80) ? 34 : 13;
            using (Bitmap bmp = Frame(f))
            {
                if (!string.IsNullOrEmpty(previewDir) && (f == 10 || f == 26 || f == 34 || f == 52 || f == 63 || f == 75))
                    bmp.Save(Path.Combine(previewDir, "rich_" + f.ToString("D2") + ".png"), ImageFormat.Png);
                IntPtr hb = bmp.GetHbitmap();
                try
                {
                    enc.Frames.Add(BitmapFrame.Create(System.Windows.Interop.Imaging.CreateBitmapSourceFromHBitmap(
                        hb, IntPtr.Zero, System.Windows.Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions())));
                }
                finally { DeleteObject(hb); }
            }
        }
        using (MemoryStream ms = new MemoryStream())
        {
            enc.Save(ms);
            File.WriteAllBytes(gifPath, Patch(ms.ToArray(), delays));
        }
    }

    static byte[] Patch(byte[] raw, int[] delays)
    {
        int packed = raw[10];
        int gct = ((packed & 0x80) != 0) ? 3 * (1 << ((packed & 0x07) + 1)) : 0;
        int pos = 13 + gct, fi = 0;
        for (int i = pos; i < raw.Length - 8; i++)
            if (raw[i] == 0x21 && raw[i + 1] == 0xF9 && raw[i + 2] == 0x04 && raw[i + 7] == 0x00)
            {
                int d = (fi < delays.Length) ? delays[fi] : 12;
                raw[i + 4] = (byte)(d & 0xFF); raw[i + 5] = (byte)(d >> 8); fi++;
            }
        byte[] ns = { 0x21, 0xFF, 0x0B, 0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30, 0x03, 0x01, 0x00, 0x00, 0x00 };
        using (MemoryStream o = new MemoryStream())
        {
            o.Write(raw, 0, pos); o.Write(ns, 0, ns.Length); o.Write(raw, pos, raw.Length - pos);
            return o.ToArray();
        }
    }
}
'@

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml, System.Drawing
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing, PresentationCore, PresentationFramework, WindowsBase, System.Xaml
[PixelTvRich]::Generate($levels, $total, $OutPath, $PreviewDir)
Write-Output "GIF gerado: $OutPath ($((Get-Item $OutPath).Length) bytes)"
