# ------------------------------------------------------------- christmas ----
# The Christmas theme, a snowy holiday night: snow falling over the whole window
# and a garland of coloured lights along its top, blinking in turns; in the sky row
# snowdrifts with a little house smoking from its chimney, a snowman, a decorated
# tree with twinkling lights and a glowing star, and now and then Santa's sleigh
# flying across. Clawd's Santa hat suits it.

$XmasFx  = New-SceneBackdrop
$XmasSky = New-SceneSky
$XmasPx  = 1.6
$script:Xmas = @{ w = 0; sleigh = $null; wait = 120 }

# Snowflakes: specks of one to two pixels and a few little crosses, falling and swaying.
$script:XmasFlakes = @()
for ($i = 0; $i -lt 44; $i++) {
    if ($i % 8 -eq 0) {
        $e = New-ScenePixels $XmasFx @('.w.', 'www', '.w.') 1.2 @{ w = '#CCF8FAFC' }
    } else {
        $d = @(1, 1.5, 1.5, 2)[$script:Rnd.Next(4)]
        $e = New-SceneShape $XmasFx Rectangle $d $d '#B3F8FAFC'
    }
    $script:XmasFlakes += @{ e = $e; x = 0.0; y = -99.0; v = 0.0; ph = 0.0; amp = 0.0 }
}

# The garland: a wire sagging between hooks along the top, bulbs in four colours
# lit in turns - each bulb a glow and a pixel, so that the glow can breathe.
$XmasWire = New-SceneShape $XmasFx Path 0 0 $null
$XmasWire.Stroke = New-SceneBrush '#80584A4E'
$XmasWire.StrokeThickness = 1
$XmasBulbColors = @('#F87171', '#FCD34D', '#4ADE80', '#60A5FA')
$script:Bulbs = @()
for ($i = 0; $i -lt 36; $i++) {
    $hex = $XmasBulbColors[$i % 4]
    $glow = New-SceneShape $XmasFx Ellipse 10 10 (New-Glow $hex 0.45)
    $dot = New-SceneShape $XmasFx Rectangle 2 3 $hex
    $script:Bulbs += @{ glow = $glow; dot = $dot; k = $i % 4 }
}
$XmasSpan = 56   # between two hooks
$XmasStep = 14   # between two bulbs

# The sag of the wire at x: zero at the hooks, deepest between them.
function Get-XmasSag([double]$x) { return 2 + 5 * [math]::Sin([math]::PI * (($x % $XmasSpan) / $XmasSpan)) }

function Set-XmasGarland([double]$w) {
    $g = New-Object System.Windows.Media.StreamGeometry
    $ctx = $g.Open()
    $ctx.BeginFigure((New-Object System.Windows.Point 0, (Get-XmasSag 0)), $false, $false)
    for ($x = 2; $x -le $w; $x += 2) { $ctx.LineTo((New-Object System.Windows.Point $x, (Get-XmasSag $x)), $true, $false) }
    $ctx.Close()
    $g.Freeze()
    $XmasWire.Data = $g
    for ($i = 0; $i -lt $script:Bulbs.Count; $i++) {
        $b = $script:Bulbs[$i]
        $x = 7 + $i * $XmasStep
        $vis = $(if ($x -lt $w - 4) { 'Visible' } else { 'Collapsed' })
        $b.glow.Visibility = $vis; $b.dot.Visibility = $vis
        $y = Get-XmasSag $x
        Set-At $b.dot ($x - 1) ($y + 0.5)
        Set-At $b.glow ($x - 5) ($y - 3)
    }
}

# The sky row's ground: snowdrifts with a bluish shade along their tops.
$drift = @('', '', '', '', '')
for ($x = 0; $x -lt 170; $x++) {
    $top = [int][math]::Round(1.6 + 1.2 * [math]::Sin($x / 9.0) + 0.8 * [math]::Sin($x / 4.0 + 1))
    for ($r = 0; $r -lt 5; $r++) {
        $drift[$r] += $(if ($r -lt $top) { '.' } elseif ($r -eq $top -and $r -lt 4) { 'b' } else { 'w' })
    }
}

# A house: a snowy roof, a chimney, a warm window and a door.
$XmasHouse = New-Object System.Windows.Controls.Canvas
[void]$XmasSky.Children.Add($XmasHouse)
$HouseArt = @(
    '......w.cc...',
    '.....wwwcc...',
    '....wwwwwc...',
    '...wwwwwww...',
    '..wwwwwwwww..',
    '.wwwwwwwwwww.',
    '..rrrrrrrrr..',
    '..hhhhhhhhh..',
    '..hyyhhhddh..',
    '..hyyhhhddh..',
    '..hhhhhhddh..'
)
[void](New-ScenePixels $XmasHouse $HouseArt $XmasPx @{
    c = '#FF7F1D1D'; w = '#FFF1F5F9'; r = '#FF991B1B'; h = '#FF92400E'; d = '#FF451A03' })
