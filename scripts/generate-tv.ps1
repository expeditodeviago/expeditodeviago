# Gera assets/tv-truman-grid.gif em pixel art 2.5D detalhada (340x200 -> 680x400)
# usando as contribuicoes REAIS do GitHub e tipografia pixelada VT323.
param(
    [string]$User = "expeditodeviago",
    [string]$OutPath = "",
    [string]$PreviewDir = ""
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutPath) { $OutPath = Join-Path $root "assets\tv-truman-grid.gif" }
$fontPath = Join-Path $root "design\VT323-Regular.ttf"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
if ($PreviewDir) { New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null }

# ---------- 1. Ler contribuicoes reais do GitHub ----------
$html = (Invoke-WebRequest -UseBasicParsing "https://github.com/users/$User/contributions").Content
$cells = @{}
foreach ($m in [regex]::Matches($html, 'data-date="(\d{4}-\d{2}-\d{2})"[^>]*?data-level="(\d)"')) {
    $cells[$m.Groups[1].Value] = [int]$m.Groups[2].Value
}
if ($cells.Count -eq 0) { throw "Nao consegui ler o calendario de contribuicoes." }
$totalMatch = [regex]::Match($html, '([\d,\.]+)\s+contributions?\s+in the last year')
$total = if ($totalMatch.Success) { [int]($totalMatch.Groups[1].Value -replace '[,\.]', '') } else { 0 }

$WEEKS = 18
$lastDate = [datetime]::ParseExact(($cells.Keys | Sort-Object | Select-Object -Last 1), "yyyy-MM-dd", $null)
$lastWeekStart = $lastDate.AddDays(-[int]$lastDate.DayOfWeek)
$firstWeekStart = $lastWeekStart.AddDays(-7 * ($WEEKS - 1))
$levels = New-Object int[] ($WEEKS * 7)
for ($w = 0; $w -lt $WEEKS; $w++) {
    for ($d = 0; $d -lt 7; $d++) {
        $key = $firstWeekStart.AddDays($w * 7 + $d).ToString("yyyy-MM-dd")
        $levels[$w * 7 + $d] = if ($cells.ContainsKey($key)) { $cells[$key] } else { 0 }
    }
}
Write-Output "Contribuicoes no ano: $total | janela: $($firstWeekStart.ToString('yyyy-MM-dd')) -> $($lastDate.ToString('yyyy-MM-dd'))"

# ---------- 2. Engine Pixel Art 2.5D ----------
$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Windows.Media.Imaging;

public class TrumanTvStudio
{
    const int W = 340, H = 204, SCALE = 2, WEEKS = 18;
    static Color C(string h) { return ColorTranslator.FromHtml(h); }

    // Studio & Desk Palette
    static readonly Color BgStudio = C("#0d1117");
    static readonly Color DeskTop = C("#161c26");
    static readonly Color DeskEdge = C("#263042");
    static readonly Color DeskShadow = C("#080b10");

    // Walnut Wood & Brushed Trinitron Hardware
    static readonly Color WoodHi = C("#9c623c");
    static readonly Color WoodLight = C("#7d4b2b");
    static readonly Color WoodMid = C("#5e361d");
    static readonly Color WoodDark = C("#3d2110");
    static readonly Color WoodDeep = C("#241207");
    static readonly Color BrassFoot = C("#b8863b");

    static readonly Color SilverHi = C("#d0d7de");
    static readonly Color SilverMid = C("#8b949e");
    static readonly Color SilverDark = C("#484f58");
    static readonly Color BezelOuter = C("#21262d");
    static readonly Color BezelInner = C("#11151c");
    static readonly Color PanelDark = C("#181d24");

    // CRT Screen & 2.5D Grid Colors
    static readonly Color SkyTop = C("#070c16");
    static readonly Color SkyMid = C("#0d1729");
    static readonly Color SkyBot = C("#13233b");
    static readonly Color DomeHex = C("#1f6feb");
    static readonly Color DomeGlow = C("#58a6ff");

    static readonly Color FloorTop = C("#13222b");
    static readonly Color FloorEdge = C("#0b151b");
    static readonly Color FloorLine = C("#1d3340");

    // GitHub Emerald 3D Extruded Blocks
    static readonly Color[] TopCol = { C("#13222b"), C("#145332"), C("#1e8244"), C("#2ea043"), C("#39d353") };
    static readonly Color[] FrontCol = { C("#0b151b"), C("#0e3a23"), C("#14592f"), C("#1f6f30"), C("#26a641") };
    static readonly Color[] RimCol = { C("#1d3340"), C("#1e6f43"), C("#2ea043"), C("#56d364"), C("#7ee787") };

    // Accents & Character
    static readonly Color Cyan = C("#58a6ff");
    static readonly Color CyanHi = C("#a5d6ff");
    static readonly Color Amber = C("#f0b429");
    static readonly Color Red = C("#ff5f56");
    static readonly Color YellowNote = C("#f7d154");
    static readonly Color NoteInk = C("#1c1917");
    static readonly Color White = C("#f0f6fc");

    static readonly Color CoatDark = C("#171e2b");
    static readonly Color CoatMid = C("#253147");
    static readonly Color CoatHi = C("#3b4d6e");
    static readonly Color HelmetDark = C("#2a323d");
    static readonly Color HelmetMid = C("#434e5e");
    static readonly Color HelmetHi = C("#6e7c91");
    static readonly Color VisorBlack = C("#080b10");

