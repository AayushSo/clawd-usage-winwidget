# ------------------------------------------------------------- cyberpunk ----
# The Cyberpunk theme, a night in a neon megacity: behind the whole window neon
# rain falling, the city's glow along the bottom and now and then a glitch tearing
# across in red and cyan; in the sky row a skyline with flickering windows, a tall
# tower with a blinking beacon and searchlights, neon signs ("2077" on a roof)
# stuttering, and flying cars crossing between the towers. Clawd's Rockerboy and
# Netrunner skins suit it.

$CyberFx  = New-SceneBackdrop
$CyberSky = New-SceneSky
$CyberPx  = 1.6
$script:Cyber = @{ glitch = -1; wait = 150; jx = 0; relic = -1; night = $null; jacked = $null; woke = $false }

# The city's glow along the bottom: magenta and cyan, drifting.
$script:CyberGlow = @()
foreach ($g in @(@('#FF2A6D', 0.13), @('#05D9E8', 0.10), @('#B026FF', 0.10))) {
    $script:CyberGlow += @{ e = (New-SceneShape $CyberFx Ellipse 10 10 (New-Glow $g[0] $g[1])); ph = $script:Rnd.NextDouble() * 6.28 }
}

# Rain: thin streaks in the neon's colours, falling fast.
$script:CyberRain = @()
for ($i = 0; $i -lt 36; $i++) {
    $hex = @('#8005D9E8', '#6605D9E8', '#66FF2A6D', '#4DE0F2FE')[$i % 4]
    $r = New-SceneShape $CyberFx Rectangle 1 (6 + $script:Rnd.Next(7)) $hex
    $script:CyberRain += @{ r = $r; x = 0.0; y = -999.0; v = 0.0 }
}

# A glitch: bars of red and cyan torn across the window for a moment.
$script:CyberBars = @()
foreach ($hex in @('#66FF003C', '#5500F0FF', '#4DFF003C', '#4400F0FF', '#33FCEE0A')) {
    $r = New-SceneShape $CyberFx Rectangle 10 2 $hex
    $r.Visibility = 'Collapsed'
    $script:CyberBars += $r
}

# The skyline: a row of buildings as pixel art, bottom-aligned; lit windows are
# letters of their own, a few groups, each flickering on its own.
$CityRows = 26; $CityCols = 170
function New-CityArt([object[]]$blocks, [int]$lit, [string]$wins) {
    $g = @()
    for ($y = 0; $y -lt $CityRows; $y++) { $g += , (New-Object char[] $CityCols) }
    for ($y = 0; $y -lt $CityRows; $y++) { for ($x = 0; $x -lt $CityCols; $x++) { $g[$y][$x] = '.' } }
    foreach ($b in $blocks) {
        for ($y = $CityRows - $b.h; $y -lt $CityRows; $y++) {
            for ($x = $b.x; $x -lt [math]::Min($CityCols, $b.x + $b.w); $x++) {
                $g[$y][$x] = 'b'
                # Windows: every other cell inside the walls, some of them lit.
                $wx = $x - $b.x; $wy = $y - ($CityRows - $b.h)
                if ($b.nowin -or $wx -lt 1 -or $wx -ge $b.w - 1 -or $wy -lt 1 -or $wx % 2 -eq 0 -or $wy % 2 -eq 0) { continue }
                if ($script:Rnd.Next(100) -lt $lit) { $g[$y][$x] = $wins[$script:Rnd.Next($wins.Length)] }
            }
        }
    }
    return @($g | ForEach-Object { -join $_ })
}

# Far: a crowd of towers in haze, and the tallest one with its antenna.
$far = @(); $x = 0
while ($x -lt $CityCols) {
    $w = 5 + $script:Rnd.Next(8)
    $far += @{ x = $x; w = $w; h = 8 + $script:Rnd.Next(10) }
    $x += $w + $script:Rnd.Next(2)
}
$TowerX = 92
$far += @{ x = $TowerX; w = 9; h = 21 }
$far += @{ x = $TowerX + 2; w = 5; h = 24; nowin = $true }
$far += @{ x = $TowerX + 4; w = 1; h = 26; nowin = $true }
$FarArt = New-CityArt $far 22 'xyz'
$CityFar = @{ c = (New-ScenePixels $CyberSky $FarArt $CyberPx @{ b = '#FF1E1436' }); wins = @() }
foreach ($k in @('x', 'y', 'z')) {
    $CityFar.wins += @{ c = (New-ScenePixels $CyberSky $FarArt $CyberPx @{ $k = @('#B3FCEE0A', '#9905D9E8', '#99FF2A6D')[$CityFar.wins.Count] })
                        ph = $script:Rnd.NextDouble() * 6.28 }
}

