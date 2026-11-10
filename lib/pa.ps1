# -------------------------------------------------------------------- pa ----
# Fork addition: two panel tabs that are a small front end to the /pa skill.
#   Today - today's schedule with the current block marked, and a box that queues a
#           new task in /pa's inbox, the same as the PA widget's "+ Add" (/pa writes
#           it into tasks.md at its next run).
#   Links - the PA widget's quick links; a click opens one the way that widget does.
# Everything goes through /pa's own tools - tools\pa_bridge.py reads with its
# modules, widgetctl.py queues the task - so this widget never writes /pa's files.
# Python runs in the background (one job per kind) and a short timer picks up the result.

foreach ($kv in ([ordered]@{
    'tab.today'      = 'Today'
    'tab.links'      = 'Links'
    'pa.loading'     = 'Loading...'
    'pa.noSchedule'  = 'No schedule is set up in /pa.'
    'pa.empty'       = 'Nothing scheduled today.'
    'pa.failed'      = '/pa did not answer: {0}'
    'pa.now'         = 'now {0}'
    'pa.addHint'     = 'Add a task for {0}...'
    'pa.sending'     = 'Sending...'
    'pa.queued'      = 'Queued. {0} files it at the next /pa run.'
    'pa.open'        = 'Open PA widget'
    'pa.opening'     = 'Opening...'
    'pa.noLinks'     = 'No quick links in /pa.'
    'pa.noPython'    = 'Python was not found on PATH.'
    'pa.fixed'       = 'fixed'
    'pa.flexible'    = 'flexible'
}).GetEnumerator()) { $Strings.en[$kv.Key] = $kv.Value }

foreach ($n in @('TabToday', 'TabLinks', 'PageToday', 'PageLinks', 'PaHead', 'PaScroll', 'PaBlocks', 'PaAdd', 'PaAddHint',
                 'PaAddMsg', 'PaOpen', 'PaLinkList', 'PaLinkMsg')) {
    $UI[$n] = $advWin.FindName($n)
}

$script:PaJobs     = @{}                    # kind -> @{ proc; out; err; at; arg }
$script:PaToday    = $null                  # what pa_bridge.py today said
$script:PaTodayErr = $null
$script:PaTodayAt  = [datetime]::MinValue   # last good answer
$script:PaTodayTry = [datetime]::MinValue
$script:PaLinks    = $null
$script:PaLinksAt  = [datetime]::MinValue
$script:PaLinksTry = [datetime]::MinValue
$script:PaLinksErr = $null
$script:PaKey      = $null
$script:PaLinkKey  = $null
$script:PaPython   = $null
$PaBridge          = Join-Path $script:Root 'tools\pa_bridge.py'

