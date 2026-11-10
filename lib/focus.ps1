# ----------------------------------------------------------------- focus ----
# Fork addition: focus mode. The widget shrinks to a small always-on-top circle with
# the weekly limit - a ring filled to the percent in the limit's colour, the number in
# the middle and the week's red pace tick on the ring (where an even pace would be).
# Drag the circle to move it (its place is remembered apart from the widget's); a click
# without moving opens the full widget again. The ◉ button in the widget's header goes
# back to the circle. The mode survives a restart (focusMode in config.json).

$FocusBase = 46.0          # the circle's size before scale
$FocusR    = 19.0          # the ring's radius inside it

$dotWin = New-Object System.Windows.Window
$dotWin.WindowStyle        = 'None'
$dotWin.AllowsTransparency = $true
$dotWin.Background         = [System.Windows.Media.Brushes]::Transparent
$dotWin.ShowInTaskbar      = $false
$dotWin.ResizeMode         = 'NoResize'
$dotWin.Topmost            = $true
$dotWin.Title              = 'Clawd focus'
$dotWin.WindowStartupLocation = 'Manual'

$dotGrid = New-Object System.Windows.Controls.Grid
$dotGrid.Width = $FocusBase; $dotGrid.Height = $FocusBase
$dotGrid.Cursor = [System.Windows.Input.Cursors]::Hand

$dotBg = New-Object System.Windows.Shapes.Ellipse
$dotBg.Fill            = New-Brush '#F21A1A1E'
$dotBg.Stroke          = New-Brush '#40FFFFFF'
$dotBg.StrokeThickness = 1
[void]$dotGrid.Children.Add($dotBg)

$dotTrack = New-Object System.Windows.Shapes.Ellipse
$dotTrack.Width = 2 * $FocusR; $dotTrack.Height = 2 * $FocusR
$dotTrack.Stroke = New-Brush '#26FFFFFF'
$dotTrack.StrokeThickness = 4
[void]$dotGrid.Children.Add($dotTrack)

# The used part of the week: an arc from 12 o'clock, clockwise.
$dotArc = New-Object System.Windows.Shapes.Path
$dotArc.StrokeThickness    = 4
$dotArc.StrokeStartLineCap = 'Round'
$dotArc.StrokeEndLineCap   = 'Round'
[void]$dotGrid.Children.Add($dotArc)

$dotTick = New-Object System.Windows.Shapes.Line
$dotTick.Stroke = New-Brush '#FFFF2D2D'
$dotTick.StrokeThickness = 2
$dotTick.StrokeStartLineCap = 'Round'; $dotTick.StrokeEndLineCap = 'Round'
[void]$dotGrid.Children.Add($dotTick)

$dotText = New-Object System.Windows.Controls.TextBlock
$dotText.FontFamily = 'Segoe UI'
$dotText.FontSize   = 13
$dotText.FontWeight = 'SemiBold'
$dotText.HorizontalAlignment = 'Center'
$dotText.VerticalAlignment   = 'Center'
[void]$dotGrid.Children.Add($dotText)

# The circle scales with the widget (Settings -> scale).
$dotBox = New-Object System.Windows.Controls.Viewbox
$dotBox.Child = $dotGrid
$dotWin.Content = $dotBox

function Set-FocusSize {
    $k = [math]::Max(0.6, [math]::Min(4.0, [double]$script:Cfg.scale))
    $dotWin.Width = $FocusBase * $k; $dotWin.Height = $FocusBase * $k
}

# A point on the ring at a share of the full turn (0 - 12 o'clock, clockwise).
function Get-FocusPoint([double]$share, [double]$r) {
    $a = 2 * [math]::PI * $share
    $c = $FocusBase / 2
    return New-Object System.Windows.Point ($c + $r * [math]::Sin($a)), ($c - $r * [math]::Cos($a))
}