$HouseLight = New-ScenePixels $XmasHouse $HouseArt $XmasPx @{ y = '#FFFDE68A' }
$HouseGlow = New-SceneShape $XmasHouse Ellipse 14 14 (New-Glow '#FCD34D' 0.5)
Set-At $HouseGlow (3.5 * $XmasPx - 7) (9 * $XmasPx - 7)
$script:Smoke = @()
for ($i = 0; $i -lt 4; $i++) {
    $script:Smoke += @{ e = (New-SceneShape $XmasHouse Rectangle $XmasPx $XmasPx '#FFCBD5E1'); k = $i / 4.0 }
}

# A snowman in a top hat and a red scarf, with stick arms.
$XmasSnowman = New-ScenePixels $XmasSky @(
    '....kkk....',
    '....kkk....',
    '...kkkkk...',
    '...wwwww...',
    '...wewew...',
    '...wwwnn...',
    '...wwwww...',
    '..rrrrrrr..',
    'a..wwwwr..a',
    '.awwwbwwra.',
    '..wwwwwwww.',
    '.wwwwbwwww.',
    '.wwwwwwwww.',
    '..wwwwwww..'
) $XmasPx @{ k = '#FF1F2937'; w = '#FFF8FAFC'; e = '#FF0F172A'; n = '#FFFB923C'; r = '#FFDC2626'; b = '#FF334155'; a = '#FF92400E' }

# The tree: snow on its tiers, lights in three colours twinkling apart, and a star.
$TreeArt = @(
    '......s......',
    '.....sss.....',
    '......g......',
    '.....ggg.....',
    '....gggrg....',
    '...ggwggwg...',
    '.....gyg.....',
    '....ggggb....',
    '...grggggg...',
    '..gwgggywgg..',
    '....bgggg....',
    '...ggggrgg...',
    '..gyggggggb..',
    '.wggrgggyggw.',
    'gggggbggggrgg',
    '.....ttt.....',
    '.....ttt.....'
)
$XmasTree = New-Object System.Windows.Controls.Canvas
[void]$XmasSky.Children.Add($XmasTree)
$TreeStarGlow = New-SceneShape $XmasTree Ellipse 16 16 (New-Glow '#FDE047' 0.55)
Set-At $TreeStarGlow (6.5 * $XmasPx - 8) (1 * $XmasPx - 8)
[void](New-ScenePixels $XmasTree $TreeArt $XmasPx @{
    g = '#FF15803D'; w = '#FFE2E8F0'; t = '#FF78350F'; s = '#FFFDE047' })
# Under the lights, what the twinkling falls back to: dark bulbs on the tree.
$TreeOff = New-ScenePixels $XmasTree $TreeArt $XmasPx @{ r = '#FF14532D'; y = '#FF14532D'; b = '#FF14532D' }
$script:TreeLights = @()
foreach ($l in @(@('r', '#FFF87171'), @('y', '#FFFCD34D'), @('b', '#FF60A5FA'))) {
    $script:TreeLights += New-ScenePixels $XmasTree $TreeArt $XmasPx @{ $l[0] = $l[1] }
}

# The ground in front of the house, the snowman and the tree.
$XmasDrift = New-ScenePixels $XmasSky $drift $XmasPx @{ w = '#F2F1F5F9'; b = '#FFFFFFFF' }

# Santa's sleigh behind two reindeer, the front one with a red nose; two frames of legs.
function New-SleighArt([int]$f) {
    $legs = $(if ($f -eq 0) { '.e...e...' } else { 'e.....e..' })
    $sleigh = @('....w......', '...rr......', '..rffr.....', '..wwwwkk...', 'y.rrrrkkk..', 'yqqqqqqqqq.', '.yyyyyyyyyy')
    $deer   = @('.........', '......a.a', '.......a.', '......ddn', '.ddddddd.', '.dddddd..', $legs)
    $reins  = @('..', '..', '..', '..', 'll', '..', '..')
    $rows = @()
    for ($r = 0; $r -lt 7; $r++) {
        $back = $deer[$r].Replace('n', 'd')
        $rows += $sleigh[$r] + $reins[$r] + $back + $reins[$r] + $deer[$r]
    }
    return $rows
}
$SleighColors = @{ r = '#FFEF4444'; w = '#FFF8FAFC'; f = '#FFFED7AA'; y = '#FFFBBF24'; q = '#FFB91C1C'
                   k = '#FF78350F'; l = '#FFFCD34D'; a = '#FFD6A35C'; d = '#FFB45309'; e = '#FF78350F'; n = '#FFF87171' }
