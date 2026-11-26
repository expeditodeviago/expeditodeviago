# Pipeline completo do Perfil PRAGMATA // EXP.DEV:
# 1. Busca os 371 dias reais de commits do GitHub
# 2. Renderiza assets/pragmata-hero.png (1600x500 HD com Diana, Hugh e Domo Lunar)
# 3. Renderiza assets/commit-game.svg (Simulacao 60fps Pragmata Lunafilament sobre os commits reais)
# 4. Renderiza assets/btn-play.svg, assets/stack-hud.svg e assets/btn-*.svg
# 5. Atualiza docs/commits-data.js para o jogo 100% INTERATIVO no GitHub Pages!
param(
    [string]$User = "expeditodeviago"
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "assets"
$docsDir = Join-Path $root "docs"
$designDir = Join-Path $root "design"
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType Directory -Force $docsDir | Out-Null
New-Item -ItemType Directory -Force $designDir | Out-Null

# Garantir que as imagens base oficiais estejam salvas em design/ para o GitHub Actions
$sc = "C:\Users\OPERACIONAL\.gemini\antigravity\brain\d8ad4fb9-3b91-4a1a-a91b-a1414df0742c\scratch\pragmata"
$domeImg = Join-Path $designDir "pragmata-dome.jpg"
$charsImg = Join-Path $designDir "pragmata-chars.png"
if ((Test-Path (Join-Path $sc "shot2.jpg")) -and -not (Test-Path $domeImg)) {
    Copy-Item (Join-Path $sc "shot2.jpg") $domeImg -Force
}
if ((Test-Path (Join-Path $sc "bg.jpg")) -and -not (Test-Path $charsImg)) {
    Copy-Item (Join-Path $sc "bg.jpg") $charsImg -Force
}
Copy-Item $domeImg (Join-Path $docsDir "lunar-bg.jpg") -Force

# Limpar assets antigos antes de regerar
Get-ChildItem -Path $out -File -ErrorAction SilentlyContinue | Remove-Item -Force

# ---------- 1. Buscar calendario completo (53 semanas) e metricas reais ----------
$pubRepos = 14
try {
    $u = Invoke-RestMethod "https://api.github.com/users/$User"
    if ($u.public_repos) { $pubRepos = [int]$u.public_repos }
} catch {}

$html = (Invoke-WebRequest -UseBasicParsing "https://github.com/users/$User/contributions").Content
$cellMap = @{}
foreach ($m in [regex]::Matches($html, 'data-date="(\d{4}-\d{2}-\d{2})"[^>]*?data-level="(\d)"')) {
    $cellMap[$m.Groups[1].Value] = [int]$m.Groups[2].Value
}
if ($cellMap.Count -eq 0) { throw "Falha ao ler contribuicoes de $User" }

$totalMatch = [regex]::Match($html, '([\d,\.]+)\s+contributions?\s+in the last year')
$totalContribs = if ($totalMatch.Success) { [int]($totalMatch.Groups[1].Value -replace '[,\.]', '') } else { 89 }

$WEEKS = 53
$sortedDates = $cellMap.Keys | Sort-Object
$lastDate = [datetime]::ParseExact(($sortedDates | Select-Object -Last 1), "yyyy-MM-dd", $null)
$lastSunday = $lastDate.AddDays(-[int]$lastDate.DayOfWeek)
$firstSunday = $lastSunday.AddDays(-7 * ($WEEKS - 1))

$levels = New-Object int[] ($WEEKS * 7)
$monthLabels = New-Object System.Collections.Generic.List[string]
$monthCols = New-Object System.Collections.Generic.List[int]
$ptMonths = @("", "Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez")
$prevMonth = -1

$jsCells = New-Object System.Collections.Generic.List[string]
$jsMonths = New-Object System.Collections.Generic.List[string]

for ($w = 0; $w -lt $WEEKS; $w++) {
    $weekStart = $firstSunday.AddDays($w * 7)
    if ($weekStart.Month -ne $prevMonth) {
        if ($monthCols.Count -eq 0 -or ($w - $monthCols[$monthCols.Count - 1]) -ge 3) {
            $mName = $ptMonths[$weekStart.Month]
            $monthLabels.Add($mName)
            $monthCols.Add($w)
            $jsMonths.Add("{`"name`":`"$mName`",`"col`":$w}")
        }
        $prevMonth = $weekStart.Month
    }
    for ($d = 0; $d -lt 7; $d++) {
        $dt = $weekStart.AddDays($d)
        $key = $dt.ToString("yyyy-MM-dd")
        $lv = if ($dt -gt $lastDate) { -1 } elseif ($cellMap.ContainsKey($key)) { $cellMap[$key] } else { 0 }
        $levels[$w * 7 + $d] = $lv
        $jsCells.Add("{`"w`":$w,`"d`":$d,`"date`":`"$key`",`"level`":$lv}")
    }
}

# Exportar docs/commits-data.js para o Jogo Interativo Web!
$commitsJs = "window.COMMIT_CALENDAR = { total: $totalContribs, repos: $pubRepos, months: [$($jsMonths -join ',')], cells: [$($jsCells -join ',')] };`n"
[IO.File]::WriteAllText((Join-Path $docsDir "commits-data.js"), $commitsJs, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  docs/commits-data.js ($totalContribs commits)"

# ---------- 2. Motor C# Unificado (Hero Banner HD + Diana/Hugh Commit Breaker SVG) ----------
$cs = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Globalization;
using System.IO;
using System.Text;

public class PragmataSuiteBuilder
{
    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
    static string F(double v) { return v.ToString("0.##", Inv); }
    static string P(double pct) { return Math.Max(0, Math.Min(100, pct)).ToString("0.##", Inv) + "%"; }

    // ==================== A. HERO BANNER 1600x500 ====================
    public static void BuildHeroBanner(string domePath, string charsPath, string outPath, int repos, int contribs)
    {
        int W = 1600, H = 500;
        using (Bitmap canvas = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        using (Graphics g = Graphics.FromImage(canvas))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

            using (Bitmap dome = new Bitmap(domePath))
            {
                Rectangle srcRect = new Rectangle(0, 0, dome.Width, (int)(dome.Width * ((double)H / W)));
                g.DrawImage(dome, new Rectangle(0, 0, W, H), srcRect, GraphicsUnit.Pixel);
            }

            using (LinearGradientBrush darkGrad = new LinearGradientBrush(
                new Rectangle(0, 0, W, H), Color.FromArgb(245, 8, 12, 21), Color.FromArgb(130, 10, 18, 32), 0f))
            {
                ColorBlend cb = new ColorBlend();
                cb.Positions = new float[] { 0f, 0.45f, 0.72f, 1f };
                cb.Colors = new Color[] {
                    Color.FromArgb(246, 9, 13, 22),
                    Color.FromArgb(226, 10, 16, 27),
                    Color.FromArgb(148, 12, 22, 38),
                    Color.FromArgb(165, 8, 13, 22)
                };
                darkGrad.InterpolationColors = cb;
                g.FillRectangle(darkGrad, 0, 0, W, H);
            }

            // Lunafilament Tactical Grid on Left
            using (Pen gridPen = new Pen(Color.FromArgb(18, 56, 189, 248), 1f))
            {
                for (int x = 48; x < 760; x += 48) g.DrawLine(gridPen, x, 0, x, H);
                for (int y = 32; y < H; y += 48) g.DrawLine(gridPen, 0, y, 760, y);
            }

            // Cyan Halo Behind Diana & Hugh
            using (GraphicsPath gp = new GraphicsPath())
            {
                gp.AddEllipse(920, -60, 700, 620);
                using (PathGradientBrush pgb = new PathGradientBrush(gp))
                {
                    pgb.CenterColor = Color.FromArgb(82, 56, 189, 248);
                    pgb.SurroundColors = new Color[] { Color.FromArgb(0, 56, 189, 248) };
                    g.FillPath(pgb, gp);
                }
            }

            // Render Diana & Hugh Cleanly Framed on Right (skipping 6px border so ZERO vertical seam!)
            using (Bitmap chars = new Bitmap(charsPath))
            {
                int cropX = 8;
                int cropW = chars.Width - 16;
                int cropH = (int)(chars.Height * 0.80);
                int targetH = 488;
                int targetW = (int)(cropW * ((double)targetH / cropH));
                int drawX = W - targetW + 128; // shifted right so Diana's hand frames beside the pods!
                int drawY = H - targetH + 8;
                g.DrawImage(chars, new Rectangle(drawX, drawY, targetW, targetH),
                    new Rectangle(cropX, 0, cropW, cropH), GraphicsUnit.Pixel);
            }

            // Seamless Bottom Vignette into GitHub #0d1117
            using (LinearGradientBrush botFade = new LinearGradientBrush(
                new Rectangle(0, H - 68, W, 68), Color.FromArgb(0, 13, 17, 23), Color.FromArgb(248, 13, 17, 23), 90f))
            {
                g.FillRectangle(botFade, 0, H - 68, W, 68);
            }

            Color cyan = Color.FromArgb(255, 56, 189, 248);
            Color emerald = Color.FromArgb(255, 57, 211, 83);
            Color gold = Color.FromArgb(255, 240, 180, 41);
            Color white = Color.FromArgb(255, 240, 246, 252);
            Color muted = Color.FromArgb(220, 148, 163, 184);

            using (Pen framePen = new Pen(Color.FromArgb(145, 38, 54, 74), 2f))
                DrawRoundRect(g, framePen, 2, 2, W - 4, H - 4, 20);

            using (Pen cPen = new Pen(cyan, 3f))
            {
                g.DrawLine(cPen, 26, 26, 66, 26); g.DrawLine(cPen, 26, 26, 26, 66);
                g.DrawLine(cPen, 26, H - 26, 66, H - 26); g.DrawLine(cPen, 26, H - 26, 26, H - 66);
                g.DrawLine(cPen, W - 26, 26, W - 66, 26); g.DrawLine(cPen, W - 26, 26, W - 26, 66);
            }

            // Status Pill
            using (SolidBrush pillBg = new SolidBrush(Color.FromArgb(195, 13, 21, 38)))
            using (Pen pillPen = new Pen(Color.FromArgb(145, 56, 189, 248), 1.5f))
            {
                FillRoundRect(g, pillBg, 58, 52, 412, 36, 18);
                DrawRoundRect(g, pillPen, 58, 52, 412, 36, 18);
            }
            using (SolidBrush dotBr = new SolidBrush(emerald))
                g.FillEllipse(dotBr, 76, 64, 11, 11);
            using (Font fMonoSm = new Font("Consolas", 13f, FontStyle.Bold, GraphicsUnit.Pixel))
            using (SolidBrush cyanBr = new SolidBrush(cyan))
                g.DrawString("PRAGMATA  //  LUNAFILAMENT OS  ·  EXP.DEV", fMonoSm, cyanBr, 98, 62);

            // Title
            using (Font fTitle = new Font("Segoe UI", 66f, FontStyle.Bold, GraphicsUnit.Pixel))
            using (SolidBrush whiteBr = new SolidBrush(white))
            using (SolidBrush shBr = new SolidBrush(Color.FromArgb(160, 0, 0, 0)))
            {
                g.DrawString("IAGO EXPEDITO", fTitle, shBr, 58, 112);
                g.DrawString("IAGO EXPEDITO", fTitle, whiteBr, 54, 108);
            }

            using (SolidBrush barBr = new SolidBrush(cyan))
                g.FillRectangle(barBr, 60, 200, 5, 48);

            using (Font fRole = new Font("Segoe UI Semibold", 21f, FontStyle.Bold, GraphicsUnit.Pixel))
            using (Font fSub = new Font("Segoe UI", 16f, FontStyle.Regular, GraphicsUnit.Pixel))
            using (SolidBrush cyanBr = new SolidBrush(cyan))
            using (SolidBrush mutBr = new SolidBrush(muted))
            {
                g.DrawString("PRODUCT ARCHITECT & SOFTWARE ENGINEER", fRole, cyanBr, 78, 197);
                g.DrawString("Arquitetura de Produto  ·  IA Generativa & Dados  ·  Sistemas Escaláveis", fSub, mutBr, 78, 227);
            }

            // Compact Pods positioned cleanly to the left of Diana's hand!
            DrawPod(g, 58, 294, 184, 84, repos.ToString(), "REPOSITÓRIOS", cyan);
            DrawPod(g, 254, 294, 184, 84, contribs.ToString(), "COMMITS NO ANO", emerald);
            DrawPod(g, 450, 294, 214, 84, "JOGÁVEL", "CLIQUE NA GRADE ▼", gold);

            using (Font fTiny = new Font("Consolas", 11.5f, FontStyle.Regular, GraphicsUnit.Pixel))
            using (SolidBrush dimBr = new SolidBrush(Color.FromArgb(165, 148, 163, 184)))
            {
                g.DrawString("DIANA HACKING MATRIX CONNECTED  ·  CRADLE STATION 04  ·  GITHUB.COM/EXPEDITODEVIAGO", fTiny, dimBr, 60, 412);
            }

            canvas.Save(outPath, ImageFormat.Png);
        }
    }

    static void DrawPod(Graphics g, int x, int y, int w, int h, string val, string label, Color accent)
    {
        using (SolidBrush bg = new SolidBrush(Color.FromArgb(205, 11, 17, 29)))
        using (Pen border = new Pen(Color.FromArgb(120, accent.R, accent.G, accent.B), 1.5f))
        {
            FillRoundRect(g, bg, x, y, w, h, 12);
            DrawRoundRect(g, border, x, y, w, h, 12);
        }
        using (SolidBrush topLine = new SolidBrush(accent))
            g.FillRectangle(topLine, x + 16, y, 40, 3);

        using (Font fVal = new Font("Segoe UI", 26f, FontStyle.Bold, GraphicsUnit.Pixel))
        using (Font fLbl = new Font("Consolas", 11.5f, FontStyle.Bold, GraphicsUnit.Pixel))
        using (SolidBrush valBr = new SolidBrush(Color.FromArgb(255, 248, 250, 252)))
        using (SolidBrush lblBr = new SolidBrush(accent))
        {
            g.DrawString(val, fVal, valBr, x + 16, y + 14);
            g.DrawString(label, fLbl, lblBr, x + 18, y + 54);
        }
    }

    static GraphicsPath RoundPath(int x, int y, int w, int h, int r)
    {
        int d = r * 2;
        GraphicsPath gp = new GraphicsPath();
        gp.AddArc(x, y, d, d, 180, 90);
        gp.AddArc(x + w - d, y, d, d, 270, 90);
        gp.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        gp.AddArc(x, y + h - d, d, d, 90, 90);
        gp.CloseFigure();
        return gp;
    }
    static void FillRoundRect(Graphics g, Brush b, int x, int y, int w, int h, int r) { using (GraphicsPath gp = RoundPath(x, y, w, h, r)) g.FillPath(b, gp); }
    static void DrawRoundRect(Graphics g, Pen p, int x, int y, int w, int h, int r) { using (GraphicsPath gp = RoundPath(x, y, w, h, r)) g.DrawPath(p, gp); }

    // ==================== B. PRAGMATA DIANA HACKING + BREAKER SVG ====================
    const int SW = 880, SH = 314, WEEKS = 53;
    const double GX0 = 48.0, GY0 = 70.0, CELL = 12.0, PITCH = 15.0;
    const double LEFT_WALL = 46.0, RIGHT_WALL = 846.0, TOP_WALL = 66.0, PADDLE_Y = 268.0;
    const double PADDLE_W = 86.0, BALL_R = 4.5, TOTAL_DUR = 22.0;

    class Brick
    {
        public int Id, Week, Day, Level;
        public double X, Y, CX, CY, HitTime = -1;
        public bool Alive = true, LaserKill = false;
    }
    struct KeyPt { public double T, X, Y; public KeyPt(double t, double x, double y) { T = t; X = x; Y = y; } }

    static string LevelColor(int lvl)
    {
        switch (lvl)
        {
            case 1: return "#0e4429";
            case 2: return "#006d32";
            case 3: return "#26a641";
            case 4: return "#39d353";
            default: return "#131b28";
        }
    }

    public static string BuildPragmataGameSvg(int[] levels, string[] mNames, int[] mCols, int totalContribs)
    {
        List<Brick> bricks = new List<Brick>();
        for (int w = 0; w < WEEKS; w++)
        {
            for (int d = 0; d < 7; d++)
            {
                int lvl = levels[w * 7 + d];
                if (lvl > 0)
                {
                    Brick br = new Brick();
                    br.Id = bricks.Count; br.Week = w; br.Day = d; br.Level = lvl;
                    br.X = GX0 + w * PITCH; br.Y = GY0 + d * PITCH;
                    br.CX = br.X + CELL / 2.0; br.CY = br.Y + CELL / 2.0;
                    bricks.Add(br);
                }
            }
        }
        if (bricks.Count == 0)
        {
            int[] dc = { 8, 16, 24, 32, 40, 48 };
            for (int i = 0; i < dc.Length; i++)
            {
                Brick br = new Brick();
                br.Id = i; br.Week = dc[i]; br.Day = (i * 2) % 7; br.Level = 4;
                br.X = GX0 + br.Week * PITCH; br.Y = GY0 + br.Day * PITCH;
                br.CX = br.X + 6; br.CY = br.Y + 6;
                bricks.Add(br);
            }
        }

        // Diana's Hacking Constellation Lines (connect nearby commit nodes with glowing cyan Lunafilament circuit!)
        StringBuilder dianaLines = new StringBuilder();
        for (int i = 0; i < bricks.Count - 1; i++)
        {
            Brick a = bricks[i], b = bricks[i + 1];
            if (Math.Abs(b.Week - a.Week) <= 10)
            {
                dianaLines.AppendFormat(Inv,
                    "<line x1=\"{0}\" y1=\"{1}\" x2=\"{2}\" y2=\"{3}\" stroke=\"#38bdf8\" stroke-width=\"1\" stroke-dasharray=\"3 3\" opacity=\"0.32\"/>\n",
                    F(a.CX), F(a.CY), F(b.CX), F(b.CY));
            }
        }

        double startX = Math.Max(LEFT_WALL + 50, Math.Min(RIGHT_WALL - 50, bricks[bricks.Count / 3].CX));
        List<KeyPt> ballPts = new List<KeyPt>();
        List<KeyPt> padPts = new List<KeyPt>();

        int targetBallKills = Math.Max(1, (int)Math.Ceiling(bricks.Count * 0.58));
        int ballKills = 0;
        double bx = startX, by = PADDLE_Y - BALL_R - 1;
        Brick firstTarget = bricks[bricks.Count / 3];
        double ang0 = Math.Atan2(firstTarget.CY - by, firstTarget.CX - bx);
        double speed = 345.0;
        double vx = Math.Cos(ang0) * speed, vy = Math.Sin(ang0) * speed;
        if (vy > -180) { vy = -240; vx = (vx >= 0 ? 1 : -1) * Math.Sqrt(speed * speed - vy * vy); }

        ballPts.Add(new KeyPt(0.0, bx, by));
        padPts.Add(new KeyPt(0.0, startX, PADDLE_Y));
        ballPts.Add(new KeyPt(0.35, bx, by));
        padPts.Add(new KeyPt(0.35, startX, PADDLE_Y));
        double t = 0.35, dt = 0.005;
        Brick powerUpSource = bricks[0];

        while (t < 13.0 && ballKills < targetBallKills)
        {
            double nx = bx + vx * dt, ny = by + vy * dt;
            t += dt;
            bool bounced = false;
            if (nx - BALL_R <= LEFT_WALL) { nx = LEFT_WALL + BALL_R; vx = Math.Abs(vx); bounced = true; }
            else if (nx + BALL_R >= RIGHT_WALL) { nx = RIGHT_WALL - BALL_R; vx = -Math.Abs(vx); bounced = true; }
            if (ny - BALL_R <= TOP_WALL) { ny = TOP_WALL + BALL_R; vy = Math.Abs(vy); bounced = true; }

            for (int i = 0; i < bricks.Count; i++)
            {
                Brick br = bricks[i];
                if (!br.Alive) continue;
                if (nx + BALL_R >= br.X && nx - BALL_R <= br.X + CELL &&
                    ny + BALL_R >= br.Y && ny - BALL_R <= br.Y + CELL)
                {
                    br.Alive = false; br.HitTime = t; br.LaserKill = false;
                    powerUpSource = br; ballKills++;
                    double ox = Math.Min(nx + BALL_R - br.X, (br.X + CELL) - (nx - BALL_R));
                    double oy = Math.Min(ny + BALL_R - br.Y, (br.Y + CELL) - (ny - BALL_R));
                    if (ox < oy) vx = -vx; else vy = -vy;
                    bounced = true;
                    break;
                }
            }

            if (vy > 0 && ny + BALL_R >= PADDLE_Y)
            {
                ny = PADDLE_Y - BALL_R;
                double padX = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, nx));
                padPts.Add(new KeyPt(t, padX, PADDLE_Y));
                if (ballKills >= targetBallKills || t >= 12.0)
                {
                    bx = nx; by = ny; ballPts.Add(new KeyPt(t, bx, by)); break;
                }
                Brick aim = null; double best = 1e9;
                for (int i = 0; i < bricks.Count; i++)
                {
                    if (!bricks[i].Alive) continue;
                    double d = Math.Abs(bricks[i].CX - nx) + bricks[i].Day * 8;
                    if (d < best) { best = d; aim = bricks[i]; }
                }
                if (aim != null)
                {
                    double ang = Math.Max(-2.45, Math.Min(-0.69, Math.Atan2(aim.CY - ny, aim.CX - nx)));
                    vx = Math.Cos(ang) * speed; vy = Math.Sin(ang) * speed;
                }
                else vy = -Math.Abs(vy);
                bounced = true;
            }
            bx = nx; by = ny;
            if (bounced) ballPts.Add(new KeyPt(t, bx, by));
        }

        if (by < PADDLE_Y - BALL_R - 2)
        {
            t += Math.Max(0.25, (PADDLE_Y - BALL_R - by) / 280.0);
            by = PADDLE_Y - BALL_R;
            bx = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, bx));
            ballPts.Add(new KeyPt(t, bx, by));
            padPts.Add(new KeyPt(t, bx, PADDLE_Y));
        }

        double phase1End = t;
        double capStartT = Math.Max(0.5, powerUpSource.HitTime > 0 ? powerUpSource.HitTime : phase1End - 0.8);
        double capCatchX = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, powerUpSource.CX));
        double capCatchT = Math.Max(phase1End + 0.55, capStartT + 0.95);

        padPts.Add(new KeyPt(capCatchT, capCatchX, PADDLE_Y));
        ballPts.Add(new KeyPt(capCatchT, capCatchX, PADDLE_Y - BALL_R));

        List<Brick> remaining = new List<Brick>();
        for (int i = 0; i < bricks.Count; i++) if (bricks[i].Alive) remaining.Add(bricks[i]);
        remaining.Sort((a, b) => a.X.CompareTo(b.X));

        double laserStartT = capCatchT + 0.25, laserEndT = 18.4;
        List<KeyPt> laserShots = new List<KeyPt>();
        for (int i = 0; i < remaining.Count; i++)
        {
            double frac = (remaining.Count == 1) ? 0.5 : (double)i / (remaining.Count - 1);
            double shotT = laserStartT + frac * (laserEndT - laserStartT);
            Brick rb = remaining[i];
            rb.Alive = false; rb.HitTime = shotT + 0.08; rb.LaserKill = true;
            double px = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, rb.CX));
            padPts.Add(new KeyPt(shotT, px, PADDLE_Y));
            ballPts.Add(new KeyPt(shotT, px, PADDLE_Y - BALL_R));
            laserShots.Add(new KeyPt(shotT, rb.CX, rb.CY));
        }

        padPts.Add(new KeyPt(19.6, 440, PADDLE_Y)); ballPts.Add(new KeyPt(19.6, 440, PADDLE_Y - BALL_R));
        padPts.Add(new KeyPt(21.6, startX, PADDLE_Y)); ballPts.Add(new KeyPt(21.6, startX, PADDLE_Y - BALL_R));
        padPts.Add(new KeyPt(TOTAL_DUR, startX, PADDLE_Y)); ballPts.Add(new KeyPt(TOTAL_DUR, startX, PADDLE_Y - BALL_R));

        StringBuilder css = new StringBuilder();
        css.AppendLine(".txt { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }");
        css.AppendLine(".mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }");

        css.Append("@keyframes ball { ");
        for (int i = 0; i < ballPts.Count; i++)
        {
            if (i > 0 && ballPts[i].T <= ballPts[i - 1].T + 0.002) continue;
            css.AppendFormat(Inv, "{0} {{ transform: translate({1}px, {2}px); }} ", P(ballPts[i].T / TOTAL_DUR * 100.0), F(ballPts[i].X), F(ballPts[i].Y));
        }
        css.AppendLine("}");
        css.AppendLine("#ball { animation: ball 22s linear infinite; } #ballT1 { animation: ball 22s linear -0.045s infinite; } #ballT2 { animation: ball 22s linear -0.09s infinite; }");
        css.AppendFormat(Inv, "@keyframes ballVis {{ 0%, {0} {{ opacity: 1; }} {1}, {2} {{ opacity: 0; }} {3}, 100% {{ opacity: 1; }} }}\n",
            P((capCatchT - 0.05) / TOTAL_DUR * 100.0), P(capCatchT / TOTAL_DUR * 100.0), P(21.2 / TOTAL_DUR * 100.0), P(21.5 / TOTAL_DUR * 100.0));
        css.AppendLine("#ballDot, #ballTrail1, #ballTrail2 { animation: ballVis 22s linear infinite; }");

        css.Append("@keyframes pad { ");
        for (int i = 0; i < padPts.Count; i++)
        {
            if (i > 0 && padPts[i].T <= padPts[i - 1].T + 0.005) continue;
            css.AppendFormat(Inv, "{0} {{ transform: translate({1}px, {2}px); }} ", P(padPts[i].T / TOTAL_DUR * 100.0), F(padPts[i].X), F(padPts[i].Y));
        }
        css.AppendLine("}");
        css.AppendLine("#paddle { animation: pad 22s linear infinite; }");
        css.AppendFormat(Inv, "@keyframes padLaser {{ 0%, {0} {{ opacity: 0; }} {1}, 85% {{ opacity: 1; }} 86.5%, 100% {{ opacity: 0; }} }}\n",
            P((capCatchT - 0.05) / TOTAL_DUR * 100.0), P(capCatchT / TOTAL_DUR * 100.0));
        css.AppendLine("#padOverdrive { animation: padLaser 22s linear infinite; }");

        css.AppendFormat(Inv,
            "@keyframes capDrop {{ 0%, {0} {{ opacity: 0; transform: translate({4}px, {5}px); }} {1} {{ opacity: 1; transform: translate({4}px, {5}px); }} {2} {{ opacity: 1; transform: translate({6}px, {7}px); }} {3}, 100% {{ opacity: 0; transform: translate({6}px, {7}px); }} }}\n",
            P((capStartT - 0.05) / TOTAL_DUR * 100.0), P(capStartT / TOTAL_DUR * 100.0), P((capCatchT - 0.02) / TOTAL_DUR * 100.0), P((capCatchT + 0.05) / TOTAL_DUR * 100.0),
            F(powerUpSource.CX), F(powerUpSource.CY), F(capCatchX), F(PADDLE_Y - 6));
        css.AppendLine("#capsule { animation: capDrop 22s linear infinite; }");

        StringBuilder gridSvg = new StringBuilder();
        StringBuilder fxSvg = new StringBuilder();
        for (int w = 0; w < WEEKS; w++)
        {
            for (int d = 0; d < 7; d++)
            {
                if (levels[w * 7 + d] < 0) continue;
                gridSvg.AppendFormat(Inv, "<rect x=\"{0}\" y=\"{1}\" width=\"12\" height=\"12\" rx=\"2.5\" fill=\"#121926\" stroke=\"#1e293b\" stroke-width=\"0.8\"/>\n",
                    F(GX0 + w * PITCH), F(GY0 + d * PITCH));
            }
        }

        for (int i = 0; i < bricks.Count; i++)
        {
            Brick br = bricks[i];
            string col = LevelColor(br.Level);
            double hitP = (br.HitTime / TOTAL_DUR) * 100.0;
            double respStartP = ((20.1 + (br.Week / 53.0) * 1.2) / TOTAL_DUR) * 100.0;

            css.AppendFormat(Inv,
                "@keyframes b{0} {{ 0%, {1} {{ opacity: 1; fill: {2}; }} {3} {{ opacity: 1; fill: #a5f3fc; }} {4}, {5} {{ opacity: 0; fill: {2}; }} {6}, 100% {{ opacity: 1; fill: {2}; }} }}\n",
                br.Id, P(hitP - 0.05), col, P(hitP + 0.35), P(hitP + 0.85), P(respStartP), P(respStartP + 0.9));

            gridSvg.AppendFormat(Inv,
                "<rect x=\"{0}\" y=\"{1}\" width=\"12\" height=\"12\" rx=\"2.5\" fill=\"{2}\" stroke=\"#38bdf8\" stroke-opacity=\"0.35\" stroke-width=\"0.8\" style=\"animation: b{3} 22s linear infinite;\"/>\n",
                F(br.X), F(br.Y), col, br.Id);

            string ringCol = br.LaserKill ? "#38bdf8" : "#7ee787";
            css.AppendFormat(Inv,
                "@keyframes r{0} {{ 0%, {1} {{ opacity: 0; transform: scale(0.5); }} {2} {{ opacity: 0.95; transform: scale(1); }} {3} {{ opacity: 0; transform: scale(3.5); }} 100% {{ opacity: 0; transform: scale(3.5); }} }}\n",
                br.Id, P(hitP - 0.05), P(hitP + 0.15), P(hitP + 1.5));
            fxSvg.AppendFormat(Inv,
                "<g transform=\"translate({0},{1})\"><circle cx=\"0\" cy=\"0\" r=\"5\" fill=\"none\" stroke=\"{2}\" stroke-width=\"1.5\" style=\"animation: r{3} 22s linear infinite;\"/></g>\n",
                F(br.CX), F(br.CY), ringCol, br.Id);
        }

        int stepLaser = Math.Max(1, laserShots.Count / 14);
        for (int i = 0; i < laserShots.Count; i += stepLaser)
        {
            KeyPt ls = laserShots[i];
            double lp0 = (ls.T / TOTAL_DUR) * 100.0;
            css.AppendFormat(Inv, "@keyframes lz{0} {{ 0%, {1} {{ opacity: 0; }} {2} {{ opacity: 0.95; }} {3}, 100% {{ opacity: 0; }} }}\n",
                i, P(lp0 - 0.1), P(lp0 + 0.2), P(lp0 + 0.95));
            fxSvg.AppendFormat(Inv,
                "<g style=\"animation: lz{0} 22s linear infinite;\"><line x1=\"{1}\" y1=\"{2}\" x2=\"{1}\" y2=\"{3}\" stroke=\"#38bdf8\" stroke-width=\"2.2\" stroke-linecap=\"round\"/><line x1=\"{4}\" y1=\"{2}\" x2=\"{4}\" y2=\"{3}\" stroke=\"#a5f3fc\" stroke-width=\"1.2\" stroke-linecap=\"round\"/></g>\n",
                i, F(ls.X - 10), F(PADDLE_Y - 2), F(ls.Y + 4), F(ls.X + 10));
        }

        css.AppendFormat(Inv, "@keyframes progFill {{ 0% {{ width: 0px; }} {0} {{ width: 88px; }} {1} {{ width: 146px; }} 91% {{ width: 146px; }} 96%, 100% {{ width: 0px; }} }}\n",
            P(phase1End / TOTAL_DUR * 100.0), P(laserEndT / TOTAL_DUR * 100.0));
        css.AppendLine("#progBar { animation: progFill 22s linear infinite; }");
        css.AppendLine("@keyframes stageBanner { 0%, 84% { opacity: 0; transform: translateY(6px); } 86%, 93% { opacity: 1; transform: translateY(0px); } 96%, 100% { opacity: 0; transform: translateY(-4px); } }");
        css.AppendLine("#stageClear { animation: stageBanner 22s ease-out infinite; }");
        css.AppendFormat(Inv,
            "@keyframes modeRic {{ 0%, {0} {{ opacity: 1; }} {1}, 96% {{ opacity: 0; }} 97%, 100% {{ opacity: 1; }} }}\n" +
            "@keyframes modeLas {{ 0%, {0} {{ opacity: 0; }} {1}, 84% {{ opacity: 1; }} 85%, 100% {{ opacity: 0; }} }}\n" +
            "@keyframes modeWin {{ 0%, 84% {{ opacity: 0; }} 85%, 96% {{ opacity: 1; }} 97%, 100% {{ opacity: 0; }} }}\n",
            P((capCatchT - 0.1) / TOTAL_DUR * 100.0), P(capCatchT / TOTAL_DUR * 100.0));
        css.AppendLine("#mRic { animation: modeRic 22s linear infinite; } #mLas { animation: modeLas 22s linear infinite; } #mWin { animation: modeWin 22s linear infinite; }");

        StringBuilder monthsSvg = new StringBuilder();
        for (int i = 0; i < mNames.Length; i++)
            monthsSvg.AppendFormat(Inv, "<text x=\"{0}\" y=\"60\" class=\"txt\" font-size=\"10.5\" fill=\"#94a3b8\">{1}</text>\n", F(GX0 + mCols[i] * PITCH), mNames[i]);

        StringBuilder svg = new StringBuilder();
        svg.AppendFormat(Inv, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{0}\" height=\"{1}\" viewBox=\"0 0 {0} {1}\">\n", SW, SH);
        svg.AppendLine("<defs><style>");
        svg.Append(css.ToString());
        svg.AppendLine("</style>");
        svg.AppendLine("<linearGradient id=\"padGrad\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\"><stop offset=\"0%\" stop-color=\"#0284c7\"/><stop offset=\"50%\" stop-color=\"#7ee787\"/><stop offset=\"100%\" stop-color=\"#0284c7\"/></linearGradient>");
        svg.AppendLine("<linearGradient id=\"padCyan\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\"><stop offset=\"0%\" stop-color=\"#38bdf8\"/><stop offset=\"50%\" stop-color=\"#ffffff\"/><stop offset=\"100%\" stop-color=\"#38bdf8\"/></linearGradient>");
        svg.AppendLine("<radialGradient id=\"ballGlow\" cx=\"50%\" cy=\"50%\" r=\"50%\"><stop offset=\"0%\" stop-color=\"#ffffff\"/><stop offset=\"45%\" stop-color=\"#38bdf8\"/><stop offset=\"100%\" stop-color=\"#38bdf8\" stop-opacity=\"0\"/></radialGradient>");
        svg.AppendLine("</defs>");

        // Pragmata Lunar Dark Glass Card + Cyan Brackets
        svg.AppendLine("<rect x=\"1\" y=\"1\" width=\"878\" height=\"312\" rx=\"12\" fill=\"#090e18\" stroke=\"#1e293b\" stroke-width=\"1.5\"/>");
        svg.AppendLine("<rect x=\"1\" y=\"1\" width=\"878\" height=\"40\" rx=\"12\" fill=\"#0f172a\"/>");
        svg.AppendLine("<rect x=\"1\" y=\"28\" width=\"878\" height=\"13\" fill=\"#0f172a\"/>");
        svg.AppendLine("<line x1=\"1\" y1=\"41\" x2=\"879\" y2=\"41\" stroke=\"#1e293b\" stroke-width=\"1\"/>");
        svg.AppendLine("<path d=\"M14 52 L14 46 L20 46 M866 52 L866 46 L860 46 M14 274 L14 280 L20 280 M866 274 L866 280 L860 280\" stroke=\"#38bdf8\" stroke-width=\"1.5\" fill=\"none\" opacity=\"0.7\"/>");

        // Header HUD
        svg.AppendLine("<text x=\"22\" y=\"25\" class=\"mono\" font-size=\"12\" font-weight=\"700\" fill=\"#38bdf8\" letter-spacing=\"1\">◈ DIANA // LUNAFILAMENT COMMIT MATRIX</text>");
        svg.AppendFormat(Inv, "<text x=\"316\" y=\"25\" class=\"txt\" font-size=\"11.5\" fill=\"#94a3b8\">·  {0} commits reais em simulação</text>\n", totalContribs);

        svg.AppendLine("<g transform=\"translate(510, 9)\">");
        svg.AppendLine("  <rect width=\"164\" height=\"23\" rx=\"11.5\" fill=\"#090e18\" stroke=\"#334155\"/>");
        svg.AppendLine("  <text id=\"mRic\" x=\"82\" y=\"15.5\" class=\"mono\" font-size=\"10.5\" font-weight=\"700\" fill=\"#39d353\" text-anchor=\"middle\">● ORBITAL BREAKER</text>");
        svg.AppendLine("  <text id=\"mLas\" x=\"82\" y=\"15.5\" class=\"mono\" font-size=\"10.5\" font-weight=\"700\" fill=\"#38bdf8\" text-anchor=\"middle\">⚡ DIANA OVERDRIVE</text>");
        svg.AppendLine("  <text id=\"mWin\" x=\"82\" y=\"15.5\" class=\"mono\" font-size=\"10.5\" font-weight=\"700\" fill=\"#f0b429\" text-anchor=\"middle\">★ HACK 100% CLEAR</text>");
        svg.AppendLine("</g>");

        svg.AppendLine("<rect x=\"694\" y=\"15\" width=\"146\" height=\"11\" rx=\"5.5\" fill=\"#090e18\" stroke=\"#334155\"/>");
        svg.AppendLine("<rect id=\"progBar\" x=\"694\" y=\"15\" width=\"0\" height=\"11\" rx=\"5.5\" fill=\"url(#padGrad)\"/>");

        svg.Append(monthsSvg.ToString());
        svg.AppendLine("<text x=\"18\" y=\"94\" class=\"txt\" font-size=\"10\" fill=\"#64748b\">Seg</text>");
        svg.AppendLine("<text x=\"18\" y=\"124\" class=\"txt\" font-size=\"10\" fill=\"#64748b\">Qua</text>");
        svg.AppendLine("<text x=\"18\" y=\"154\" class=\"txt\" font-size=\"10\" fill=\"#64748b\">Sex</text>");

        // Grid + Diana Constellation Circuit + Bricks
        svg.Append(gridSvg.ToString());
        svg.Append(dianaLines.ToString());

        svg.AppendLine("<line x1=\"46\" y1=\"276\" x2=\"846\" y2=\"276\" stroke=\"#1e293b\" stroke-width=\"1\" stroke-dasharray=\"4 4\"/>");
        svg.Append(fxSvg.ToString());

        svg.AppendLine("<g id=\"capsule\"><rect x=\"-16\" y=\"-7\" width=\"32\" height=\"14\" rx=\"7\" fill=\"#0284c7\" stroke=\"#a5f3fc\" stroke-width=\"1.2\"/><text x=\"0\" y=\"3.5\" class=\"mono\" font-size=\"9.5\" font-weight=\"700\" fill=\"#ffffff\" text-anchor=\"middle\">⚡LZR</text></g>");
        svg.AppendLine("<g id=\"ballT2\"><g id=\"ballTrail2\"><circle cx=\"0\" cy=\"0\" r=\"2.5\" fill=\"#38bdf8\" opacity=\"0.3\"/></g></g>");
        svg.AppendLine("<g id=\"ballT1\"><g id=\"ballTrail1\"><circle cx=\"0\" cy=\"0\" r=\"3.6\" fill=\"#a5f3fc\" opacity=\"0.55\"/></g></g>");
        svg.AppendLine("<g id=\"ball\"><g id=\"ballDot\"><circle cx=\"0\" cy=\"0\" r=\"10\" fill=\"url(#ballGlow)\"/><circle cx=\"0\" cy=\"0\" r=\"4.5\" fill=\"#ffffff\"/></g></g>");

        svg.AppendLine("<g id=\"paddle\"><rect x=\"-43\" y=\"0\" width=\"86\" height=\"9\" rx=\"4.5\" fill=\"url(#padGrad)\"/><rect id=\"padOverdrive\" x=\"-43\" y=\"0\" width=\"86\" height=\"9\" rx=\"4.5\" fill=\"url(#padCyan)\"/><rect x=\"-18\" y=\"2.5\" width=\"36\" height=\"4\" rx=\"2\" fill=\"#090e18\" opacity=\"0.6\"/></g>");

        svg.AppendLine("<g id=\"stageClear\"><rect x=\"250\" y=\"198\" width=\"380\" height=\"38\" rx=\"19\" fill=\"#0f172a\" stroke=\"#38bdf8\" stroke-width=\"1.5\"/><text x=\"440\" y=\"221\" class=\"mono\" font-size=\"12.5\" font-weight=\"700\" fill=\"#a5f3fc\" text-anchor=\"middle\" letter-spacing=\"1\">◈ CLIQUE AQUI PARA JOGAR VOCÊ MESMO! ↗</text></g>");

        svg.AppendLine("<text x=\"48\" y=\"299\" class=\"mono\" font-size=\"10.5\" fill=\"#38bdf8\">▶ CLIQUE NA GRADE PARA ABRIR O JOGO INTERATIVO (MOUSE / TECLADO)</text>");
        svg.AppendLine("<g transform=\"translate(728, 289)\"><text x=\"0\" y=\"10\" class=\"txt\" font-size=\"10.5\" fill=\"#64748b\">Menos</text><rect x=\"38\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#121926\" stroke=\"#1e293b\"/><rect x=\"51\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#0e4429\"/><rect x=\"64\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#006d32\"/><rect x=\"77\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#26a641\"/><rect x=\"90\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#39d353\"/><text x=\"105\" y=\"10\" class=\"txt\" font-size=\"10.5\" fill=\"#64748b\">Mais</text></g>");
        svg.AppendLine("</svg>");
        return svg.ToString();
    }
}
'@

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$heroOut = Join-Path $out "pragmata-hero.png"
[PragmataSuiteBuilder]::BuildHeroBanner($domeImg, $charsImg, $heroOut, $pubRepos, $totalContribs)
Write-Output "ok  pragmata-hero.png ($((Get-Item $heroOut).Length) bytes)"