    static PrivateFontCollection Pfc;
    static Font FontSmall, FontMed, FontBig;
    static int[] Levels;
    static int Total;
    static int TargetA, TargetB;

    public static void InitFonts(string ttfPath)
    {
        Pfc = new PrivateFontCollection();
        Pfc.AddFontFile(ttfPath);
        FontSmall = new Font(Pfc.Families[0], 12f, FontStyle.Regular, GraphicsUnit.Pixel);
        FontMed = new Font(Pfc.Families[0], 14f, FontStyle.Regular, GraphicsUnit.Pixel);
        FontBig = new Font(Pfc.Families[0], 16f, FontStyle.Regular, GraphicsUnit.Pixel);
    }

    static void Px(Bitmap b, int x, int y, Color c)
    {
        if (x >= 0 && x < W && y >= 0 && y < H) b.SetPixel(x, y, c);
    }

    static void Fill(Bitmap b, int x, int y, int w, int h, Color c)
    {
        int x0 = Math.Max(0, x), y0 = Math.Max(0, y);
        int x1 = Math.Min(W, x + w), y1 = Math.Min(H, y + h);
        for (int j = y0; j < y1; j++)
            for (int i = x0; i < x1; i++)
                b.SetPixel(i, j, c);
    }

    static void Rect(Bitmap b, int x, int y, int w, int h, Color c)
    {
        for (int i = 0; i < w; i++) { Px(b, x + i, y, c); Px(b, x + i, y + h - 1, c); }
        for (int j = 0; j < h; j++) { Px(b, x, y + j, c); Px(b, x + w - 1, y + j, c); }
    }

    static void Line(Bitmap b, int x0, int y0, int x1, int y1, Color c)
    {
        int dx = Math.Abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
        int dy = -Math.Abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
        int err = dx + dy;
        while (true)
        {
            Px(b, x0, y0, c);
            if (x0 == x1 && y0 == y1) break;
            int e2 = 2 * err;
            if (e2 >= dy) { err += dy; x0 += sx; }
            if (e2 <= dx) { err += dx; y0 += sy; }
        }
    }

    static void FillCircle(Bitmap b, int cx, int cy, int r, Color c)
    {
        for (int dy = -r; dy <= r; dy++)
            for (int dx = -r; dx <= r; dx++)
                if (dx * dx + dy * dy <= r * r + 1)
                    Px(b, cx + dx, cy + dy, c);
    }

    static void DrawCircle(Bitmap b, int cx, int cy, int r, Color c)
    {
        for (int dy = -r; dy <= r; dy++)
            for (int dx = -r; dx <= r; dx++)
            {
                int d2 = dx * dx + dy * dy;
                if (d2 <= r * r + 1 && d2 >= (r - 1) * (r - 1))
                    Px(b, cx + dx, cy + dy, c);
            }
    }

    static void DrawPixelText(Bitmap b, string text, Font f, int x, int y, Color col, bool center = false)
    {
        using (Graphics g = Graphics.FromImage(b))
        {
            g.TextRenderingHint = TextRenderingHint.SingleBitPerPixelGridFit;
            g.SmoothingMode = SmoothingMode.None;
            if (center)
            {
                SizeF sz = g.MeasureString(text, f);
                x = x - (int)(sz.Width / 2f);
            }
            using (Brush br = new SolidBrush(col))
                g.DrawString(text, f, br, x, y);
        }
    }

    static void ChooseTargets()
    {
        List<int> active = new List<int>();
        for (int i = 0; i < Levels.Length; i++) if (Levels[i] > 0) active.Add(i);
        if (active.Count >= 2)
        {
            TargetA = active[active.Count / 3];
            TargetB = active[active.Count - 1];
            if (TargetB == TargetA && active.Count > 1) TargetA = active[0];
        }
        else
        {
            TargetA = 5 * 7 + 3;
            TargetB = 13 * 7 + 2;
        }
    }

    // 2.5D Grid Coordinates inside CRT (sx=52, sy=26, sw=190, sh=140)
    static void TilePos(int idx, int sx, int sy, out int tx, out int ty)
    {
        int w = idx / 7, d = idx % 7;
        int baseX = sx + 12 + (6 - d) * 1; // subtle 2.5D perspective slant!
        int baseY = sy + 78;
        tx = baseX + w * 9;
        ty = baseY + d * 8;
    }

