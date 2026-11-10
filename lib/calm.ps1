# ------------------------------------------------------------------ calm ----
# Fork addition: calm Clawd (calmMascot). He stays where he stands, in one still pose
# for his mood - eyes open when idle, focused while a session works, a "?" while one
# waits for you, eyes shut with a "z" asleep, legs up at the limit - and nothing moves:
# no running, hops, waves, tricks, dust, confetti or floating hearts. One frame a
# second instead of eleven; the sky is redrawn every 30 s (see mascot-menu.ps1).
# Also here: showHearts - the three hearts are the main limit again, so off by default.

$Strings.en['set.calmMascot'] = 'Calm Clawd (still, no running or hopping)'
$Strings.en['set.showHearts'] = 'Hearts (the main limit left)'
$CalmFrameMs = 1000

function Step-MascotCalm {
    $m = $script:Mz
    $m.tick++
    $span = [math]::Max(0, $UI.MascotArea.ActualWidth - $MascotW)
    if ($m.x -lt 0 -or $m.x -gt $span) { $m.x = $span / 2 }
    # Nothing that moves: no one-shot animations, walks, notes, petting or confetti.
    $m.act = $null; $m.target = $null; $m.noteT = -1; $m.loveT = -1; $m.confT = -1; $m.buried = $false

    $mood = $(if ($m.force) { $m.force } else { $m.mood })
    if ($null -ne $m.forceHearts -and [int]$m.forceHearts -eq 0) { $mood = 'dead' }
    $halves = Get-Halves
    $tier = $HealthTiers[$(if ($null -eq $halves) { 5 } else { $halves })]
    $m.cur = $mood

    $f = @{ feet = 'both'; look = 0; eyes = 'open'; arms = 'down'; flip = $false; lift = 0.0
           off = 0; x = 0; facing = ''; poof = ''; shadow = ''; soul = 0.0; soulT = 0; dig = 0; spray = 0 }
    $bubble = ''; $zzz = $false
    switch ($mood) {
        'sleep' { $f.eyes = 'closed'; $zzz = $true }
        'doze'  { $f.eyes = 'blink'; $zzz = $true }
        'dead'  { $f.flip = $true; $f.eyes = 'x' }
        'wait'  { $f.eyes = 'wide'; $bubble = '?' }
        'work'  { $f.eyes = 'focus' }
    }
    # Tired eyes as the limit runs out, as in the lively Clawd.
    if ($tier.eyes -and $f.eyes -in @('open', 'focus')) { $f.eyes = $tier.eyes }

    $geo = Get-MascotGeo $f
    if (-not [object]::ReferenceEquals($geo, $m.key)) {
        $m.key = $geo
        $UI.MascotBody.Data = $geo.body
        $UI.MascotEyes.Data = $geo.eyes
        $UI.MascotFx.Data   = $geo.fx
        $UI.MascotSand.Data = $geo.sand
        for ($i = 0; $i -lt $script:SkinPaths.Count; $i++) { $script:SkinPaths[$i].Data = $geo.acc[$i] }
    }
    if ($mascotTimer.Interval.TotalMilliseconds -ne $CalmFrameMs) { $mascotTimer.Interval = [TimeSpan]::FromMilliseconds($CalmFrameMs) }
    [System.Windows.Controls.Canvas]::SetLeft($UI.Mascot, [math]::Round($m.x))
    [System.Windows.Controls.Canvas]::SetBottom($UI.Mascot, - $MascotSink)

    # A still "z" over the head while he sleeps.
    $z = $UI.MascotZ
    if ($zzz) {
        $z.Visibility = 'Visible'; $z.FontSize = 9; $z.Opacity = 0.8
        [System.Windows.Controls.Canvas]::SetLeft($z, $m.x + 28)
        [System.Windows.Controls.Canvas]::SetBottom($z, 19)
    } else { $z.Visibility = 'Collapsed' }

    # "?" over the head while a session waits for you.
    $b = $UI.MascotBubble
    if ($bubble) {
        $b.Visibility = 'Visible'
        if ($b.Text -ne $bubble) { $b.Text = $bubble; $b.Foreground = New-Brush $Palette.warn.Wpf }
        [System.Windows.Controls.Canvas]::SetLeft($b, $m.x + $MascotW / 2 - 6)
        [System.Windows.Controls.Canvas]::SetBottom($b, 22)
    } else { $b.Visibility = 'Collapsed' }

    # Near the limit: one still drop of sweat.
    $s = $UI.MascotSweat
    if (($m.crit -or $m.forceCrit -or $tier.sweat) -and $mood -notin @('sleep', 'dead')) {
        $s.Visibility = 'Visible'; $s.Opacity = 0.9
        [System.Windows.Controls.Canvas]::SetLeft($s, 2)
        [System.Windows.Controls.Canvas]::SetTop($s, 1)
    } else { $s.Visibility = 'Collapsed' }

    Step-Hearts
    foreach ($r in $script:Dust) { $r.Visibility = 'Collapsed' }
    foreach ($c in $script:Confetti) { $c.r.Visibility = 'Collapsed' }
    $UI.MascotLove.Visibility = 'Collapsed'
    $UI.MascotSoul.Visibility = 'Collapsed'
    if ($UI.MascotTag.Text) { $UI.MascotTag.Text = '' }
}