# Searchlights from the tower's top, sweeping the sky above the row: on the
# backdrop, since the tower reaches the row's top edge.
$BeamLen = 80
$script:CyberBeams = @()
foreach ($ph in @(0.0, 2.6)) {
    # A cone, widening upwards from its tip at the bottom.
    $r = New-SceneShape $CyberFx Polygon 0 0 (New-Object System.Windows.Media.LinearGradientBrush (
        (ConvertTo-Color '#0005D9E8'), (ConvertTo-Color '#3305D9E8'), 90))
    $r.Points = [System.Windows.Media.PointCollection]::Parse("8,$BeamLen 0,0 16,0")
    $r.RenderTransform = New-Object System.Windows.Media.RotateTransform 0, 8, $BeamLen
    $script:CyberBeams += @{ r = $r; ph = $ph }
}
$Beacon = New-SceneShape $CyberSky Rectangle $CyberPx $CyberPx '#FFFF003C'
$BeaconGlow = New-SceneShape $CyberSky Ellipse 12 12 (New-Glow '#FF003C' 0.6)

# Flying cars between the far and the near towers: a big one heading right,
# a small one farther off heading left, headlights in front, tail lights behind.
$script:Cars = @()
foreach ($a in @(
    @{ art = @('...kkkk...', 'rkkkkkkkkh', '..k....k..'); px = $CyberPx; dir = 1; v = 0.9; w = 10 }
    @{ art = @('.kkk.', 'hkkkr'); px = 1.2; dir = -1; v = 0.5; w = 5 }
)) {
    $c = New-Object System.Windows.Controls.Canvas
    [void]$CyberSky.Children.Add($c)
    $lamp = $(if ($a.dir -gt 0) { $a.w * $a.px } else { 0 })
    $g = New-SceneShape $c Ellipse 10 10 (New-Glow '#E0FFFF' 0.45)
    Set-At $g ($lamp - 5) ($a.px * 1.5 - 5)
    [void](New-ScenePixels $c $a.art $a.px @{ k = '#FF3B3656'; h = '#FFE0FFFF'; r = '#FFFF003C' })
    if ($a.dir -lt 0) { $c.Opacity = 0.75 }
    $script:Cars += @{ c = $c; dir = $a.dir; v = $a.v; w = $a.w * $a.px; x = $null; fy = 0.0; ph = 0.0 }
}

# Near: lower and darker blocks in front, brighter windows.
$near = @(); $x = 0
while ($x -lt $CityCols) {
    $w = 6 + $script:Rnd.Next(9)
    $near += @{ x = $x; w = $w; h = 3 + $script:Rnd.Next(7) }
    $x += $w + $script:Rnd.Next(3)
}
# Signs go on two of them, between the percentage and Clawd: the tallest one starting
# in each range (blocks are at most 14 wide with gaps of 2, so there is always one).
function Get-NearAt([double]$from, [double]$to) {
    return @($near | Where-Object { $_.x -ge $CityCols * $from -and $_.x -le $CityCols * $to } |
        Sort-Object { $_.h } -Descending)[0]
}
$SignRoof = Get-NearAt 0.45 0.55
$SignSide = Get-NearAt 0.26 0.36
$SignRoof.h = [math]::Max($SignRoof.h, 6); $SignRoof.w = [math]::Max($SignRoof.w, 13)
$SignSide.h = [math]::Max($SignSide.h, 12)
$NearArt = New-CityArt $near 30 'uv'
$CityNear = @{ c = (New-ScenePixels $CyberSky $NearArt $CyberPx @{ b = '#FF0B0716' }); wins = @() }
foreach ($k in @('u', 'v')) {
    $CityNear.wins += @{ c = (New-ScenePixels $CyberSky $NearArt $CyberPx @{ $k = @('#FFFCEE0A', '#E605D9E8')[$CityNear.wins.Count] })
                         ph = $script:Rnd.NextDouble() * 6.28 }
}

