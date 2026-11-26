# Gera todas as artes vetoriais do perfil GitHub (Zero TV/Truman):
# 1. assets/hero-header.svg   — Header minimalista cyber-arcade
# 2. assets/commit-game.svg   — Jogo COMMIT BREAKER (fisica 2D real + power-up laser) nos 53x7 commits reais
# 3. assets/stack-hud.svg     — Painel limpo de arquitetura e stack
# 4. assets/btn-*.svg         — Pílulas modernas clicáveis (Repositórios, LinkedIn, Instagram)
param(
    [string]$User = "expeditodeviago"
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "assets"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# Remover TODOS os arquivos antigos do modelo anterior
Get-ChildItem -Path $out -File -ErrorAction SilentlyContinue | Remove-Item -Force

# ---------- 1. Buscar calendario completo (53 semanas) e dados reais do GitHub ----------
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
$totalContribs = if ($totalMatch.Success) { [int]($totalMatch.Groups[1].Value -replace '[,\.]', '') } else { 88 }

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

for ($w = 0; $w -lt $WEEKS; $w++) {
    $weekStart = $firstSunday.AddDays($w * 7)
    if ($weekStart.Month -ne $prevMonth) {
        if ($monthCols.Count -eq 0 -or ($w - $monthCols[$monthCols.Count - 1]) -ge 3) {
            $monthLabels.Add($ptMonths[$weekStart.Month])
            $monthCols.Add($w)
        }
        $prevMonth = $weekStart.Month
    }
    for ($d = 0; $d -lt 7; $d++) {
        $dt = $weekStart.AddDays($d)
        $key = $dt.ToString("yyyy-MM-dd")
        if ($dt -gt $lastDate) {
            $levels[$w * 7 + $d] = -1
        } elseif ($cellMap.ContainsKey($key)) {
            $levels[$w * 7 + $d] = $cellMap[$key]
        } else {
            $levels[$w * 7 + $d] = 0
        }
    }
}

Write-Output "Calendario lido: $WEEKS semanas | $totalContribs contribuicoes | $pubRepos repositorios"

# ---------- 2. Motor C# para Simulacao Fisica 2D + Geracao SVG ----------
$cs = @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

public class CommitBreakerEngine
{
    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
    static string F(double v) { return v.ToString("0.##", Inv); }
    static string P(double pct) { return Math.Max(0, Math.Min(100, pct)).ToString("0.##", Inv) + "%"; }

    const int W = 880, H = 304, WEEKS = 53;
    const double GX0 = 48.0, GY0 = 68.0, CELL = 12.0, GAP = 3.0, PITCH = 15.0;
    const double LEFT_WALL = 46.0, RIGHT_WALL = 846.0, TOP_WALL = 64.0, PADDLE_Y = 264.0;
    const double PADDLE_W = 82.0, BALL_R = 4.5;
    const double TOTAL_DUR = 22.0; // 22-second seamless 60fps loop

    class Brick
    {
        public int Id, Week, Day, Level;
        public double X, Y, CX, CY;
        public bool Alive = true;
        public double HitTime = -1;
        public bool LaserKill = false;
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
            default: return "#161b22";
        }
    }

    public static string BuildGameSvg(int[] levels, string[] mNames, int[] mCols, int totalContribs)
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
                    br.Id = bricks.Count;
                    br.Week = w; br.Day = d; br.Level = lvl;
                    br.X = GX0 + w * PITCH;
                    br.Y = GY0 + d * PITCH;
                    br.CX = br.X + CELL / 2.0;
                    br.CY = br.Y + CELL / 2.0;
                    bricks.Add(br);
                }
            }
        }

        // Fallback se um dia a conta tiver 0 commits
        if (bricks.Count == 0)
        {
            int[] demoCols = { 8, 14, 21, 28, 35, 42, 48 };
            for (int i = 0; i < demoCols.Length; i++)
            {
                Brick br = new Brick();
                br.Id = i; br.Week = demoCols[i]; br.Day = (i * 2) % 7; br.Level = (i % 4) + 1;
                br.X = GX0 + br.Week * PITCH; br.Y = GY0 + br.Day * PITCH;
                br.CX = br.X + CELL / 2.0; br.CY = br.Y + CELL / 2.0;
                bricks.Add(br);
            }
        }

        // Escolher posição inicial abaixo do primeiro terço de commits
        double startX = bricks[bricks.Count / 3].CX;
        startX = Math.Max(LEFT_WALL + 50, Math.Min(RIGHT_WALL - 50, startX));

        List<KeyPt> ballPts = new List<KeyPt>();
        List<KeyPt> padPts = new List<KeyPt>();

        // Fase 1: Ricochete físico real com mira inteligente da raquete (0.3s -> ~13.2s)
        int targetBallKills = Math.Max(1, (int)Math.Ceiling(bricks.Count * 0.58));
        int ballKills = 0;

        double bx = startX, by = PADDLE_Y - BALL_R - 1;
        // Mirar primeiro tiro no commit mais próximo
        Brick firstTarget = bricks[bricks.Count / 3];
        double ang0 = Math.Atan2(firstTarget.CY - by, firstTarget.CX - bx);
        double speed = 340.0;
        double vx = Math.Cos(ang0) * speed, vy = Math.Sin(ang0) * speed;
        if (vy > -180) { vy = -240; vx = (vx >= 0 ? 1 : -1) * Math.Sqrt(speed * speed - vy * vy); }

        double t = 0.0;
        ballPts.Add(new KeyPt(0.0, bx, by));
        padPts.Add(new KeyPt(0.0, startX, PADDLE_Y));
        ballPts.Add(new KeyPt(0.35, bx, by));
        padPts.Add(new KeyPt(0.35, startX, PADDLE_Y));
        t = 0.35;

        double dt = 0.005;
        Brick powerUpSource = bricks[0];

        while (t < 13.0 && ballKills < targetBallKills)
        {
            double nx = bx + vx * dt;
            double ny = by + vy * dt;
            t += dt;
            bool bounced = false;

            if (nx - BALL_R <= LEFT_WALL)
            {
                nx = LEFT_WALL + BALL_R; vx = Math.Abs(vx); bounced = true;
            }
            else if (nx + BALL_R >= RIGHT_WALL)
            {
                nx = RIGHT_WALL - BALL_R; vx = -Math.Abs(vx); bounced = true;
            }

            if (ny - BALL_R <= TOP_WALL)
            {
                ny = TOP_WALL + BALL_R; vy = Math.Abs(vy); bounced = true;
            }

            // Checar colisão com commits vivos
            for (int i = 0; i < bricks.Count; i++)
            {
                Brick br = bricks[i];
                if (!br.Alive) continue;
                if (nx + BALL_R >= br.X && nx - BALL_R <= br.X + CELL &&
                    ny + BALL_R >= br.Y && ny - BALL_R <= br.Y + CELL)
                {
                    br.Alive = false;
                    br.HitTime = t;
                    br.LaserKill = false;
                    powerUpSource = br;
                    ballKills++;

                    double overlapX = Math.Min(nx + BALL_R - br.X, (br.X + CELL) - (nx - BALL_R));
                    double overlapY = Math.Min(ny + BALL_R - br.Y, (br.Y + CELL) - (ny - BALL_R));
                    if (overlapX < overlapY) vx = -vx; else vy = -vy;
                    bounced = true;
                    break;
                }
            }

            // Checar interceptação na raquete!
            if (vy > 0 && ny + BALL_R >= PADDLE_Y)
            {
                ny = PADDLE_Y - BALL_R;
                double padX = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, nx));
                padPts.Add(new KeyPt(t, padX, PADDLE_Y));

                // Se já bateu a meta da Fase 1, encerrar o rally na raquete!
                if (ballKills >= targetBallKills || t >= 12.0)
                {
                    bx = nx; by = ny;
                    ballPts.Add(new KeyPt(t, bx, by));
                    break;
                }

                // Mirar o próximo disparo na direção de um commit vivo!
                Brick aim = null;
                double bestScore = 1e9;
                for (int i = 0; i < bricks.Count; i++)
                {
                    if (!bricks[i].Alive) continue;
                    double dist = Math.Abs(bricks[i].CX - nx) + (bricks[i].Day * 8);
                    if (dist < bestScore) { bestScore = dist; aim = bricks[i]; }
                }
                if (aim != null)
                {
                    double dx = aim.CX - nx;
                    double dy = aim.CY - ny;
                    // Limitar ângulo para parecer rebote natural de arcade
                    double ang = Math.Atan2(dy, dx);
                    ang = Math.Max(-2.45, Math.Min(-0.69, ang));
                    vx = Math.Cos(ang) * speed;
                    vy = Math.Sin(ang) * speed;
                }
                else
                {
                    vy = -Math.Abs(vy);
                }
                bounced = true;
            }

            bx = nx; by = ny;
            if (bounced)
                ballPts.Add(new KeyPt(t, bx, by));
        }

        // Garantir que a bola volte suavemente à raquete ao fim da Fase 1 se terminou no ar
        if (by < PADDLE_Y - BALL_R - 2)
        {
            double dropDur = Math.Max(0.25, (PADDLE_Y - BALL_R - by) / 280.0);
            t += dropDur;
            by = PADDLE_Y - BALL_R;
            double catchX = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, bx));
            bx = catchX;
            ballPts.Add(new KeyPt(t, bx, by));
            padPts.Add(new KeyPt(t, catchX, PADDLE_Y));
        }

        double phase1End = t;

        // Fase 2: Cápsula ⚡ HYPER-LASER cai do último tijolo atingido -> Raquete pega e varre os restantes!
        double capStartT = Math.Max(0.5, powerUpSource.HitTime > 0 ? powerUpSource.HitTime : phase1End - 0.8);
        double capCatchX = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, powerUpSource.CX));
        double capCatchT = Math.Max(phase1End + 0.55, capStartT + 0.95);

        padPts.Add(new KeyPt(capCatchT, capCatchX, PADDLE_Y));
        ballPts.Add(new KeyPt(capCatchT, capCatchX, PADDLE_Y - BALL_R)); // bola acoplada na raquete magnetizada!

        // Ordenar tijolos vivos da esquerda para a direita para a varredura de Laser Duplo!
        List<Brick> remaining = new List<Brick>();
        for (int i = 0; i < bricks.Count; i++) if (bricks[i].Alive) remaining.Add(bricks[i]);
        remaining.Sort((a, b) => a.X.CompareTo(b.X));

        double laserStartT = capCatchT + 0.25;
        double laserEndT = 18.4;
        List<KeyPt> laserShots = new List<KeyPt>();

        if (remaining.Count > 0)
        {
            for (int i = 0; i < remaining.Count; i++)
            {
                double frac = (remaining.Count == 1) ? 0.5 : (double)i / (remaining.Count - 1);
                double shotT = laserStartT + frac * (laserEndT - laserStartT);
                Brick rb = remaining[i];
                rb.Alive = false;
                rb.HitTime = shotT + 0.08;
                rb.LaserKill = true;

                double px = Math.Max(LEFT_WALL + PADDLE_W / 2, Math.Min(RIGHT_WALL - PADDLE_W / 2, rb.CX));
                padPts.Add(new KeyPt(shotT, px, PADDLE_Y));
                ballPts.Add(new KeyPt(shotT, px, PADDLE_Y - BALL_R));
                laserShots.Add(new KeyPt(shotT, rb.CX, rb.CY));
            }
        }
        else
        {
            // Varredura de vitória se a bola já limpou tudo
            padPts.Add(new KeyPt(16.0, 240, PADDLE_Y));
            ballPts.Add(new KeyPt(16.0, 240, PADDLE_Y - BALL_R));
            padPts.Add(new KeyPt(18.2, 640, PADDLE_Y));
            ballPts.Add(new KeyPt(18.2, 640, PADDLE_Y - BALL_R));
        }

        // Fase 3: Stage Clear (18.6s .. 20.6s) & Retorno suave ao ponto inicial (22.0s)
        double lastPadX = padPts[padPts.Count - 1].X;
        padPts.Add(new KeyPt(19.6, 440, PADDLE_Y));
        ballPts.Add(new KeyPt(19.6, 440, PADDLE_Y - BALL_R));
        padPts.Add(new KeyPt(21.6, startX, PADDLE_Y));
        ballPts.Add(new KeyPt(21.6, startX, PADDLE_Y - BALL_R));
        padPts.Add(new KeyPt(TOTAL_DUR, startX, PADDLE_Y));
        ballPts.Add(new KeyPt(TOTAL_DUR, startX, PADDLE_Y - BALL_R));

        // Montar SVG + CSS Keyframes
        StringBuilder css = new StringBuilder();
        css.AppendLine(".txt { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }");
        css.AppendLine(".mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }");

        // Keyframes da Bola
        css.Append("@keyframes ball { ");
        for (int i = 0; i < ballPts.Count; i++)
        {
            if (i > 0 && ballPts[i].T <= ballPts[i - 1].T + 0.002) continue;
            css.AppendFormat(Inv, "{0} {{ transform: translate({1}px, {2}px); }} ",
                P(ballPts[i].T / TOTAL_DUR * 100.0), F(ballPts[i].X), F(ballPts[i].Y));
        }
        css.AppendLine("}");
        css.AppendLine("#ball { animation: ball 22s linear infinite; }");
        css.AppendLine("#ballT1 { animation: ball 22s linear -0.045s infinite; }");
        css.AppendLine("#ballT2 { animation: ball 22s linear -0.09s infinite; }");

        // Visibilidade da bola (some quando vira modo Laser e reaparece no respawn)
        string hideBallP1 = P((capCatchT - 0.05) / TOTAL_DUR * 100.0);
        string hideBallP2 = P(capCatchT / TOTAL_DUR * 100.0);
        string showBallP1 = P(21.2 / TOTAL_DUR * 100.0);
        string showBallP2 = P(21.5 / TOTAL_DUR * 100.0);
        css.AppendFormat(Inv, "@keyframes ballVis {{ 0%, {0} {{ opacity: 1; }} {1}, {2} {{ opacity: 0; }} {3}, 100% {{ opacity: 1; }} }}\n",
            hideBallP1, hideBallP2, showBallP1, showBallP2);
        css.AppendLine("#ballDot, #ballTrail1, #ballTrail2 { animation: ballVis 22s linear infinite; }");

        // Keyframes da Raquete
        css.Append("@keyframes pad { ");
        for (int i = 0; i < padPts.Count; i++)
        {
            if (i > 0 && padPts[i].T <= padPts[i - 1].T + 0.005) continue;
            css.AppendFormat(Inv, "{0} {{ transform: translate({1}px, {2}px); }} ",
                P(padPts[i].T / TOTAL_DUR * 100.0), F(padPts[i].X), F(padPts[i].Y));
        }
        css.AppendLine("}");
        css.AppendLine("#paddle { animation: pad 22s linear infinite; }");

        // Cor de Overdrive da Raquete no Modo Laser
        string lasOn1 = P((capCatchT - 0.05) / TOTAL_DUR * 100.0);
        string lasOn2 = P(capCatchT / TOTAL_DUR * 100.0);
        string lasOff1 = P(18.7 / TOTAL_DUR * 100.0);
        string lasOff2 = P(19.0 / TOTAL_DUR * 100.0);
        css.AppendFormat(Inv, "@keyframes padLaser {{ 0%, {0} {{ opacity: 0; }} {1}, {2} {{ opacity: 1; }} {3}, 100% {{ opacity: 0; }} }}\n",
            lasOn1, lasOn2, lasOff1, lasOff2);
        css.AppendLine("#padOverdrive { animation: padLaser 22s linear infinite; }");

        // Cápsula Power-Up ⚡ caindo
        css.AppendFormat(Inv,
            "@keyframes capDrop {{ 0%, {0} {{ opacity: 0; transform: translate({4}px, {5}px); }} {1} {{ opacity: 1; transform: translate({4}px, {5}px); }} {2} {{ opacity: 1; transform: translate({6}px, {7}px); }} {3}, 100% {{ opacity: 0; transform: translate({6}px, {7}px); }} }}\n",
            P((capStartT - 0.05) / TOTAL_DUR * 100.0),
            P(capStartT / TOTAL_DUR * 100.0),
            P((capCatchT - 0.02) / TOTAL_DUR * 100.0),
            P((capCatchT + 0.05) / TOTAL_DUR * 100.0),
            F(powerUpSource.CX), F(powerUpSource.CY),
            F(capCatchX), F(PADDLE_Y - 6));
        css.AppendLine("#capsule { animation: capDrop 22s linear infinite; }");

        // Keyframes de cada tijolo de commit + ondas de impacto
        StringBuilder gridSvg = new StringBuilder();
        StringBuilder fxSvg = new StringBuilder();

        // Desenhar primeiro todas as células vazias / estáticas (sem animação = super leve!)
        for (int w = 0; w < WEEKS; w++)
        {
            for (int d = 0; d < 7; d++)
            {
                int lvl = levels[w * 7 + d];
                if (lvl < 0) continue;
                double x = GX0 + w * PITCH;
                double y = GY0 + d * PITCH;
                // Fundo base vazio da grade (sempre visível quando o tijolo verde é quebrado!)
                gridSvg.AppendFormat(Inv, "<rect x=\"{0}\" y=\"{1}\" width=\"12\" height=\"12\" rx=\"2.5\" fill=\"#161b22\" stroke=\"#1f2630\" stroke-width=\"0.8\"/>\n",
                    F(x), F(y));
            }
        }

        // Sobrepor os tijolos verdes reais com animação individual de impacto + respawn em onda!
        for (int i = 0; i < bricks.Count; i++)
        {
            Brick br = bricks[i];
            string col = LevelColor(br.Level);
            double hitP = (br.HitTime / TOTAL_DUR) * 100.0;
            double flashP = hitP + 0.35;
            double goneP = hitP + 0.85;
            double respStartP = ((20.1 + (br.Week / 53.0) * 1.2) / TOTAL_DUR) * 100.0;
            double respDoneP = respStartP + 0.9;

            css.AppendFormat(Inv,
                "@keyframes b{0} {{ 0%, {1} {{ opacity: 1; fill: {2}; }} {3} {{ opacity: 1; fill: #ffffff; }} {4}, {5} {{ opacity: 0; fill: {2}; }} {6}, 100% {{ opacity: 1; fill: {2}; }} }}\n",
                br.Id, P(hitP - 0.05), col, P(flashP), P(goneP), P(respStartP), P(respDoneP));

            gridSvg.AppendFormat(Inv,
                "<rect x=\"{0}\" y=\"{1}\" width=\"12\" height=\"12\" rx=\"2.5\" fill=\"{2}\" style=\"animation: b{3} 22s linear infinite;\"/>\n",
                F(br.X), F(br.Y), col, br.Id);

            // Anel de choque (shockwave universal via scale) no momento exato do impacto!
            string ringCol = br.LaserKill ? "#58a6ff" : "#7ee787";
            css.AppendFormat(Inv,
                "@keyframes r{0} {{ 0%, {1} {{ opacity: 0; transform: scale(0.5); }} {2} {{ opacity: 0.95; transform: scale(1); }} {3} {{ opacity: 0; transform: scale(3.4); }} 100% {{ opacity: 0; transform: scale(3.4); }} }}\n",
                br.Id, P(hitP - 0.05), P(hitP + 0.15), P(hitP + 1.5));
            fxSvg.AppendFormat(Inv,
                "<g transform=\"translate({0},{1})\"><circle cx=\"0\" cy=\"0\" r=\"5\" fill=\"none\" stroke=\"{2}\" stroke-width=\"1.4\" style=\"animation: r{3} 22s linear infinite;\"/></g>\n",
                F(br.CX), F(br.CY), ringCol, br.Id);
        }

        // Raios Laser disparados na Fase 2 (agrupados para leveza)
        int stepLaser = Math.Max(1, laserShots.Count / 14);
        for (int i = 0; i < laserShots.Count; i += stepLaser)
        {
            KeyPt ls = laserShots[i];
            double lp0 = (ls.T / TOTAL_DUR) * 100.0;
            css.AppendFormat(Inv,
                "@keyframes lz{0} {{ 0%, {1} {{ opacity: 0; }} {2} {{ opacity: 0.95; }} {3}, 100% {{ opacity: 0; }} }}\n",
                i, P(lp0 - 0.1), P(lp0 + 0.2), P(lp0 + 0.95));
            fxSvg.AppendFormat(Inv,
                "<g style=\"animation: lz{0} 22s linear infinite;\"><line x1=\"{1}\" y1=\"{2}\" x2=\"{1}\" y2=\"{3}\" stroke=\"#58a6ff\" stroke-width=\"2.2\" stroke-linecap=\"round\"/><line x1=\"{4}\" y1=\"{2}\" x2=\"{4}\" y2=\"{3}\" stroke=\"#a5d6ff\" stroke-width=\"1.2\" stroke-linecap=\"round\"/></g>\n",
                i, F(ls.X - 10), F(PADDLE_Y - 2), F(ls.Y + 4), F(ls.X + 10));
        }

        // Barra de Progresso de Limpeza + Banner Stage Clear
        css.AppendFormat(Inv,
            "@keyframes progFill {{ 0% {{ width: 0px; }} {0} {{ width: 88px; }} {1} {{ width: 150px; }} 91% {{ width: 150px; }} 96%, 100% {{ width: 0px; }} }}\n",
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

        // Rótulos de Meses reais
        StringBuilder monthsSvg = new StringBuilder();
        for (int i = 0; i < mNames.Length; i++)
        {
            double mx = GX0 + mCols[i] * PITCH;
            monthsSvg.AppendFormat(Inv, "<text x=\"{0}\" y=\"58\" class=\"txt\" font-size=\"10.5\" fill=\"#8b949e\">{1}</text>\n", F(mx), mNames[i]);
        }

        StringBuilder svg = new StringBuilder();
        svg.AppendFormat(Inv, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{0}\" height=\"{1}\" viewBox=\"0 0 {0} {1}\">\n", W, H);
        svg.AppendLine("<defs>");
        svg.AppendLine("  <style>");
        svg.Append(css.ToString());
        svg.AppendLine("  </style>");
        svg.AppendLine("  <linearGradient id=\"padGrad\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\">");
        svg.AppendLine("    <stop offset=\"0%\" stop-color=\"#2ea043\"/><stop offset=\"50%\" stop-color=\"#7ee787\"/><stop offset=\"100%\" stop-color=\"#2ea043\"/>");
        svg.AppendLine("  </linearGradient>");
        svg.AppendLine("  <linearGradient id=\"padCyan\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\">");
        svg.AppendLine("    <stop offset=\"0%\" stop-color=\"#1f6feb\"/><stop offset=\"50%\" stop-color=\"#a5d6ff\"/><stop offset=\"100%\" stop-color=\"#1f6feb\"/>");
        svg.AppendLine("  </linearGradient>");
        svg.AppendLine("  <radialGradient id=\"ballGlow\" cx=\"50%\" cy=\"50%\" r=\"50%\">");
        svg.AppendLine("    <stop offset=\"0%\" stop-color=\"#ffffff\"/><stop offset=\"45%\" stop-color=\"#7ee787\"/><stop offset=\"100%\" stop-color=\"#39d353\" stop-opacity=\"0\"/>");
        svg.AppendLine("  </radialGradient>");
        svg.AppendLine("</defs>");

        // Card GitHub Dark Nativo
        svg.AppendLine("<rect x=\"1\" y=\"1\" width=\"878\" height=\"302\" rx=\"10\" fill=\"#0d1117\" stroke=\"#21262d\" stroke-width=\"1.5\"/>");
        svg.AppendLine("<rect x=\"1\" y=\"1\" width=\"878\" height=\"38\" rx=\"10\" fill=\"#161b22\"/>");
        svg.AppendLine("<rect x=\"1\" y=\"28\" width=\"878\" height=\"11\" fill=\"#161b22\"/>");
        svg.AppendLine("<line x1=\"1\" y1=\"39\" x2=\"879\" y2=\"39\" stroke=\"#21262d\" stroke-width=\"1\"/>");

        // Top Arcade HUD Bar
        svg.AppendLine("<circle cx=\"22\" cy=\"20\" r=\"4.5\" fill=\"#39d353\"/>");
        svg.AppendLine("<text x=\"34\" y=\"24\" class=\"mono\" font-size=\"12\" font-weight=\"700\" fill=\"#e6edf3\" letter-spacing=\"1\">COMMIT BREAKER</text>");
        svg.AppendFormat(Inv, "<text x=\"168\" y=\"24\" class=\"txt\" font-size=\"11.5\" fill=\"#8b949e\">·  {0} contribuições reais em jogo</text>\n", totalContribs);

        // Status Dinâmico do Modo de Jogo
        svg.AppendLine("<g transform=\"translate(425, 9)\">");
        svg.AppendLine("  <rect width=\"164\" height=\"22\" rx=\"11\" fill=\"#0d1117\" stroke=\"#30363d\"/>");
        svg.AppendLine("  <text id=\"mRic\" x=\"82\" y=\"15\" class=\"mono\" font-size=\"10.5\" font-weight=\"700\" fill=\"#39d353\" text-anchor=\"middle\">● MODO RICOCHETE</text>");
        svg.AppendLine("  <text id=\"mLas\" x=\"82\" y=\"15\" class=\"mono\" font-size=\"10.5\" font-weight=\"700\" fill=\"#58a6ff\" text-anchor=\"middle\">⚡ HYPER-LASER ATIVO</text>");
        svg.AppendLine("  <text id=\"mWin\" x=\"82\" y=\"15\" class=\"mono\" font-size=\"10.5\" font-weight=\"700\" fill=\"#f0b429\" text-anchor=\"middle\">★ STAGE CLEAR 100%</text>");
        svg.AppendLine("</g>");

        // Barra de Progresso do Mapa
        svg.AppendLine("<text x=\"638\" y=\"24\" class=\"mono\" font-size=\"10.5\" fill=\"#8b949e\">CLEAR</text>");
        svg.AppendLine("<rect x=\"682\" y=\"14\" width=\"150\" height=\"11\" rx=\"5.5\" fill=\"#0d1117\" stroke=\"#30363d\"/>");
        svg.AppendLine("<rect id=\"progBar\" x=\"682\" y=\"14\" width=\"0\" height=\"11\" rx=\"5.5\" fill=\"url(#padGrad)\"/>");

        // Rótulos de Mês e Dia da Semana (idênticos ao GitHub!)
        svg.Append(monthsSvg.ToString());
        svg.AppendLine("<text x=\"18\" y=\"92\" class=\"txt\" font-size=\"10\" fill=\"#8b949e\">Seg</text>");
        svg.AppendLine("<text x=\"18\" y=\"122\" class=\"txt\" font-size=\"10\" fill=\"#8b949e\">Qua</text>");
        svg.AppendLine("<text x=\"18\" y=\"152\" class=\"txt\" font-size=\"10\" fill=\"#8b949e\">Sex</text>");

        // Grade 53x7 + Tijolos Verdes Reais
        svg.Append(gridSvg.ToString());

        // Linha sutil da Arena Arcade
        svg.AppendLine("<line x1=\"46\" y1=\"272\" x2=\"846\" y2=\"272\" stroke=\"#161b22\" stroke-width=\"1\" stroke-dasharray=\"4 4\"/>");

        // Efeitos de Choque & Lasers
        svg.Append(fxSvg.ToString());

        // Cápsula de Power-Up ⚡ HYPER-LASER
        svg.AppendLine("<g id=\"capsule\">");
        svg.AppendLine("  <rect x=\"-14\" y=\"-7\" width=\"28\" height=\"14\" rx=\"7\" fill=\"#1f6feb\" stroke=\"#a5d6ff\" stroke-width=\"1.2\"/>");
        svg.AppendLine("  <text x=\"0\" y=\"3.5\" class=\"mono\" font-size=\"9.5\" font-weight=\"700\" fill=\"#ffffff\" text-anchor=\"middle\">⚡LZR</text>");
        svg.AppendLine("</g>");

        // Bola de Plasma + Rastro de Cometa Arcade
        svg.AppendLine("<g id=\"ballT2\"><g id=\"ballTrail2\"><circle cx=\"0\" cy=\"0\" r=\"2.5\" fill=\"#39d353\" opacity=\"0.28\"/></g></g>");
        svg.AppendLine("<g id=\"ballT1\"><g id=\"ballTrail1\"><circle cx=\"0\" cy=\"0\" r=\"3.5\" fill=\"#7ee787\" opacity=\"0.52\"/></g></g>");
        svg.AppendLine("<g id=\"ball\"><g id=\"ballDot\">");
        svg.AppendLine("  <circle cx=\"0\" cy=\"0\" r=\"10\" fill=\"url(#ballGlow)\"/>");
        svg.AppendLine("  <circle cx=\"0\" cy=\"0\" r=\"4.5\" fill=\"#ffffff\"/>");
        svg.AppendLine("</g></g>");

        // Raquete Cyber-Arcade (EXP.DEV)
        svg.AppendLine("<g id=\"paddle\">");
        svg.AppendLine("  <rect x=\"-41\" y=\"0\" width=\"82\" height=\"9\" rx=\"4.5\" fill=\"url(#padGrad)\"/>");
        svg.AppendLine("  <rect id=\"padOverdrive\" x=\"-41\" y=\"0\" width=\"82\" height=\"9\" rx=\"4.5\" fill=\"url(#padCyan)\"/>");
        svg.AppendLine("  <rect x=\"-18\" y=\"2.5\" width=\"36\" height=\"4\" rx=\"2\" fill=\"#0d1117\" opacity=\"0.55\"/>");
        svg.AppendLine("</g>");

        // Banner de Vitória Stage Clear
        svg.AppendLine("<g id=\"stageClear\">");
        svg.AppendLine("  <rect x=\"270\" y=\"196\" width=\"340\" height=\"36\" rx=\"18\" fill=\"#161b22\" stroke=\"#39d353\" stroke-width=\"1.5\"/>");
        svg.AppendLine("  <text x=\"440\" y=\"219\" class=\"mono\" font-size=\"13\" font-weight=\"700\" fill=\"#7ee787\" text-anchor=\"middle\" letter-spacing=\"1\">★ STAGE CLEAR · GRADE ZERADA! ★</text>");
        svg.AppendLine("</g>");

        // Rodapé Legenda GitHub Nativa
        svg.AppendLine("<text x=\"48\" y=\"291\" class=\"txt\" font-size=\"10.5\" fill=\"#6e7681\">Atualizado automaticamente todo dia com os commits reais de @expeditodeviago</text>");
        svg.AppendLine("<g transform=\"translate(728, 281)\">");
        svg.AppendLine("  <text x=\"0\" y=\"10\" class=\"txt\" font-size=\"10.5\" fill=\"#8b949e\">Menos</text>");
        svg.AppendLine("  <rect x=\"38\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#161b22\" stroke=\"#1f2630\"/>");
        svg.AppendLine("  <rect x=\"51\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#0e4429\"/>");
        svg.AppendLine("  <rect x=\"64\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#006d32\"/>");
        svg.AppendLine("  <rect x=\"77\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#26a641\"/>");
        svg.AppendLine("  <rect x=\"90\" y=\"1\" width=\"10\" height=\"10\" rx=\"2\" fill=\"#39d353\"/>");
        svg.AppendLine("  <text x=\"105\" y=\"10\" class=\"txt\" font-size=\"10.5\" fill=\"#8b949e\">Mais</text>");
        svg.AppendLine("</g>");

        svg.AppendLine("</svg>");
        return svg.ToString();
    }
}
'@