$XmasSleigh = New-Object System.Windows.Controls.Canvas
[void]$XmasSky.Children.Add($XmasSleigh)
$SleighFrames = @(
    (New-ScenePixels $XmasSleigh (New-SleighArt 0) $XmasPx $SleighColors),
    (New-ScenePixels $XmasSleigh (New-SleighArt 1) $XmasPx $SleighColors)
)
$SleighW = 33 * $XmasPx
$XmasSleigh.Visibility = 'Collapsed'

function Step-Christmas([int]$t) {
    $s = $script:Xmas
    $w = $XmasFx.ActualWidth; $h = $XmasFx.ActualHeight
    if ($w -le 0 -or $h -le 0) { return }
    if ($w -ne $s.w) { $s.w = $w; Set-XmasGarland $w }

    foreach ($f in $script:XmasFlakes) {
        if ($f.y -gt $h + 4 -or $f.y -lt -50) {
            $f.x = $script:Rnd.NextDouble() * $w
            $f.y = $(if ($f.y -lt -50) { $script:Rnd.NextDouble() * $h } else { -4 })
            $f.v = 0.25 + 0.5 * $script:Rnd.NextDouble()
            $f.amp = 1 + 3 * $script:Rnd.NextDouble(); $f.ph = $script:Rnd.NextDouble() * 6.28
        }
        $f.y += $f.v
        Set-At $f.e ($f.x + $f.amp * [math]::Sin($t / 15.0 + $f.ph)) $f.y
    }
    # Bulbs: one colour after another lights up brightly while the rest glow dimly.
    $lit = [int][math]::Floor($t / 8) % 4
    foreach ($b in $script:Bulbs) {
        if ($b.dot.Visibility -ne 'Visible') { continue }
        $on = ($b.k -eq $lit)
        $b.dot.Opacity = $(if ($on) { 1 } else { 0.55 })
        $b.glow.Opacity = $(if ($on) { 0.9 } else { 0.25 })
    }

    # The sky row.
    $sw = $UI.Sky.ActualWidth; $sh = $UI.Sky.ActualHeight
    if ($UI.Sky.Visibility -ne 'Visible' -or $sw -le 0) { return }
    $floor = $sh - 3 * $XmasPx
    Set-At $XmasDrift 0 ($floor - 2 * $XmasPx)
    Set-At $XmasHouse ([math]::Round($sw * 0.24)) ($floor - 11 * $XmasPx)
    Set-At $XmasSnowman ([math]::Round($sw * 0.41)) ($floor - 13 * $XmasPx)
    Set-At $XmasTree ([math]::Round($sw * 0.56)) ($floor - 16 * $XmasPx)

    # The window flickers like a fire inside; smoke puffs rise from the chimney and fade.
    $fl = 0.75 + 0.15 * [math]::Sin($t / 3.0) + 0.1 * [math]::Sin($t / 1.7)
    $HouseLight.Opacity = $fl; $HouseGlow.Opacity = $fl
    foreach ($p in $script:Smoke) {
        $k = (($t / 60.0) + $p.k) % 1
        $p.e.Opacity = 0.7 * (1 - $k)
        $p.e.Width = $XmasPx * (1 + $k); $p.e.Height = $p.e.Width
        Set-At $p.e (8.5 * $XmasPx + 2 * $k + [math]::Sin($t / 9.0 + $p.k * 6) * $k * 2) (-$k * 14)
    }

    # Tree lights twinkle in three groups; the star breathes.
    for ($i = 0; $i -lt $script:TreeLights.Count; $i++) {
        $script:TreeLights[$i].Opacity = [math]::Max(0, [math]::Min(1, 0.5 + 0.7 * [math]::Sin($t / 5.0 + $i * 2.1)))
    }
    $TreeStarGlow.Opacity = 0.6 + 0.4 * [math]::Sin($t / 7.0)

    # The sleigh: after a while away, across the sky from the left, bobbing.
    if ($null -eq $s.sleigh) {
        $s.wait--
        if ($s.wait -le 0) { $s.sleigh = -$SleighW; $XmasSleigh.Visibility = 'Visible' }
    } else {
        $s.sleigh += 0.7
        if ($s.sleigh -gt $sw) {
            $s.sleigh = $null; $s.wait = 400 + $script:Rnd.Next(600)
            $XmasSleigh.Visibility = 'Collapsed'
        } else {
            $leg = [int]([math]::Floor($t / 3) % 2)
            $SleighFrames[0].Visibility = $(if ($leg -eq 0) { 'Visible' } else { 'Collapsed' })
            $SleighFrames[1].Visibility = $(if ($leg -eq 1) { 'Visible' } else { 'Collapsed' })
            Set-At $XmasSleigh ([math]::Round($s.sleigh)) ([math]::Round(4 + 2 * [math]::Sin($t / 10.0)))
        }
    }
}

$Scenes.christmas = @{ back = $XmasFx; sky = $XmasSky; step = ${function:Step-Christmas} }
Sync-Scene