    static void DrawDeskAndProps(Bitmap b, int f)
    {
        Fill(b, 0, 0, W, H, BgStudio);

        // Subtle ambient studio glow behind TV
        for (int r = 115; r > 70; r -= 15)
            DrawCircle(b, W / 2, 98, r, C("#101822"));

        // Desk surface
        Fill(b, 10, 180, W - 20, 18, DeskTop);
        Fill(b, 10, 180, W - 20, 2, DeskEdge);
        Fill(b, 4, 198, W - 8, 6, BgStudio);
        Fill(b, 38, 182, 264, 5, DeskShadow); // TV shadow on desk

        // Prop Left: Stacked VHS cassettes on the desk
        Fill(b, 12, 168, 24, 6, C("#1f2633")); Rect(b, 12, 168, 24, 6, C("#343f52"));
        Fill(b, 15, 170, 12, 2, Amber);
        Fill(b, 10, 174, 26, 6, C("#191f2a")); Rect(b, 10, 174, 26, 6, C("#2d3748"));
        Fill(b, 13, 176, 14, 2, Red);

        // Prop Right: Pixel Succulent Plant in Terracotta Pot + Desk Mug
        Fill(b, 308, 170, 14, 10, C("#9c4a2d")); // pot
        Fill(b, 306, 168, 18, 3, C("#b85a3a"));  // pot rim
        FillCircle(b, 315, 164, 5, C("#1e8244"));
        FillCircle(b, 312, 163, 3, C("#39d353"));
        FillCircle(b, 318, 165, 3, C("#2ea043"));
        Px(b, 314, 161, C("#7ee787"));
    }

    static void DrawCabinetAndControls(Bitmap b, int f, int ox, int oy, bool glitch, bool alert)
    {
        int tx = 40 + ox, ty = 16 + oy, tw = 260, th = 164;

        // Rabbit-ear Chrome Antenna on top
        int ax = tx + 112, ay = ty;
        Line(b, ax - 4, ay, ax - 36, ay - 14, SilverDark);
        Line(b, ax - 3, ay, ax - 35, ay - 14, SilverHi);
        Line(b, ax + 4, ay, ax + 38, ay - 13, SilverDark);
        Line(b, ax + 5, ay, ax + 39, ay - 13, SilverHi);
        FillCircle(b, ax - 36, ay - 14, 2, Red);
        FillCircle(b, ax + 39, ay - 13, 2, Red);
        Fill(b, ax - 12, ay - 3, 24, 4, BezelOuter);
        Rect(b, ax - 12, ay - 3, 24, 4, SilverDark);
        if (glitch)
        {
            for (int x = ax - 26; x <= ax + 26; x += 4)
                Px(b, x, ay - 11 + ((x + f) % 3 - 1), CyanHi);
        }

        // Brass / Wood Feet
        Fill(b, tx + 20, ty + th, 22, 4, WoodDeep);
        Fill(b, tx + 22, ty + th + 2, 18, 2, BrassFoot);
        Fill(b, tx + tw - 42, ty + th, 22, 4, WoodDeep);
        Fill(b, tx + tw - 40, ty + th + 2, 18, 2, BrassFoot);

        // Outer Rounded Walnut Wood Cabinet
        Fill(b, tx + 3, ty, tw - 6, th, WoodMid);
        Fill(b, tx, ty + 3, tw, th - 6, WoodMid);
        Fill(b, tx + 1, ty + 1, tw - 2, th - 2, WoodMid);

        // Wood Grain Texture & Bevel Shading
        for (int y = ty + 3; y < ty + th - 3; y += 5)
        {
            Fill(b, tx + 2, y, tw - 4, 1, WoodDark);
            if (y % 10 == 3) Fill(b, tx + 4, y + 2, tw - 8, 1, WoodLight);
        }
        Fill(b, tx + 4, ty + 1, tw - 8, 2, WoodHi);       // top highlight
        Fill(b, tx + 4, ty + th - 3, tw - 8, 2, WoodDeep); // bottom shadow
        Line(b, tx + 2, ty + 2, tx + 9, ty + 9, WoodDeep); // mitered corner seams
        Line(b, tx + tw - 3, ty + 2, tx + tw - 10, ty + 9, WoodDeep);

        // Inner Brushed Trinitron Bezel
        Fill(b, tx + 8, ty + 8, tw - 16, th - 16, BezelOuter);
        Rect(b, tx + 8, ty + 8, tw - 16, th - 16, SilverMid); // signature silver trim!
        Fill(b, tx + 10, ty + 10, 194, th - 20, BezelInner);

        // Right-Side Control Deck (X: tx+207 .. tx+249)
        int px = tx + 207, py = ty + 10, pw = 43, ph = th - 20;
        Fill(b, px, py, pw, ph, PanelDark);
        Rect(b, px, py, pw, ph, SilverDark);

        // Digital Channel Readout
        Fill(b, px + 5, py + 5, pw - 10, 16, VisorBlack);
        Rect(b, px + 5, py + 5, pw - 10, 16, SilverDark);
        DrawPixelText(b, glitch ? "ERR" : "CH 04", FontSmall, px + pw / 2, py + 6, glitch ? Red : TopCol[4], true);

        // Backlit Analog VU Signal Meter!
        int vx = px + 5, vy = py + 25, vw = pw - 10, vh = 16;
        Fill(b, vx, vy, vw, vh, C("#241c0c"));
        Rect(b, vx, vy, vw, vh, SilverDark);
        Fill(b, vx + 3, vy + 3, vw - 6, 2, C("#5c481c"));
        Fill(b, vx + vw - 9, vy + 3, 6, 2, Red);
        int needleX = vx + vw / 2 + (int)(Math.Sin(f * 0.55) * 9);
        Line(b, vx + vw / 2, vy + vh - 2, needleX, vy + 4, Amber);

        // Rotary VHF Knob (Shaded Metallic Circle)
        int k1x = px + pw / 2, k1y = py + 56;
        FillCircle(b, k1x, k1y + 1, 11, VisorBlack);
        FillCircle(b, k1x, k1y, 10, SilverDark);
        FillCircle(b, k1x, k1y, 8, SilverMid);
        FillCircle(b, k1x - 1, k1y - 1, 6, SilverHi);
        FillCircle(b, k1x, k1y, 5, BezelOuter);
        double ang1 = -0.8 + (glitch ? 1.1 : 0.0);
        Line(b, k1x, k1y, k1x + (int)(Math.Cos(ang1) * 7), k1y + (int)(Math.Sin(ang1) * 7), White);

        // Rotary UHF Knob
        int k2x = px + pw / 2, k2y = py + 84;
        FillCircle(b, k2x, k2y + 1, 9, VisorBlack);
        FillCircle(b, k2x, k2y, 8, SilverDark);
        FillCircle(b, k2x, k2y, 6, SilverMid);
        FillCircle(b, k2x, k2y, 4, BezelOuter);
        double ang2 = 0.6 + (f / 20) * 0.3;
        Line(b, k2x, k2y, k2x + (int)(Math.Cos(ang2) * 6), k2y + (int)(Math.Sin(ang2) * 6), SilverHi);

        // Speaker Grille Slots
        for (int sy = py + 100; sy <= py + 122; sy += 4)
        {
            Fill(b, px + 7, sy, pw - 14, 2, VisorBlack);
        }

        // Power Switch & Glowing LED
        Fill(b, px + 9, py + 129, 14, 8, BezelOuter);
        Rect(b, px + 9, py + 129, 14, 8, SilverDark);
        Color led = alert ? ((f % 2 == 0) ? Red : Amber) : TopCol[4];
        FillCircle(b, px + 31, py + 133, 3, led);
        Px(b, px + 30, py + 132, White);
    }