# Neon signs, stuttering now and then: "2077" on a roof, a column of glyphs on a wall.
function New-Sign([string[]]$art, [string]$hex, [double]$gw, [double]$gh) {
    $c = New-Object System.Windows.Controls.Canvas
    [void]$CyberSky.Children.Add($c)
    $w = $art[0].Length * $CyberPx; $h = $art.Count * $CyberPx
    $g = New-SceneShape $c Ellipse ($w + $gw) ($h + $gh) (New-Glow ('#' + $hex.Substring(3)) 0.55)
    Set-At $g (-$gw / 2) (-$gh / 2)
    [void](New-ScenePixels $c $art $CyberPx @{ n = $hex })
    return @{ c = $c; off = 0 }
}
$script:Signs = @(
    @{ s = (New-Sign @('nnn.nnn.nnn.nnn', '..n.n.n...n...n', 'nnn.n.n...n...n', 'n...n.n...n...n', 'nnn.nnn...n...n') '#FF00F0FF' 14 10)
       b = $SignRoof; dx = [math]::Floor(($SignRoof.w - 15) / 2); dy = -6 }
    @{ s = (New-Sign @('nnn', 'n.n', 'nnn', '...', '.n.', 'nnn', '.n.', '...', 'n.n', '.n.', 'n.n') '#FFFF2A6D' 10 14)
       b = $SignSide; dx = $SignSide.w; dy = 1 }
)

# The malfunction, a secret: at 20:77 (21:17, that is), if Clawd is asleep, a
# storm of glitches, the window flushes red, an error box types out a quote and
# Clawd, woken up, flickers into the Netrunner - jacked in - waves, comes back and
# goes to sleep again.
# A layer of its own above the content, not under it like the backdrop.
$RelicLen = 110
$RelicFx = New-SceneBackdrop
$win.Content.Child.Children.Remove($RelicFx)
[void]$win.Content.Child.Children.Add($RelicFx)
$RelicTint = New-SceneShape $RelicFx Rectangle 10 10 '#FFFF003C'
$script:RelicBars = @()
foreach ($hex in @('#99FF003C', '#8800F0FF', '#77FF003C', '#6600F0FF', '#66F2FBFF', '#55FCEE0A')) {
    $script:RelicBars += New-SceneShape $RelicFx Rectangle 10 2 $hex
}
$RelicBox = New-Object System.Windows.Controls.Border
$RelicBox.Background = New-SceneBrush '#EE0C0B16'
$RelicBox.BorderBrush = New-SceneBrush '#FFFF003C'
$RelicBox.BorderThickness = 1
$RelicBox.Padding = New-Object System.Windows.Thickness 8, 5, 8, 7
$stack = New-Object System.Windows.Controls.StackPanel
$RelicHead = New-Object System.Windows.Controls.TextBlock
$RelicHead.FontFamily = 'Consolas'; $RelicHead.FontSize = 9; $RelicHead.FontWeight = 'Bold'
$RelicHead.Foreground = New-SceneBrush '#FFFF003C'
$RelicHead.Margin = New-Object System.Windows.Thickness 0, 0, 0, 3
[void]$stack.Children.Add($RelicHead)
# The quote three times: red and cyan copies jittering off the white one.
$quote = New-Object System.Windows.Controls.Grid
$script:RelicText = @()
foreach ($l in @(@('#B3FF003C', -1.5), @('#B300F0FF', 1.5), @('#FFF2FBFF', 0))) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.FontFamily = 'Consolas'; $tb.FontSize = 12; $tb.FontWeight = 'Bold'; $tb.TextWrapping = 'Wrap'
    $tb.Foreground = New-SceneBrush $l[0]
    $tb.RenderTransform = New-Object System.Windows.Media.TranslateTransform $l[1], 0
    [void]$quote.Children.Add($tb)
    $script:RelicText += @{ tb = $tb; dx = $l[1] }
}
[void]$stack.Children.Add($quote)
$RelicBox.Child = $stack
[void]$RelicFx.Children.Add($RelicBox)

# The widget itself goes haywire: numbers jump, captions crumble into junk and the
# bars twitch; what was shown is kept and put back at the end. Only plain text -
# a caption made of several runs (a link, a coloured mark) is left alone.
$RelicJunk = '#%&@$!?/\|<>~^*=+0123456789' + [string][char]0x2591 + [char]0x2592 + [char]0x2593 + [char]0x2588 + [char]0xA4 + [char]0xA7 + [char]0xC6 + [char]0xD8
$script:RelicSaved = $null