Add-Type -TypeDefinition $cs
$gameSvg = [CommitBreakerEngine]::BuildGameSvg($levels, $monthLabels.ToArray(), $monthCols.ToArray(), $totalContribs)
[IO.File]::WriteAllText((Join-Path $out "commit-game.svg"), $gameSvg, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  commit-game.svg ($((Get-Item (Join-Path $out 'commit-game.svg')).Length) bytes)"

# ---------- 3. HERO HEADER MODERNO (assets/hero-header.svg) — 880 x 154 ----------
$heroSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="880" height="154" viewBox="0 0 880 154">
  <defs>
    <style>
      .sans { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }
      .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
      .pulse { animation: p 2s ease-in-out infinite; }
      @keyframes p { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }
      .beam { animation: b 6s ease-in-out infinite; }
      @keyframes b { 0%, 100% { transform: translateX(-180px); opacity: 0.2; } 50% { transform: translateX(620px); opacity: 0.85; } }
    </style>
    <pattern id="dots" width="18" height="18" patternUnits="userSpaceOnUse">
      <circle cx="2" cy="2" r="1" fill="#21262d"/>
    </pattern>
    <linearGradient id="titleGrad" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#f0f6fc"/>
      <stop offset="65%" stop-color="#e6edf3"/>
      <stop offset="100%" stop-color="#7ee787"/>
    </linearGradient>
    <linearGradient id="lineGlow" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#39d353" stop-opacity="0"/>
      <stop offset="50%" stop-color="#39d353" stop-opacity="1"/>
      <stop offset="100%" stop-color="#58a6ff" stop-opacity="0"/>
    </linearGradient>
  </defs>

  <rect x="1" y="1" width="878" height="152" rx="10" fill="#0d1117" stroke="#21262d" stroke-width="1.5"/>
  <rect x="2" y="2" width="876" height="150" rx="9" fill="url(#dots)" opacity="0.65"/>

  <!-- Feixe luminoso sutil no topo -->
  <rect class="beam" x="40" y="1" width="240" height="2" fill="url(#lineGlow)"/>

  <!-- Badge de Status -->
  <rect x="34" y="24" width="212" height="24" rx="12" fill="#161b22" stroke="#30363d"/>
  <circle cx="48" cy="36" r="4" fill="#39d353" class="pulse"/>
  <text x="60" y="40" class="mono" font-size="11" font-weight="600" fill="#7ee787">EXP.DEV · ONLINE</text>
  <text x="174" y="40" class="mono" font-size="11" fill="#8b949e">// BR</text>

  <!-- Nome Principal e Especialidade -->
  <text x="34" y="88" class="sans" font-size="38" font-weight="800" fill="url(#titleGrad)" letter-spacing="-0.5">Iago Expedito</text>
  <text x="34" y="116" class="mono" font-size="13.5" font-weight="600" fill="#39d353">Product Architect &amp; Software Engineer</text>
  <text x="342" y="116" class="sans" font-size="13" fill="#8b949e">·  Arquitetura de Produto, IA Generativa &amp; Dados</text>

  <!-- Cards Minimalistas de Métricas à Direita -->
  <g transform="translate(620, 36)">
    <rect width="108" height="82" rx="8" fill="#161b22" stroke="#21262d"/>
    <text x="54" y="38" class="sans" font-size="26" font-weight="800" fill="#f0f6fc" text-anchor="middle">$pubRepos</text>
    <text x="54" y="60" class="mono" font-size="10" fill="#8b949e" text-anchor="middle">REPOSITÓRIOS</text>
  </g>
  <g transform="translate(740, 36)">
    <rect width="108" height="82" rx="8" fill="#161b22" stroke="#21262d"/>
    <text x="54" y="38" class="sans" font-size="26" font-weight="800" fill="#39d353" text-anchor="middle">$totalContribs</text>
    <text x="54" y="60" class="mono" font-size="10" fill="#8b949e" text-anchor="middle">COMMITS / ANO</text>
  </g>
</svg>
"@
[IO.File]::WriteAllText((Join-Path $out "hero-header.svg"), $heroSvg, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  hero-header.svg"

# ---------- 4. PAINEL MODERNO DE STACK & ARQUITETURA (assets/stack-hud.svg) — 880 x 176 ----------
$stackSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="880" height="176" viewBox="0 0 880 176">
  <defs>
    <style>
      .sans { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }
      .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
    </style>
  </defs>

  <rect x="1" y="1" width="878" height="174" rx="10" fill="#0d1117" stroke="#21262d" stroke-width="1.5"/>

  <!-- Coluna 1: Linguagens & Core -->
  <g transform="translate(20, 20)">
    <rect width="202" height="136" rx="8" fill="#161b22" stroke="#21262d"/>
    <circle cx="18" cy="22" r="4" fill="#39d353"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#e6edf3">LINGUAGENS</text>
    <line x1="14" y1="38" x2="188" y2="38" stroke="#21262d"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#c9d1d9">TypeScript · JavaScript</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#c9d1d9">Python · Java</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#8b949e">SQL · HTML5 · CSS3</text>
  </g>

  <!-- Coluna 2: Frontend & UX -->
  <g transform="translate(232, 20)">
    <rect width="202" height="136" rx="8" fill="#161b22" stroke="#21262d"/>
    <circle cx="18" cy="22" r="4" fill="#58a6ff"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#e6edf3">FRONTEND &amp; UI</text>
    <line x1="14" y1="38" x2="188" y2="38" stroke="#21262d"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#c9d1d9">React 19 · Next.js</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#c9d1d9">Tailwind CSS · Vite</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#8b949e">Framer Motion · Recharts</text>
  </g>

  <!-- Coluna 3: Backend & Dados -->
  <g transform="translate(444, 20)">
    <rect width="202" height="136" rx="8" fill="#161b22" stroke="#21262d"/>
    <circle cx="18" cy="22" r="4" fill="#f0b429"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#e6edf3">BACKEND &amp; DADOS</text>
    <line x1="14" y1="38" x2="188" y2="38" stroke="#21262d"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#c9d1d9">FastAPI · Node.js</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#c9d1d9">Pandas · NumPy · Prisma</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#8b949e">PostgreSQL · SQLite · Turso</text>
  </g>

  <!-- Coluna 4: IA & Arquitetura -->
  <g transform="translate(656, 20)">
    <rect width="204" height="136" rx="8" fill="#161b22" stroke="#21262d"/>
    <circle cx="18" cy="22" r="4" fill="#d2a8ff"/>
    <text x="30" y="26" class="mono" font-size="11.5" font-weight="700" fill="#e6edf3">IA &amp; ARQUITETURA</text>
    <line x1="14" y1="38" x2="190" y2="38" stroke="#21262d"/>
    <text x="16" y="62" class="sans" font-size="12.5" fill="#c9d1d9">LLMs · Llama · Groq API</text>
    <text x="16" y="86" class="sans" font-size="12.5" fill="#c9d1d9">OpenAI SDK · Web Speech</text>
    <text x="16" y="110" class="sans" font-size="12.5" fill="#8b949e">Product Arch · Vercel · Git</text>
  </g>
</svg>
"@
[IO.File]::WriteAllText((Join-Path $out "stack-hud.svg"), $stackSvg, (New-Object Text.UTF8Encoding($false)))
Write-Output "ok  stack-hud.svg"

# ---------- 5. BOTOES MINIMALISTAS DE NAVEGACAO (284 x 46) ----------
function Save-Pill([string]$file, [string]$label, [string]$sub, [string]$accent) {
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="284" height="46" viewBox="0 0 284 46">
  <style>
    .sans { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
  </style>
  <rect x="1" y="1" width="282" height="44" rx="8" fill="#161b22" stroke="#30363d" stroke-width="1.2"/>
  <circle cx="22" cy="23" r="4.5" fill="$accent"/>
  <text x="36" y="27" class="sans" font-size="13" font-weight="700" fill="#f0f6fc">$label</text>
  <text x="266" y="27" class="mono" font-size="11" fill="#8b949e" text-anchor="end">$sub ↗</text>
</svg>
"@
    [IO.File]::WriteAllText((Join-Path $out $file), $svg, (New-Object Text.UTF8Encoding($false)))
    Write-Output "ok  $file"
}

Save-Pill "btn-repos.svg"    "Explorar Repositórios" "$pubRepos projetos" "#39d353"
Save-Pill "btn-linkedin.svg" "LinkedIn"              "conectar"           "#58a6ff"
Save-Pill "btn-insta.svg"    "Instagram"             "@iagoexpedito"      "#d2a8ff"