    // Detailed 28px-tall Pixel Art Character (Vico-04)
    // eyeMode: 0=normal cyan, 1=happy ^^, 2=shocked OO, 3=suspicious squint ¬¬
    static void DrawVico(Bitmap b, int x, int y, int dir, int walkStep, int eyeMode, bool slash, bool coffee)
    {
        int bob = (walkStep == 1 || walkStep == 3) ? -1 : 0;
        int py = y + bob;

        // Ground shadow
        Fill(b, x + 2, y + 26, 14, 2, C("#081016"));

        // Diagonal Glowing Tech-Katana on Back (when not slashing)
        if (!slash)
        {
            Line(b, x, py + 2, x + 16, py + 19, SilverDark);
            Line(b, x + 1, py + 2, x + 17, py + 19, Cyan);
            Fill(b, x - 1, py + 1, 3, 3, White); // pommel
        }

        // Boots (4-step walk cycle)
        int lOff = (walkStep == 1) ? -2 : (walkStep == 3) ? 1 : 0;
        int rOff = (walkStep == 3) ? -2 : (walkStep == 1) ? 1 : 0;
        Fill(b, x + 4 + lOff, y + 23, 4, 4, VisorBlack);
        Fill(b, x + 4 + lOff, y + 26, 4, 1, SilverMid);
        Fill(b, x + 10 + rOff, y + 23, 4, 4, VisorBlack);
        Fill(b, x + 10 + rOff, y + 26, 4, 1, SilverMid);

        // Flowing Longcoat (with fluttering coat-tails!)
        int tailShift = (walkStep % 2 == 1) ? -dir : 0;
        Fill(b, x + 2 + tailShift, py + 18, 14, 5, CoatDark);
        Fill(b, x + 3, py + 11, 12, 11, CoatDark);
        Fill(b, x + 4, py + 11, 10, 9, CoatMid);
        // Coat lapels & cyan/brass trim
        Fill(b, x + 3, py + 10, 12, 2, CoatHi);
        Fill(b, x + 8, py + 12, 2, 10, VisorBlack);
        Fill(b, x + 8, py + 16, 2, 2, Amber); // belt clasp

        // Rounded Titanium Helmet (14x10)
        Fill(b, x + 3, py + 1, 12, 9, HelmetDark);
        Fill(b, x + 2, py + 2, 14, 7, HelmetMid);
        Fill(b, x + 4, py, 10, 2, HelmetHi);
        // Side ear-pods with cyan indicator
        Fill(b, x + 1, py + 4, 2, 4, SilverMid);
        Fill(b, x + 15, py + 4, 2, 4, SilverMid);
        Px(b, x + 1, py + 3, Cyan);
        Px(b, x + 16, py + 3, Cyan);

        // Dark Visor Window
        int vx = x + 4 + (dir == 1 ? 1 : (dir == -1 ? -1 : 0));
        Fill(b, vx, py + 3, 10, 5, VisorBlack);

        // Two Expressive Glowing Eyes inside Visor!
        if (eyeMode == 1) // happy ^ ^ sipping coffee
        {
            Px(b, vx + 2, py + 5, CyanHi); Px(b, vx + 3, py + 4, CyanHi); Px(b, vx + 4, py + 5, CyanHi);
            Px(b, vx + 6, py + 5, CyanHi); Px(b, vx + 7, py + 4, CyanHi); Px(b, vx + 8, py + 5, CyanHi);
        }
        else if (eyeMode == 2) // shocked O O
        {
            Rect(b, vx + 1, py + 3, 3, 4, Amber);
            Rect(b, vx + 6, py + 3, 3, 4, Amber);
        }
        else if (eyeMode == 3) // suspicious squint ¬ ¬
        {
            Fill(b, vx + 1, py + 5, 3, 2, Red); Px(b, vx + 2, py + 5, White);
            Fill(b, vx + 6, py + 5, 3, 2, Red); Px(b, vx + 7, py + 5, White);
        }
        else // normal cute glowing eyes (with natural blink)
        {
            Fill(b, vx + 2, py + 4, 2, 3, Cyan); Px(b, vx + 2, py + 4, White);
            Fill(b, vx + 6, py + 4, 2, 3, Cyan); Px(b, vx + 6, py + 4, White);
        }

        // Glowing Crescent Blade Slash!
        if (slash)
        {
            int sx = x + 14;
            Line(b, sx, py + 13, sx + 11, py + 6, CyanHi);
            Line(b, sx, py + 14, sx + 11, py + 7, Cyan);
            DrawCircle(b, sx + 4, py + 11, 9, Cyan);
            Px(b, sx + 12, py + 4, White);
            Px(b, sx + 10, py + 15, RimCol[4]);
        }

        // Steaming Espresso Cup
        if (coffee)
        {
            int mx = x + 14, my = py + 11;
            Fill(b, mx, my, 5, 5, White);
            Fill(b, mx + 1, my + 1, 3, 1, WoodMid); // espresso crema!
            Px(b, mx + 5, my + 1, White); Px(b, mx + 5, my + 3, White);
            Px(b, mx + 4, my + 2, White);
            int sOff = (walkStep % 2 == 0) ? 0 : 1;
            Px(b, mx + 1 + sOff, my - 2, SilverHi);
            Px(b, mx + 2 - sOff, my - 4, SilverMid);
        }
    }