function Get-RelicTexts($el, $list) {
    if ($el -eq $RelicFx) { return }
    if ($el -is [System.Windows.Controls.TextBlock]) {
        $plain = $el.Inlines.Count -eq 0 -or ($el.Inlines.Count -eq 1 -and $el.Inlines.FirstInline -is [System.Windows.Documents.Run])
        if ($plain -and $el.Text) { [void]$list.Add(@{ tb = $el; text = $el.Text }) }
        return
    }
    if (-not ($el -is [System.Windows.Media.Visual])) { return }
    for ($i = 0; $i -lt [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($el); $i++) {
        Get-RelicTexts ([System.Windows.Media.VisualTreeHelper]::GetChild($el, $i)) $list
    }
}

function Set-RelicHaywire([double]$p) {
    if ($p -le 0) {
        if (-not $script:RelicSaved) { return }
        foreach ($x in $script:RelicSaved.texts) { $x.tb.Text = $x.text }
        foreach ($b in $script:RelicSaved.bars) { $b.bar.Width = $b.w }
        $script:RelicSaved = $null
        return
    }
    if (-not $script:RelicSaved) {
        $texts = New-Object System.Collections.ArrayList
        Get-RelicTexts $win.Content $texts
        $script:RelicSaved = @{ texts = $texts; bars = @(foreach ($b in @($UI.BarSession, $UI.BarWeek, $UI.BarFable)) {
            if ($b) { @{ bar = $b; w = $b.Width } } }) }
    }
    foreach ($x in $script:RelicSaved.texts) {
        $sb = New-Object System.Text.StringBuilder
        foreach ($ch in $x.text.ToCharArray()) {
            if ([char]::IsDigit($ch)) { [void]$sb.Append([char](48 + $script:Rnd.Next(10))) }
            elseif (-not [char]::IsWhiteSpace($ch) -and $script:Rnd.NextDouble() -lt $p) { [void]$sb.Append($RelicJunk[$script:Rnd.Next($RelicJunk.Length)]) }
            else { [void]$sb.Append($ch) }
        }
        $x.tb.Text = $sb.ToString()
    }
    foreach ($b in $script:RelicSaved.bars) {
        if ($b.w -is [double] -and -not [double]::IsNaN($b.w)) { $b.bar.Width = $BarWidth * $script:Rnd.NextDouble() }
    }
}

# Clawd as the Netrunner, or back as himself; $null - not swapped.
function Set-RelicJack([bool]$on) {
    $s = $script:Cyber
    if ($on -eq [bool]$s.jacked) { return }
    if ($on) {
        $j = (Get-Skins)['netrunner']
        if (-not $j) { return }
        Show-Skin $j
    } else { Set-Skin -Force }
    $s.jacked = $on
}

function Step-Relic([int]$k, [double]$w, [double]$h) {
    $s = $script:Cyber
    if ($k -lt 0) {
        $RelicFx.Visibility = 'Collapsed'
        Set-RelicJack $false
        Set-RelicHaywire 0
        # Back to sleep, unless the mood was set by hand meanwhile.
        if ($s.woke -and $script:Mz.force -eq 'idle') { $script:Mz.force = $null }
        $s.woke = $false
        return
    }
    $RelicFx.Visibility = 'Visible'
    $RelicHead.Text = T 'cyber.relic'
    $storm = $k -lt 15 -or $k -ge $RelicLen - 12
    $RelicTint.Width = $w; $RelicTint.Height = $h
    $RelicTint.Opacity = $(if ($storm) { ($k % 2) * 0.12 } else { 0.07 + 0.04 * [math]::Sin($k / 2.0) })
    foreach ($r in $script:RelicBars) {
        if (-not $storm -and $script:Rnd.Next(5) -gt 0) { $r.Visibility = 'Collapsed'; continue }
        $r.Visibility = 'Visible'
        $r.Width = $w * (0.15 + 0.8 * $script:Rnd.NextDouble()); $r.Height = 1 + $script:Rnd.Next(5)
        Set-At $r ($script:Rnd.NextDouble() * ($w - $r.Width)) ($script:Rnd.NextDouble() * $h)
    }
    if ($storm) { $s.jx = $(if ($script:Rnd.Next(2) -eq 0) { -3 } else { 3 }) } elseif ($s.glitch -lt 0) { $s.jx = 0 }
    # Every other tick, stronger in the storms; calm for the last few ticks before the end.
    if ($k -ge $RelicLen - 4) { Set-RelicHaywire 0 }
    elseif ($k % 2 -eq 0) { Set-RelicHaywire $(if ($storm) { 0.6 } else { 0.2 }) }

    # The error box: under the sky row, blinking out now and then, the quote typing itself.
    $RelicBox.Visibility = $(if ($storm -or $k % 17 -eq 0) { 'Collapsed' } else { 'Visible' })
    $RelicBox.Width = [math]::Max(80, $w - 32)
    $y = $h * 0.4
    if ($UI.Sky.Visibility -eq 'Visible' -and $UI.Sky.ActualHeight -gt 0) {
        $y = $UI.Sky.TranslatePoint((New-Object System.Windows.Point 0, $UI.Sky.ActualHeight), $RelicFx).Y + 8
    }
    Set-At $RelicBox 16 ([math]::Round($y))
    $q = T 'cyber.samurai'
    $n = [math]::Max(0, [math]::Min($q.Length, [int](($k - 18) * 1.4)))
    foreach ($l in $script:RelicText) {
        $l.tb.Text = $q.Substring(0, $n) + $(if ($n -lt $q.Length -and $k % 4 -lt 2) { '_' } else { '' })
        $l.tb.RenderTransform.X = $(if ($l.dx -and $script:Rnd.Next(4) -eq 0) { $l.dx * (2 + $script:Rnd.Next(3)) } else { $l.dx })
    }

    # Clawd: woken up by the noise, he climbs out of the sand; the Netrunner flickers
    # through, then stays for a while and waves.
    if ($k -eq 12 -and $script:Mz.mood -eq 'sleep' -and -not $script:Mz.force) { $script:Mz.force = 'idle'; $s.woke = $true }
    $j = $k -ge 20 -and $k -lt $RelicLen - 15 -and ($k -ge 48 -or [math]::Floor($k / 3) % 2 -eq 0)
    Set-RelicJack $j
    if ($k -eq 55) {
        $m = $script:Mz
        if ($m -and -not $m.act -and $m.mood -ne 'dead' -and $m.cur -ne 'dead' -and -not $m.buried) { Start-MascotAct 'wave' }
    }
}

# Switched to another theme or hidden halfway through - it ends, and Clawd is himself.
$CyberFx.add_IsVisibleChanged({
    if (-not $CyberFx.IsVisible -and $script:Cyber.relic -ge 0) { $script:Cyber.relic = -1; Step-Relic -1 0 0 }
})

function Step-Cyberpunk([int]$t) {
    $s = $script:Cyber
    $w = $CyberFx.ActualWidth; $h = $CyberFx.ActualHeight
    if ($w -le 0 -or $h -le 0) { return }

    for ($i = 0; $i -lt $script:CyberGlow.Count; $i++) {
        $g = $script:CyberGlow[$i]
        $gw = $w * (0.8 + 0.2 * $i); $gh = 90 + 20 * $i
        $g.e.Width = $gw; $g.e.Height = $gh
        $g.e.Opacity = 0.75 + 0.25 * [math]::Sin($t / 35.0 + $g.ph)
        Set-At $g.e ($w * (0.5 + 0.4 * [math]::Sin($t / (300.0 + 50 * $i) + $g.ph)) - $gw / 2) ($h - $gh * 0.5)
    }
    foreach ($d in $script:CyberRain) {
        if ($d.y -gt $h) {
            $d.x = [math]::Round($script:Rnd.NextDouble() * $w)
            $d.y = $(if ($d.y -lt -100) { $script:Rnd.NextDouble() * $h } else { -12 - 40 * $script:Rnd.NextDouble() })
            $d.v = 5 + 4 * $script:Rnd.NextDouble()
        }
        $d.y += $d.v
        Set-At $d.r $d.x ([math]::Round($d.y))
    }

    # The glitch: a few ticks of torn bars, the sky row jerking aside with them.
    if ($s.glitch -lt 0) {
        $s.wait--
        if ($s.wait -le 0) { $s.glitch = 0 }
    }
    if ($s.glitch -ge 0) {
        foreach ($r in $script:CyberBars) {
            if ($script:Rnd.Next(3) -eq 0) { $r.Visibility = 'Collapsed'; continue }
            $r.Visibility = 'Visible'
            $r.Width = $w * (0.2 + 0.7 * $script:Rnd.NextDouble()); $r.Height = 1 + $script:Rnd.Next(4)
            Set-At $r ($script:Rnd.NextDouble() * ($w - $r.Width)) ($script:Rnd.NextDouble() * $h)
        }
        $s.jx = $(if ($script:Rnd.Next(2) -eq 0) { -2 } else { 2 })
        $s.glitch++
        if ($s.glitch -ge 7) {
            $s.glitch = -1; $s.wait = 250 + $script:Rnd.Next(450); $s.jx = 0
            foreach ($r in $script:CyberBars) { $r.Visibility = 'Collapsed' }
        }
    }

    # 20:77 strikes - while Clawd sleeps and the window is on screen, once an evening.
    if ($s.relic -lt 0 -and $t % 10 -eq 0) {
        $now = Get-Date
        if ($now.Hour -eq 21 -and $now.Minute -eq 17 -and $s.night -ne $now.Date -and $script:Mz.mood -eq 'sleep') {
            $s.night = $now.Date
            $s.relic = 0
        }
    }
    if ($s.relic -ge 0) {
        Step-Relic $s.relic $w $h
        $s.relic++
        if ($s.relic -ge $RelicLen) { $s.relic = -1; $s.jx = 0; Step-Relic -1 $w $h }
    }

    # The sky row.
    $sw = $UI.Sky.ActualWidth; $sh = $UI.Sky.ActualHeight
    $on = $UI.Sky.Visibility -eq 'Visible' -and $sw -gt 0
    foreach ($b in $script:CyberBeams) { $b.r.Visibility = $(if ($on) { 'Visible' } else { 'Collapsed' }) }
    if (-not $on) { return }
    $top = [math]::Round($sh - $CityRows * $CyberPx)
    foreach ($l in @($CityFar, $CityNear)) {
        Set-At $l.c $s.jx $top
        foreach ($g in $l.wins) {
            # Mostly on, a group dimming slowly now and then.
            $g.c.Opacity = [math]::Max(0.15, [math]::Min(1, 0.75 + 0.5 * [math]::Sin($t / 70.0 + $g.ph)))
            Set-At $g.c $s.jx $top
        }
    }
    $tx = $s.jx + ($TowerX + 4) * $CyberPx; $ty = $top
    $on = ($t % 14) -lt 4
    $Beacon.Visibility = $(if ($on) { 'Visible' } else { 'Hidden' })
    $BeaconGlow.Visibility = $Beacon.Visibility
    Set-At $Beacon $tx $ty
    Set-At $BeaconGlow ($tx + $CyberPx / 2 - 6) ($ty + $CyberPx / 2 - 6)
    $at = $UI.Sky.TranslatePoint((New-Object System.Windows.Point ($tx + $CyberPx / 2), $ty), $CyberFx)
    foreach ($b in $script:CyberBeams) {
        $b.r.RenderTransform.Angle = 38 * [math]::Sin($t / 55.0 + $b.ph)
        Set-At $b.r ($at.X - 8) ($at.Y - $BeamLen)
    }
    foreach ($c in $script:Cars) {
        if ($null -eq $c.x) {
            $c.x = $(if ($c.dir -lt 0) { $sw + $sw * $script:Rnd.NextDouble() } else { -$c.w - $sw * $script:Rnd.NextDouble() })
            $c.fy = 0.15 + 0.35 * $script:Rnd.NextDouble(); $c.ph = $script:Rnd.NextDouble() * 6.28
        }
        $c.x += $c.dir * $c.v
        if (($c.dir -lt 0 -and $c.x -lt -$c.w) -or ($c.dir -gt 0 -and $c.x -gt $sw)) { $c.x = $null; continue }
        Set-At $c.c ([math]::Round($c.x)) ([math]::Round($c.fy * $sh + 1.2 * [math]::Sin($t / 13.0 + $c.ph)))
    }
    foreach ($n in $script:Signs) {
        # Now and then a sign stutters: a few ticks blinking off and on.
        if ($n.s.off -eq 0 -and $script:Rnd.Next(160) -eq 0) { $n.s.off = 8 }
        $vis = $true
        if ($n.s.off -gt 0) { $vis = @($false, $true, $false, $false, $true, $false, $true, $true)[8 - $n.s.off]; $n.s.off-- }
        $n.s.c.Opacity = $(if ($vis) { 0.85 + 0.15 * [math]::Sin($t / 3.0) } else { 0.12 })
        Set-At $n.s.c ($s.jx + ($n.b.x + $n.dx) * $CyberPx) ($top + ($CityRows - $n.b.h + $n.dy) * $CyberPx)
    }
}

$Scenes.cyberpunk = @{ back = $CyberFx; sky = $CyberSky; step = ${function:Step-Cyberpunk} }
Sync-Scene