function Get-PaToolsDir {
    $d = [string]$script:Cfg.paSkillDir
    if (-not $d.Trim()) { $d = Join-Path $env:USERPROFILE '.claude\skills\pa' }
    return Join-Path ([Environment]::ExpandEnvironmentVariables($d).TrimEnd('\', '/')) 'tools'
}

# A real python.exe; the Microsoft Store stub in WindowsApps only opens the Store.
function Get-PaPython {
    if (-not $script:PaPython) {
        $c = Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*\WindowsApps\*' } | Select-Object -First 1
        if (-not $c) { $c = Get-Command py.exe -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($c) { $script:PaPython = $c.Source }
    }
    return $script:PaPython
}

# One argument for a Windows command line, quoted so the program gets it back exactly
# (Windows PowerShell 5.1 does not escape quotes inside arguments by itself).
function ConvertTo-PaArg([string]$s) {
    $s = [regex]::Replace($s, '(\\*)"', { param($m) ($m.Groups[1].Value * 2) + '\"' })
    $s = [regex]::Replace($s, '(\\+)$', { param($m) $m.Groups[1].Value * 2 })
    return '"' + $s + '"'
}

function Get-PaAssistant {
    if ($script:PaToday -and $script:PaToday.assistant) { return [string]$script:PaToday.assistant }
    return '/pa'
}

$paTimer = New-Object System.Windows.Threading.DispatcherTimer
$paTimer.Interval = [TimeSpan]::FromMilliseconds(300)

# Starts python with these arguments as job $kind, unless one of that kind still runs.
function Start-PaJob([string]$kind, [string]$argLine, $tag = $null) {
    $j = $script:PaJobs[$kind]
    if ($j -and -not $j.proc.HasExited) { return $false }
    $py = Get-PaPython
    if (-not $py) { Complete-PaJob $kind 1 (T 'pa.noPython') $tag; return $false }
    $out = Join-Path $env:TEMP "cuw-pa-$kind-$PID.txt"
    $err = "$out.err"
    try {
        $p = Start-Process -FilePath $py -ArgumentList $argLine -WorkingDirectory $env:TEMP `
                 -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden -PassThru
        [void]$p.Handle
    } catch {
        Complete-PaJob $kind 1 $_.Exception.Message $tag
        return $false
    }
    $script:PaJobs[$kind] = @{ proc = $p; out = $out; err = $err; at = Get-Date; tag = $tag }
    $paTimer.Start()
    return $true
}

function Read-PaFile([string]$path) {
    try { return ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)).Trim() } catch { return '' }
}

$paTimer.add_Tick({
    $busy = $false
    foreach ($kind in @($script:PaJobs.Keys)) {
        $j = $script:PaJobs[$kind]
        if (-not $j.proc.HasExited) {
            if (((Get-Date) - $j.at).TotalSeconds -lt 45) { $busy = $true; continue }
            try { & taskkill.exe /PID $j.proc.Id /T /F 2>&1 | Out-Null } catch {}
            $script:PaJobs.Remove($kind)
            Complete-PaJob $kind 1 'timed out' $j.tag
            continue
        }
        $script:PaJobs.Remove($kind)
        $text = Read-PaFile $j.out
        $errText = Read-PaFile $j.err
        foreach ($f in @($j.out, $j.err)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
        $code = 1
        try { $code = $j.proc.ExitCode } catch {}
        # On failure the first line says why: our own message on stdout, else Python's last error line.
        if ($code -ne 0 -and -not $text -and $errText) { $text = @($errText -split '\r?\n')[-1] }
        try { Complete-PaJob $kind $code $text $j.tag } catch {
            try {
                "$(Get-Date -Format s)`tpa $kind`: $($_.Exception.Message)" |
                    Out-File (Join-Path $script:Root 'widget-error.log') -Append -Encoding utf8
            } catch {}
        }
    }
    if (-not $busy) { $paTimer.Stop() }
})

function Complete-PaJob([string]$kind, [int]$code, [string]$text, $tag) {
    $first = @($text -split '\r?\n')[0]
    switch ($kind) {
        'today' {
            if ($code -eq 0) {
                try { $script:PaToday = $text | ConvertFrom-Json; $script:PaTodayAt = Get-Date; $script:PaTodayErr = $null }
                catch { $script:PaTodayErr = $_.Exception.Message }
            } else { $script:PaTodayErr = $first }
            $script:PaKey = $null
        }
        'links' {
            if ($code -eq 0) {
                # PowerShell 5.1 hands a JSON array on as one object: unroll it into its links.
                try { $arr = $text | ConvertFrom-Json; $script:PaLinks = @($arr | ForEach-Object { $_ }); $script:PaLinksAt = Get-Date; $script:PaLinksErr = $null }
                catch { $script:PaLinksErr = $_.Exception.Message }
            } else { $script:PaLinksErr = $first }
            $script:PaLinkKey = $null
        }
        'capture' {
            if ($code -eq 0) {
                # Cleared only if it still holds what was sent - typing on meanwhile is kept.
                if ($UI.PaAdd.Text.Trim() -eq $tag) { $UI.PaAdd.Text = '' }
                Set-PaMsg $UI.PaAddMsg ((T 'pa.queued') -f (Get-PaAssistant)) '#FF4ADE80'
            } else {
                Set-PaMsg $UI.PaAddMsg $(if ($first) { $first } else { "exit $code" }) '#FFF87171'
            }
        }
        'open' {
            if ($code -eq 0) { $UI.PaLinkMsg.Visibility = 'Collapsed' }
            else { Set-PaMsg $UI.PaLinkMsg ((T 'pa.failed') -f $first) '#FFF87171' }
        }
        'widget' {
            if ($code -eq 0) { $UI.PaOpen.Text = T 'pa.open' }
            else { $UI.PaOpen.Text = T 'pa.open'; Set-PaMsg $UI.PaAddMsg ((T 'pa.failed') -f $first) '#FFF87171' }
        }
    }
    if ($advWin.IsVisible -and $script:PanelTab -in @('today', 'links')) { Update-Panel }
}

function Set-PaMsg($tb, [string]$text, [string]$color) {
    $tb.Text = $text
    $tb.Foreground = New-Brush $color
    $tb.Visibility = $(if ($text) { 'Visible' } else { 'Collapsed' })
}

function Get-PaMinutes([string]$hhmm) {
    $p = $hhmm.Split(':')
    try { return [int]$p[0] * 60 + [int]$p[1] } catch { return 0 }
}

# ----------------------------------------------------------------- Today ----

# Today's schedule is asked for when the tab is open: every 5 minutes, and at once on a new day.
function Request-PaToday([switch]$Soon) {
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $stale = -not $script:PaToday -or $script:PaToday.date -ne $today -or ((Get-Date) - $script:PaTodayAt).TotalMinutes -ge 5
    $wait  = $(if ($Soon) { 20 } else { 60 })
    if ($stale -and ((Get-Date) - $script:PaTodayTry).TotalSeconds -ge $wait) {
        $script:PaTodayTry = Get-Date
        [void](Start-PaJob 'today' ("-I $(ConvertTo-PaArg $PaBridge) $(ConvertTo-PaArg (Get-PaToolsDir)) today"))
    }
}

function New-PaBlockRow($b, [bool]$past, [bool]$cur) {
    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 5
    $row.Padding = New-Object System.Windows.Thickness 0, 2, 4, 2
    $row.Margin = New-Object System.Windows.Thickness 0, 0, 0, 1
    if ($cur) { $row.Background = New-Brush '#2660A5FA' }
    if ($past) { $row.Opacity = 0.45 }
    $g = New-Object System.Windows.Controls.Grid
    foreach ($w in @(9, 74, -1)) {
        $c = New-Object System.Windows.Controls.ColumnDefinition
        if ($w -gt 0) { $c.Width = New-Object System.Windows.GridLength $w }
        $g.ColumnDefinitions.Add($c)
    }
    # The category's colour, as on the PA widget's timeline.
    $bar = New-Object System.Windows.Controls.Border
    $bar.Width = 3
    $bar.CornerRadius = New-Object System.Windows.CornerRadius 1.5
    $bar.HorizontalAlignment = 'Left'
    $bar.Margin = New-Object System.Windows.Thickness 3, 1, 0, 1
    try { $bar.Background = New-Brush ([string]$b.color) } catch { $bar.Background = New-Brush '#FF6B7280' }
    [void]$g.Children.Add($bar)
    $time = New-PanelText "$($b.start)$([char]0x2013)$($b.end)" 10 $(if ($cur) { '#FFE4E4E7' } else { '#FF8B8B94' })
    $time.TextWrapping = 'NoWrap'
    [System.Windows.Controls.Grid]::SetColumn($time, 1)
    [void]$g.Children.Add($time)
    $title = New-PanelText ([string]$b.title) 10.5 $(if ($cur) { '#FFF4F4F5' } else { '#FFE4E4E7' })
    if ($cur) { $title.FontWeight = 'SemiBold' }
    if (-not $b.fixed) { $title.FontStyle = 'Italic' }
    [System.Windows.Controls.Grid]::SetColumn($title, 2)
    [void]$g.Children.Add($title)
    $tip = "$($b.start)$([char]0x2013)$($b.end)  $($b.title)`n$($b.label) $([char]0x00B7) $(if ($b.fixed) { T 'pa.fixed' } else { T 'pa.flexible' })"
    if ($b.location) { $tip += " $([char]0x00B7) $($b.location)" }
    $row.ToolTip = $tip
    $row.Child = $g
    return $row
}

# A red line where now is, between the blocks (the same red as the week's pace head).
function New-PaNowLine {
    $g = New-Object System.Windows.Controls.Grid
    $g.Margin = New-Object System.Windows.Thickness 0, 2, 0, 3
    $c = New-Object System.Windows.Controls.ColumnDefinition; $c.Width = 'Auto'; $g.ColumnDefinitions.Add($c)
    $g.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $t = New-PanelText ((T 'pa.now') -f (Get-Date).ToString('HH:mm')) 9 '#FFFF2D2D'
    $t.Margin = New-Object System.Windows.Thickness 3, 0, 6, 0
    [void]$g.Children.Add($t)
    $line = New-Object System.Windows.Controls.Border
    $line.Height = 1
    $line.Background = New-Brush '#FFFF2D2D'
    $line.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($line, 1)
    [void]$g.Children.Add($line)
    return $g
}

function Update-TodayPage([switch]$Force) {
    Request-PaToday -Soon:$Force
    $UI.PaAddHint.Text = (T 'pa.addHint') -f (Get-PaAssistant)
    if (-not $script:PaJobs['widget']) { $UI.PaOpen.Text = T 'pa.open' }
    $d = $script:PaToday
    $now = Get-Date
    $key = (Get-Lang) + '|' + $now.ToString('yyyy-MM-dd HH:mm') + '|' + $(if ($d) { $d | ConvertTo-Json -Depth 4 -Compress }) + '|' + $script:PaTodayErr
    if (-not $Force -and $key -eq $script:PaKey) { return }
    $script:PaKey = $key

    $UI.PaBlocks.Children.Clear()
    $note = { param($text) $t = New-PanelText $text 10 '#FF8B8B94'; $t.Margin = New-Object System.Windows.Thickness 2, 0, 0, 4; [void]$UI.PaBlocks.Children.Add($t) }
    if (-not $d) {
        $UI.PaHead.Text = $now.ToString('ddd d MMM', [System.Globalization.CultureInfo]::InvariantCulture).ToUpper()
        & $note $(if ($script:PaTodayErr) { (T 'pa.failed') -f $script:PaTodayErr } else { T 'pa.loading' })
        return
    }
    $head = $now.ToString('ddd d MMM', [System.Globalization.CultureInfo]::InvariantCulture).ToUpper()
    if ($d.week_kind) { $head += "  $([char]0x00B7)  $(([string]$d.week_kind).ToUpper()) WEEK" }
    foreach ($p in @($d.phases)) { if ($p) { $head += "`n$p" } }
    $UI.PaHead.Text = $head
    if ($script:PaTodayErr) { & $note ((T 'pa.failed') -f $script:PaTodayErr) }
    if ($d.none) { & $note (T 'pa.noSchedule'); return }
    foreach ($e in @($d.all_day)) { if ($e) { & $note "$([char]0x25C6) $e" } }
    $blocks = @($d.blocks | Where-Object { $_ })
    if (-not $blocks.Count) { & $note (T 'pa.empty'); return }

    $m = $now.TimeOfDay.TotalMinutes
    $placed = $false
    $curRow = $null
    foreach ($b in $blocks) {
        $s = Get-PaMinutes $b.start; $e = Get-PaMinutes $b.end
        $cur = ($s -le $m -and $m -lt $e)
        if (-not $placed -and -not $cur -and $s -gt $m) { [void]$UI.PaBlocks.Children.Add((New-PaNowLine)); $placed = $true }
        $row = New-PaBlockRow $b ($e -le $m) $cur
        if ($cur) { $placed = $true; $curRow = $row }
        [void]$UI.PaBlocks.Children.Add($row)
    }
    if (-not $placed) { [void]$UI.PaBlocks.Children.Add((New-PaNowLine)) }
    # The block on now in view, without moving the panel itself.
    if ($curRow -and $advWin.IsVisible) {
        $UI.PaScroll.UpdateLayout()
        try {
            $y = $curRow.TransformToAncestor($UI.PaBlocks).Transform((New-Object System.Windows.Point 0, 0)).Y
            $UI.PaScroll.ScrollToVerticalOffset([math]::Max(0, $y - 40))
        } catch {}
    }
}

function Submit-PaCapture {
    $t = $UI.PaAdd.Text.Trim()
    if (-not $t) { return }
    $ctl = Join-Path (Get-PaToolsDir) 'widgetctl.py'
    if (Start-PaJob 'capture' ("-I $(ConvertTo-PaArg $ctl) capture $(ConvertTo-PaArg $t)") $t) {
        Set-PaMsg $UI.PaAddMsg (T 'pa.sending') '#FF8B8B94'
    }
}

$UI.PaAdd.add_TextChanged({ $UI.PaAddHint.Visibility = $(if ($UI.PaAdd.Text) { 'Collapsed' } else { 'Visible' }) })
$UI.PaAdd.add_PreviewKeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Return) { $e.Handled = $true; Submit-PaCapture }
    elseif ($e.Key -eq [System.Windows.Input.Key]::Escape) { $e.Handled = $true; $UI.PaAdd.Text = ''; $UI.PaAddMsg.Visibility = 'Collapsed' }
})
$UI.PaOpen.add_MouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $true
    if (Start-PaJob 'widget' ("-I $(ConvertTo-PaArg (Join-Path (Get-PaToolsDir) 'open_widget.py'))")) { $UI.PaOpen.Text = T 'pa.opening' }
})