    // High-Detail Close-Up against the CRT Glass!
    static void DrawCloseUp(Bitmap b, int sx, int sy, int sw, int sh, bool knocking, bool showStickyNote, int f)
    {
        int cx = sx + 54, by = sy + 22;

        // Katana hilt over shoulder
        for (int i = 0; i < 16; i++)
        {
            Fill(b, cx + 22 + i, by + 24 - i, 4, 4, SilverDark);
            Fill(b, cx + 23 + i, by + 25 - i, 2, 2, Cyan);
        }

        // Coat Shoulders & Collar
        Fill(b, cx - 34, by + 44, 68, 76, CoatDark);
        Fill(b, cx - 26, by + 46, 52, 74, CoatMid);
        Fill(b, cx - 28, by + 38, 56, 10, CoatHi);
        Fill(b, cx - 4, by + 46, 8, 74, VisorBlack);

        // Detailed Rounded Helmet
        Fill(b, cx - 25, by + 6, 50, 36, HelmetDark);
        Fill(b, cx - 27, by + 10, 54, 28, HelmetMid);
        Fill(b, cx - 20, by + 3, 40, 5, HelmetHi);
        Fill(b, cx - 31, by + 15, 4, 13, SilverMid);
        Fill(b, cx + 27, by + 15, 4, 13, SilverMid);
        Fill(b, cx - 31, by + 12, 3, 3, Cyan);
        Fill(b, cx + 28, by + 12, 3, 3, Cyan);

        // Wide Visor with Two Suspicious Glowing Eyes Staring Right at Viewer!
        Fill(b, cx - 21, by + 13, 42, 18, VisorBlack);
        Rect(b, cx - 21, by + 13, 42, 18, CoatHi);
        // Left Eye
        Fill(b, cx - 15, by + 19, 11, 6, Red);
        Fill(b, cx - 13, by + 20, 7, 4, Amber);
        Fill(b, cx - 11, by + 20, 3, 2, White);
        // Right Eye
        Fill(b, cx + 4, by + 19, 11, 6, Red);
        Fill(b, cx + 6, by + 20, 7, 4, Amber);
        Fill(b, cx + 8, by + 20, 3, 2, White);

        // Palm / Fist Tapping on Inside of CRT Glass!
        if (knocking)
        {
            int kx = cx + 44, ky = by + 30;
            FillCircle(b, kx, ky, 7, HelmetHi);
            DrawCircle(b, kx, ky, 7, VisorBlack);
            DrawCircle(b, kx, ky, 12, White);
            DrawCircle(b, kx, ky, 18, CyanHi);
            DrawPixelText(b, "TOC! TOC!", FontBig, kx + 4, ky - 30, YellowNote, true);
        }

        // Sticky Note Slapped Cleanly Beside Him on the Glass!
        if (showStickyNote)
        {
            int nx = sx + 98, ny = sy + 34, nw = 84, nh = 54;
            Fill(b, nx + 2, ny + 3, nw, nh, C("#090d14"));
            Fill(b, nx, ny, nw, nh, YellowNote);
            Fill(b, nx, ny, nw, 7, C("#e0b638"));
            Rect(b, nx, ny, nw, nh, C("#b89225"));
            DrawPixelText(b, "EI, CURIOSO!", FontMed, nx + nw / 2, ny + 9, NoteInk, true);
            DrawPixelText(b, "OS PROJETOS", FontSmall, nx + nw / 2, ny + 24, NoteInk, true);
            DrawPixelText(b, "ESTÃO ABAIXO ↓", FontSmall, nx + nw / 2, ny + 36, Red, true);
        }
    }