$gameSvg = [PragmataSuiteBuilder]::BuildPragmataGameSvg($levels, $monthLabels.ToArray(), $monthCols.ToArray(), $totalContribs)
[IO.File]::WriteAllText((Join-Path $out "commit-game.svg"), $gameSvg, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  commit-game.svg"

# ---------- 3. BOTAO LARGO DE LANCAMENTO INTERATIVO (assets/btn-play.svg) ----------
$playBtn = @"
<svg xmlns="http://www.w3.org/2000/svg" width="880" height="54" viewBox="0 0 880 54">
  <defs>
    <style>
      .sans { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }
      .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
      .glow { animation: g 2s ease-in-out infinite; }
      @keyframes g { 0%, 100% { opacity: 0.85; } 50% { opacity: 1; } }
    </style>
    <linearGradient id="btnBg" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#0c192c"/>
      <stop offset="50%" stop-color="#0f2942"/>
      <stop offset="100%" stop-color="#0c192c"/>
    </linearGradient>
  </defs>
  <rect x="1" y="1" width="878" height="52" rx="10" fill="url(#btnBg)" stroke="#38bdf8" stroke-width="1.5" class="glow"/>
  <circle cx="34" cy="27" r="5" fill="#39d353"/>
  <text x="52" y="31" class="mono" font-size="13" font-weight="700" fill="#f0f6fc" letter-spacing="0.8">🎮 JOGAR AGORA NOS MEUS COMMITS REAIS (MODO BREAKER + MATRIZ DE HACKING DA DIANA)</text>
  <rect x="730" y="12" width="134" height="30" rx="6" fill="#38bdf8"/>
  <text x="797" y="31" class="mono" font-size="12" font-weight="800" fill="#090e18" text-anchor="middle">ABRIR JOGO ↗</text>
</svg>
"@
[IO.File]::WriteAllText((Join-Path $out "btn-play.svg"), $playBtn, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  btn-play.svg"

# ---------- 4. PAINEL HOLOGRAFICO PRAGMATA DE STACK (assets/stack-hud.svg) ----------
$stackSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="880" height="178" viewBox="0 0 880 178">
  <style>
    .sans { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
  </style>
  <rect x="1" y="1" width="878" height="176" rx="12" fill="#090e18" stroke="#1e293b" stroke-width="1.5"/>
  <path d="M14 26 L14 14 L26 14 M866 26 L866 14 L854 14 M14 152 L14 164 L26 164 M866 152 L866 164 L854 164" stroke="#38bdf8" stroke-width="1.5" fill="none" opacity="0.65"/>

  <g transform="translate(22, 22)">
    <rect width="200" height="134" rx="8" fill="#0f172a" stroke="#1e293b"/>
    <circle cx="18" cy="22" r="4" fill="#38bdf8"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#f0f6fc">LINGUAGENS</text>
    <line x1="14" y1="38" x2="186" y2="38" stroke="#1e293b"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#e2e8f0">TypeScript · JavaScript</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#e2e8f0">Python · Java</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#94a3b8">SQL · HTML5 · CSS3</text>
  </g>

  <g transform="translate(234, 22)">
    <rect width="200" height="134" rx="8" fill="#0f172a" stroke="#1e293b"/>
    <circle cx="18" cy="22" r="4" fill="#39d353"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#f0f6fc">FRONTEND &amp; UI</text>
    <line x1="14" y1="38" x2="186" y2="38" stroke="#1e293b"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#e2e8f0">React 19 · Next.js</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#e2e8f0">Tailwind CSS · Vite</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#94a3b8">Framer Motion · Recharts</text>
  </g>

  <g transform="translate(446, 22)">
    <rect width="200" height="134" rx="8" fill="#0f172a" stroke="#1e293b"/>
    <circle cx="18" cy="22" r="4" fill="#f0b429"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#f0f6fc">BACKEND &amp; DADOS</text>
    <line x1="14" y1="38" x2="186" y2="38" stroke="#1e293b"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#e2e8f0">FastAPI · Node.js</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#e2e8f0">Pandas · NumPy · Prisma</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#94a3b8">PostgreSQL · SQLite · Turso</text>
  </g>

  <g transform="translate(658, 22)">
    <rect width="200" height="134" rx="8" fill="#0f172a" stroke="#1e293b"/>
    <circle cx="18" cy="22" r="4" fill="#c084fc"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#f0f6fc">IA &amp; ARQUITETURA</text>
    <line x1="14" y1="38" x2="186" y2="38" stroke="#1e293b"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#e2e8f0">LLMs · Llama · Groq API</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#e2e8f0">OpenAI SDK · Web Speech</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#94a3b8">Product Arch · Vercel · Git</text>
  </g>
</svg>
"@
[IO.File]::WriteAllText((Join-Path $out "stack-hud.svg"), $stackSvg, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  stack-hud.svg"

function Save-Pill([string]$file, [string]$label, [string]$sub, [string]$accent) {
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="284" height="48" viewBox="0 0 284 48">
  <style>
    .sans { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
  </style>
  <rect x="1" y="1" width="282" height="46" rx="10" fill="#0f172a" stroke="#1e293b" stroke-width="1.4"/>
  <circle cx="22" cy="24" r="4.5" fill="$accent"/>
  <text x="36" y="28" class="sans" font-size="13" font-weight="700" fill="#f0f6fc">$label</text>
  <text x="266" y="28" class="mono" font-size="11" fill="#38bdf8" text-anchor="end">$sub ↗</text>
</svg>
"@
    [IO.File]::WriteAllText((Join-Path $out $file), $svg, (New-Object Text.UTF8Encoding($false)))
    Write-Output "ok  $file"
}

Save-Pill "btn-repos.svg"    "Explorar Repositórios" "$pubRepos projetos" "#39d353"
Save-Pill "btn-linkedin.svg" "LinkedIn"              "conectar"           "#38bdf8"
Save-Pill "btn-insta.svg"    "Instagram"             "@iagoexpedito"      "#c084fc"