# ----------------------------------------------------------------- Links ----

function Request-PaLinks([switch]$Soon) {
    $stale = $null -eq $script:PaLinks -or ((Get-Date) - $script:PaLinksAt).TotalMinutes -ge 5
    $wait  = $(if ($Soon) { 20 } else { 60 })
    if ($stale -and ((Get-Date) - $script:PaLinksTry).TotalSeconds -ge $wait) {
        $script:PaLinksTry = Get-Date
        [void](Start-PaJob 'links' ("-I $(ConvertTo-PaArg $PaBridge) $(ConvertTo-PaArg (Get-PaToolsDir)) links"))
    }
}

function Update-LinksPage([switch]$Force) {
    Request-PaLinks -Soon:$Force
    $key = (Get-Lang) + '|' + $(if ($null -ne $script:PaLinks) { $script:PaLinks | ConvertTo-Json -Depth 3 -Compress }) + '|' + $script:PaLinksErr
    if (-not $Force -and $key -eq $script:PaLinkKey) { return }
    $script:PaLinkKey = $key
    $UI.PaLinkList.Children.Clear()
    $note = { param($text) $t = New-PanelText $text 10 '#FF8B8B94'; $t.Margin = New-Object System.Windows.Thickness 2, 0, 0, 4; [void]$UI.PaLinkList.Children.Add($t) }
    if ($script:PaLinksErr) { & $note ((T 'pa.failed') -f $script:PaLinksErr) }
    if ($null -eq $script:PaLinks) { if (-not $script:PaLinksErr) { & $note (T 'pa.loading') }; return }
    if (-not $script:PaLinks.Count) { & $note (T 'pa.noLinks'); return }
    foreach ($l in $script:PaLinks) {
        $row = New-Object System.Windows.Controls.Border
        $row.CornerRadius = New-Object System.Windows.CornerRadius 6
        $row.Padding = New-Object System.Windows.Thickness 8, 5, 8, 6
        $row.Margin = New-Object System.Windows.Thickness 0, 0, 0, 4
        $row.Background = New-Brush '#FF26262C'
        $row.Cursor = [System.Windows.Input.Cursors]::Hand
        $row.Tag = [string]$l.id
        $g = New-Object System.Windows.Controls.Grid
        $g.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
        $c = New-Object System.Windows.Controls.ColumnDefinition; $c.Width = 'Auto'; $g.ColumnDefinitions.Add($c)
        # Arrows as in the PA widget: an area page opens in place (->), the rest open outside it.
        $arrow = $(if ($l.kind -eq 'page') { [char]0x2192 } else { [char]0x2197 })
        [void]$g.Children.Add((New-PanelText "$($l.label) $arrow" 10.5 '#FF60A5FA'))
        $area = $(if ($l.area -and $l.area -ne '_') { [string]$l.area } else { '' })
        $a = New-PanelText $area 9 '#FF6B7280'
        $a.VerticalAlignment = 'Center'
        [System.Windows.Controls.Grid]::SetColumn($a, 1)
        [void]$g.Children.Add($a)
        $row.Child = $g
        $row.ToolTip = $(switch ([string]$l.kind) { 'url' { 'Open in the browser' } 'doc' { 'Open the local document' } default { 'Open the area page (starts the PA widget server if needed)' } })
        $row.add_MouseLeftButtonDown({
            param($s, $e)
            $e.Handled = $true
            if (Start-PaJob 'open' ("-I $(ConvertTo-PaArg $PaBridge) $(ConvertTo-PaArg (Get-PaToolsDir)) open $(ConvertTo-PaArg $s.Tag)")) {
                Set-PaMsg $UI.PaLinkMsg (T 'pa.opening') '#FF8B8B94'
            }
        })
        [void]$UI.PaLinkList.Children.Add($row)
    }
}

# ------------------------------------------------------------------ tabs ----

$UI.TabToday.add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; Set-PanelTab 'today' })
$UI.TabLinks.add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; Set-PanelTab 'links' })

# The panel opens on Today when it is on (the chat and its tips are one click away).
if (Test-PanelTab 'today') {
    $script:PanelTab = 'today'
    $UI.PageChat.Visibility  = 'Collapsed'
    $UI.PageToday.Visibility = 'Visible'
    # Not $b: the modules share one scope, and theme code has $b typed as a brush there.
    foreach ($paEl in @($UI.AdvStamp, $UI.AdvRescan, $UI.ChatAuto, $UI.ChatNew)) { $paEl.Visibility = 'Collapsed' }
}