    static Bitmap RenderFrame(int f)
    {
        // 76 Frames across 5 fluid, story-rich acts:
        //  0..17: Act 1 - Walk across 2.5D grid & polish real commit TargetA with cyan blade
        // 18..35: Act 2 - Commit cube drops on TargetB, Vico locks it in & takes an espresso break
        // 36..51: Act 3 - Studio spotlight snaps & crashes! Sky tears open revealing Truman CCTV camera!
        // 52..60: Act 4 - Vico drops coffee, stares at camera, turns suspiciously & approaches screen
        // 61..72: Act 5 - Close-up on glass: knocks TOC! TOC! & slaps yellow sticky note on the screen!
        // 73..75: VHS SMPTE static roll back to frame 0

        Bitmap b = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        bool glitch = (f == 37 || f == 38 || f >= 73);
        bool shake = (f == 38 || f == 63 || f == 65);
        int ox = shake ? ((f % 2 == 0) ? -1 : 1) : 0;
        int oy = shake ? 1 : 0;

        DrawDeskAndProps(b, f);
        DrawCabinetAndControls(b, f, ox, oy, glitch, f >= 37);

        int sx = 52 + ox, sy = 28 + oy, sw = 190, sh = 140;

        // VHS Static & Color Bar Reset (Frames 73..75)
        if (f >= 73)
        {
            Color[] bars = { White, YellowNote, Cyan, TopCol[4], C("#d2a8ff"), Red, DomeHex };
            int bw = sw / bars.Length;
            for (int i = 0; i < bars.Length; i++)
                Fill(b, sx + i * bw, sy, (i == bars.Length - 1) ? sw - i * bw : bw, sh, bars[i]);
            Random rng = new Random(f * 1337);
            for (int n = 0; n < 260; n++)
                Fill(b, sx + rng.Next(sw - 4), sy + rng.Next(sh), 4, 1, (n % 2 == 0) ? VisorBlack : White);
            Fill(b, sx + 28, sy + 52, sw - 56, 34, VisorBlack);
            Rect(b, sx + 28, sy + 52, sw - 56, 34, SilverHi);
            DrawPixelText(b, "REBOBINANDO SINAL...", FontMed, sx + sw / 2, sy + 56, Amber, true);
            DrawPixelText(b, "CANAL 04 // EXP.DEV", FontSmall, sx + sw / 2, sy + 70, TopCol[4], true);
            ApplyCrtGlass(b, sx, sy, sw, sh);
            return Upscale(b);
        }

        // Studio Sky Gradient
        Fill(b, sx, sy, sw, 26, SkyTop);
        Fill(b, sx, sy + 26, sw, 18, SkyMid);
        Fill(b, sx, sy + 44, sw, 16, SkyBot);

        // Twinkling Studio Stars
        int[,] st = { {18,16},{42,28},{78,14},{128,22},{168,30},{94,36},{28,40} };
        for (int i = 0; i < st.GetLength(0); i++)
            Px(b, sx + st[i,0], sy + st[i,1], ((f + i * 2) % 6 == 0) ? White : SilverDark);

        // Truman Show Torn Sky Panel + Giant Studio CCTV Camera (from Frame 37 onward!)
        if (f >= 37)
        {
            int holeX = sx + 88, holeY = sy + 6, holeW = 54, holeH = 38;
            Fill(b, holeX, holeY, holeW, holeH, C("#050912"));
            for (int gx = holeX; gx < holeX + holeW; gx += 9) Line(b, gx, holeY, gx, holeY + holeH - 1, DomeHex);
            for (int gy = holeY; gy < holeY + holeH; gy += 8) Line(b, holeX, gy, holeX + holeW - 1, gy, DomeHex);
            Rect(b, holeX, holeY, holeW, holeH, DomeGlow);

            // Studio CCTV Lens Looking In!
            Fill(b, holeX + 15, holeY + 10, 24, 16, HelmetDark);
            Rect(b, holeX + 15, holeY + 10, 24, 16, SilverMid);
            FillCircle(b, holeX + 27, holeY + 18, 6, VisorBlack);
            DrawCircle(b, holeX + 27, holeY + 18, 6, SilverHi);
            FillCircle(b, holeX + 27, holeY + 18, 3, (f % 2 == 0) ? Red : Amber);
            Px(b, holeX + 26, holeY + 17, White);
        }

        // Fake Crescent Moon Hanging on a Wire (placed left of center so HUD is clean)
        int mx = sx + 74, my = sy + 14;
        Line(b, mx + 4, sy, mx + 4, my, SilverDark);
        FillCircle(b, mx + 4, my + 4, 5, YellowNote);
        FillCircle(b, mx + 6, my + 3, 4, SkyTop);

        // Left Studio Spotlight on Ceiling Rig
        Fill(b, sx + 44, sy, 2, 5, SilverDark);
        Fill(b, sx + 41, sy + 5, 8, 5, SilverMid);
        Fill(b, sx + 42, sy + 10, 6, 1, YellowNote);

        // Right Studio Spotlight (Hangs until frame 36, then SNAPS & CRASHES!)
        if (f < 36)
        {
            Fill(b, sx + 112, sy, 2, 5, SilverDark);
            Fill(b, sx + 109, sy + 5, 8, 5, SilverMid);
            Fill(b, sx + 110, sy + 10, 6, 1, YellowNote);
        }

        // 2.5D Isometric Contribution Grid Floor
        Fill(b, sx, sy + 60, sw, sh - 60, C("#091117"));
        Fill(b, sx, sy + 59, sw, 1, C("#1e4631"));

        // Draw back-to-front (row 0 to row 6) so taller 3D commit blocks occlude naturally!
        for (int d = 0; d < 7; d++)
        {
            for (int w = 0; w < WEEKS; w++)
            {
                int idx = w * 7 + d;
                int lvl = Levels[idx];
                if (idx == TargetB && f >= 24) lvl = 4; // newly locked commit block!

                int tx, ty;
                TilePos(idx, sx, sy, out tx, out ty);
                int extrude = (lvl == 0) ? 0 : (lvl * 3); // 3px, 6px, 9px, 12px 3D height!

                bool glowPulse = (idx == TargetA && f >= 9 && f <= 16) || (idx == TargetB && f >= 24 && f <= 30);

                // Extruded Front Wall
                Fill(b, tx, ty - extrude + 5, 8, extrude + 2, FrontCol[lvl]);
                // Top Face
                Color topC = glowPulse && (f % 2 == 0) ? RimCol[4] : TopCol[lvl];
                Fill(b, tx, ty - extrude, 8, 5, topC);
                // Top Rim Highlight
                Fill(b, tx, ty - extrude, 8, 1, RimCol[lvl]);
                if (lvl == 0)
                    Rect(b, tx, ty, 8, 5, FloorLine);
            }
        }

        int ax, ay, bx, by2;
        TilePos(TargetA, sx, sy, out ax, out ay);
        TilePos(TargetB, sx, sy, out bx, out by2);

        // ----- ACT 1 (0..17): Ronda & Polimento na Grade 2.5D -----
        if (f <= 17)
        {
            int startX = sx + 14;
            int destX = Math.Max(sx + 14, ax - 16);
            int vx = (f < 8) ? startX + (destX - startX) * f / 8 : destX;
            int vy = ay - 26;
            bool slashing = (f >= 9 && f <= 13);
            int eyes = (f == 4 || f == 15) ? 1 : 0;
            DrawVico(b, vx, vy, 1, (f < 8) ? f % 4 : 0, eyes, slashing, false);

            if (f >= 9 && f <= 16)
            {
                int pLift = (f - 9) * 2;
                Px(b, ax + 2, ay - 10 - pLift, RimCol[4]);
                Px(b, ax + 6, ay - 13 - pLift, CyanHi);
                Px(b, ax + 4, ay - 7 - pLift, YellowNote);
                DrawPixelText(b, "+1 COMMIT", FontSmall, ax + 4, vy - 10, RimCol[4], true);
            }
            DrawSubtitle(b, sx, sy, sw, sh, "TURNO DA NOITE // CUIDANDO DOS COMMITS", TopCol[4]);
        }
        // ----- ACT 2 (18..35): Novo Commit Desce no Cabo + Pausa pro Café -----
        else if (f <= 35)
        {
            int destX = Math.Max(sx + 16, bx - 17);
            int prevX = Math.Max(sx + 14, ax - 16);
            int vx = (f < 23) ? prevX + (destX - prevX) * (f - 18) / 5 : destX;
            int vy = by2 - 26;
            int dir = (destX >= prevX) ? 1 : -1;

            if (f < 24)
            {
                // Glowing Commit Cube Descending on Cable
                int dropY = sy + 12 + (f - 18) * (by2 - 12 - (sy + 12)) / 6;
                Line(b, bx + 4, sy, bx + 4, dropY, Cyan);
                Fill(b, bx, dropY, 8, 8, TopCol[4]);
                Rect(b, bx, dropY, 8, 8, RimCol[4]);
            }
            bool sipping = (f >= 26);
            DrawVico(b, vx, vy, sipping ? 0 : dir, (f < 23) ? f % 4 : (f / 2), sipping ? 1 : 0, false, sipping);
            if (sipping)
            {
                int lblX = Math.Min(sx + sw - 48, Math.Max(sx + 46, vx + 9));
                DrawPixelText(b, "PAUSA PRO CAFÉ", FontSmall, lblX, vy - 12, White, true);
            }
            DrawSubtitle(b, sx, sy, sw, sh, "DEPLOY NO AR // HORA DO EXPRESSO", Amber);
        }
        // ----- ACT 3 (36..51): Refletor Despenca do Céu + Câmera Secreta! -----
        else if (f <= 51)
        {
            int crashX = sx + 108, crashY = sy + 96;
            int curY = (f < 39) ? sy + 10 + (f - 36) * (crashY - (sy + 10)) / 3 : crashY;
            Line(b, crashX + 4, sy, crashX + 4, sy + 28, SilverDark); // snapped cable dangling!
            Fill(b, crashX, curY, 9, 6, SilverMid);
            Fill(b, crashX + 2, curY + 1, 5, 4, YellowNote);
            if (f >= 39 && f <= 45)
            {
                Px(b, crashX - 3, crashY - 3, YellowNote);
                Px(b, crashX + 11, crashY - 4, CyanHi);
                DrawPixelText(b, "CRASH!", FontSmall, crashX + 5, crashY - 14, YellowNote, true);
            }
            int vx = sx + 78, vy = sy + 76;
            DrawVico(b, vx, vy, 1, 0, 2, false, false);
            DrawPixelText(b, "?!", FontMed, vx + 9, vy - 12, Red, true);
            DrawSubtitle(b, sx, sy, sw, sh, "PERAÍ... O CÉU É UM ESTÚDIO DE TV?!", Red);
        }
        // ----- ACT 4 (52..60): Ele Olha Pra Você e Vem Até a Tela -----
        else if (f <= 60)
        {
            int vx = sx + 82, vy = sy + 78 + (f - 52) * 2;
            DrawVico(b, vx, vy, 0, f % 4, 3, false, false);
            DrawSubtitle(b, sx, sy, sw, sh, "TEM ALGUÉM ME OLHANDO PELO VIDRO...", Red);
        }
        // ----- ACT 5 (61..72): Close-Up no Vidro + TOC TOC + Post-it -----
        else
        {
            bool knock = (f >= 62 && f <= 65);
            bool note = (f >= 66);
            DrawCloseUp(b, sx, sy, sw, sh, knock, note, f);
            DrawSubtitle(b, sx, sy, sw, sh, "CONFIRA OS PROJETOS LOGO ABAIXO ↓", YellowNote);
        }

        // Top Broadcast OSD
        FillCircle(b, sx + 9, sy + 8, 2, (f % 4 < 2) ? Red : C("#5a1d1d"));
        DrawPixelText(b, "REC", FontSmall, sx + 14, sy + 2, Red, false);
        DrawPixelText(b, "COMMITS: " + Total, FontSmall, sx + sw - 64, sy + 2, RimCol[4], false);

        ApplyCrtGlass(b, sx, sy, sw, sh);
        return Upscale(b);
    }