function Update-FocusDot {
    if (-not $dotWin.IsVisible) { return }
    Set-FocusSize
    $u = $script:Usage
    $pct = $(if ($u) { $u.week })
    if ($null -eq $pct) {
        $dotText.Text = '--'
        $dotText.Foreground = New-Brush $Palette.dead.Wpf
        $dotArc.Visibility = 'Collapsed'
    } else {
        $col = $Palette[(Get-Level $pct)].Wpf
        $dotText.Text = "$([int]$pct)"
        $dotText.Foreground = New-Brush $col
        $dotArc.Stroke = New-Brush $col
        $share = [math]::Min(1.0, [math]::Max(0.0, [double]$pct / 100.0))
        if ($share -le 0) {
            $dotArc.Visibility = 'Collapsed'
        } else {
            $dotArc.Visibility = 'Visible'
            if ($share -ge 0.999) {
                $c = $FocusBase / 2
                $dotArc.Data = New-Object System.Windows.Media.EllipseGeometry (New-Object System.Windows.Point $c, $c), $FocusR, $FocusR
            } else {
                $fig = New-Object System.Windows.Media.PathFigure
                $fig.StartPoint = Get-FocusPoint 0 $FocusR
                $seg = New-Object System.Windows.Media.ArcSegment
                $seg.Point = Get-FocusPoint $share $FocusR
                $seg.Size = New-Object System.Windows.Size $FocusR, $FocusR
                $seg.SweepDirection = 'Clockwise'
                $seg.IsLargeArc = ($share -gt 0.5)
                [void]$fig.Segments.Add($seg)
                $geo = New-Object System.Windows.Media.PathGeometry
                [void]$geo.Figures.Add($fig)
                $dotArc.Data = $geo
            }
        }
    }
    # The week's pace, as on the widget's week bar: the share of the 7 days gone.
    $frac = $null
    if ($u -and $u.weekReset) {
        $frac = 1.0 - ($u.weekReset - (Get-Date)).TotalDays / 7.0
        if ($frac -lt 0 -or $frac -gt 1) { $frac = $null }
    }
    if ($null -eq $frac) { $dotTick.Visibility = 'Collapsed' }
    else {
        $a = Get-FocusPoint $frac ($FocusR - 4); $b = Get-FocusPoint $frac ($FocusR + 3.5)
        $dotTick.X1 = $a.X; $dotTick.Y1 = $a.Y; $dotTick.X2 = $b.X; $dotTick.Y2 = $b.Y
        $dotTick.Visibility = 'Visible'
    }
    $tip = $(if ($null -ne $pct) { "Week $([int]$pct)%" } else { 'Week: no data yet' })
    if ($u -and $u.weekReset) { $s = Format-Span $u.weekReset; if ($s) { $tip += "  $([char]0x00B7)  resets in $s" } }
    if ($null -ne $frac) { $tip += "`n$([int][math]::Round($frac * 100))% of the week gone (red tick)" }
    if ($u -and $null -ne $u.session) { $tip += "`nSession $($u.session)%" }
    $dotWin.ToolTip = "$tip`nClick to expand $([char]0x00B7) drag to move"
}

# To the circle: where it was last left, or at the widget's top-right corner.
function Enter-Focus {
    $script:Cfg.focusMode = $true
    Set-FocusSize
    if ($null -ne $script:Cfg.focusLeft -and $null -ne $script:Cfg.focusTop) {
        $dotWin.Left = [double]$script:Cfg.focusLeft; $dotWin.Top = [double]$script:Cfg.focusTop
    } else {
        $w = $(if ($win.ActualWidth -gt 0) { $win.ActualWidth } else { 260 * [double]$script:Cfg.scale })
        $dotWin.Left = $win.Left + $w - $dotWin.Width - 10
        $dotWin.Top  = $win.Top + 10
    }
    if ($win.IsVisible) {
        $script:Cfg.left = [math]::Round($win.Left); $script:Cfg.top = [math]::Round($win.Top)
    }
    Save-Config $script:Cfg
    $advWin.Hide()
    $win.Hide()
    $dotWin.Show()
    Update-FocusDot
}

function Exit-Focus {
    $script:Cfg.focusMode = $false
    Save-Config $script:Cfg
    $dotWin.Hide()
    $win.Show()
    $win.Activate()
}

# The tray icon's click and its menu: hide or bring back whichever form is in use.
function Switch-WidgetShown {
    if ($win.IsVisible -or $dotWin.IsVisible) { $win.Hide(); $dotWin.Hide(); $advWin.Hide(); return }
    if ($script:Cfg.focusMode) { $dotWin.Show(); Update-FocusDot }
    else { $win.Show(); $win.Activate() }
}

# Drag moves the circle; a click that did not move it opens the widget.
$dotWin.add_MouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $true
    $x = $dotWin.Left; $y = $dotWin.Top
    try { $dotWin.DragMove() } catch {}
    if ([math]::Abs($dotWin.Left - $x) -lt 3 -and [math]::Abs($dotWin.Top - $y) -lt 3) {
        $dotWin.Left = $x; $dotWin.Top = $y
        Exit-Focus
    } else {
        $script:Cfg.focusLeft = [math]::Round($dotWin.Left)
        $script:Cfg.focusTop  = [math]::Round($dotWin.Top)
        Save-Config $script:Cfg
    }
})

$UI.BtnFocus = $win.FindName('BtnFocus')
$UI.BtnFocus.add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; Enter-Focus })