    static void DrawSubtitle(Bitmap b, int sx, int sy, int sw, int sh, string text, Color col)
    {
        int by = sy + sh - 17;
        Fill(b, sx + 4, by, sw - 8, 14, C("#080c12"));
        Rect(b, sx + 4, by, sw - 8, 14, SilverDark);
        DrawPixelText(b, text, FontSmall, sx + sw / 2, by + 1, col, true);
    }

    static void ApplyCrtGlass(Bitmap b, int sx, int sy, int sw, int sh)
    {
        // Subtle CRT Scanlines
        for (int y = sy; y < sy + sh; y += 2)
        {
            for (int x = sx; x < sx + sw; x++)
            {
                Color c = b.GetPixel(x, y);
                b.SetPixel(x, y, Color.FromArgb(255, (int)(c.R * 0.88), (int)(c.G * 0.88), (int)(c.B * 0.88)));
            }
        }

        // Curved Glass Reflection Glare (top-left diagonal sheen)
        for (int i = 0; i < 14; i++)
        {
            int gx = sx + 5 + i, gy = sy + 18 - i;
            if (gy >= sy + 4)
            {
                Color c = b.GetPixel(gx, gy);
                b.SetPixel(gx, gy, Color.FromArgb(255, Math.Min(255, c.R + 28), Math.Min(255, c.G + 32), Math.Min(255, c.B + 38)));
            }
        }

        // Rounded CRT Tube Mask Corners
        int[,] mask = {
            {0,0},{1,0},{2,0},{0,1},{1,1},{0,2},
            {sw-1,0},{sw-2,0},{sw-3,0},{sw-1,1},{sw-2,1},{sw-1,2},
            {0,sh-1},{1,sh-1},{2,sh-1},{0,sh-2},{1,sh-2},{0,sh-3},
            {sw-1,sh-1},{sw-2,sh-1},{sw-3,sh-1},{sw-1,sh-2},{sw-2,sh-2},{sw-1,sh-3}
        };
        for (int i = 0; i < mask.GetLength(0); i++)
            Px(b, sx + mask[i,0], sy + mask[i,1], BezelInner);
    }

    static Bitmap Upscale(Bitmap src)
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

    public static void Generate(string ttfPath, int[] levels, int total, string gifPath, string previewDir)
    {
        InitFonts(ttfPath);
        Levels = levels; Total = total; ChooseTargets();
        const int N = 76;
        int[] delays = new int[N];
        GifBitmapEncoder enc = new GifBitmapEncoder();
        for (int f = 0; f < N; f++)
        {
            delays[f] = (f == 15 || f == 33 || f == 48 || f == 59) ? 24 : (f >= 67 && f <= 72) ? 32 : 12;
            using (Bitmap bmp = RenderFrame(f))
            {
                if (!string.IsNullOrEmpty(previewDir) && (f == 11 || f == 29 || f == 42 || f == 64 || f == 69 || f == 74))
                    bmp.Save(Path.Combine(previewDir, "tv_" + f.ToString("D2") + ".png"), ImageFormat.Png);
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
[TrumanTvStudio]::Generate($fontPath, $levels, $total, $OutPath, $PreviewDir)
Write-Output "GIF gerado: $OutPath ($((Get-Item $OutPath).Length) bytes)"
