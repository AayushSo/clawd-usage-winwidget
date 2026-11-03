#requires -Version 5.1
# Real WPF scene regression using an isolated configuration and no CLI/network.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
$script:Root = Split-Path -Parent $PSScriptRoot
$script:ConfigPath = Join-Path $env:TEMP ('clawd-xmas-' + [guid]::NewGuid().ToString('N') + '.json')
$script:Rnd = New-Object System.Random 7
foreach ($module in @('config','i18n','format','theme','window','weather','sky','scene','christmas')) {
    . (Join-Path $script:Root "lib\$module.ps1")
}
try {
    foreach ($lang in @('en','ru','fr','pt-BR','es')) {
        $script:Cfg.language = $lang
        if ((T 'theme.christmas') -eq 'theme.christmas') { throw "Missing Christmas translation: $lang" }
    }
    foreach ($case in @(@('2026-08-31','classic'), @('2026-09-01','halloween'),
        @('2026-10-31','halloween'), @('2026-11-01','christmas'),
        @('2026-12-25','christmas'), @('2027-01-14','christmas'), @('2027-01-15','classic'))) {
        if ((Get-SeasonThemeId ([datetime]$case[0])) -ne $case[1]) { throw "Wrong seasonal theme: $($case[0])" }
    }
    $script:Cfg.theme = 'christmas'; Set-Theme
    $UI.Sky.Visibility = 'Visible'
    $win.Show(); $win.UpdateLayout()
    if ($script:Scene.id -ne 'christmas' -or $UI.SkyFx.Visibility -ne 'Collapsed') { throw 'Christmas did not replace the weather' }
    $backCount = $XmasFx.Children.Count; $skyCount = $XmasSky.Children.Count
    $weatherFlakes = $script:Flakes
    foreach ($scale in @(0.6, 1.35, 4)) {
        Set-Scale $scale; $win.UpdateLayout()
        $script:Xmas.sleigh = $null; $script:Xmas.wait = 1
        Step-Christmas 0
        if ($XmasSleigh.Visibility -ne 'Visible') { throw 'Santa did not launch' }
        $oldY = $script:XmasFlakes[0].y
        Step-Christmas 1
        if ($script:XmasFlakes[0].y -le $oldY) { throw 'Snow did not advance' }
        Step-Christmas 8
        if ($script:Bulbs[1].dot.Opacity -ne 1 -or $script:Bulbs[0].dot.Opacity -ne 0.55) { throw 'Garland did not change colour' }
        foreach ($tick in 2..640) { Step-Christmas $tick }
        if ($null -ne $script:Xmas.sleigh -or $XmasSleigh.Visibility -ne 'Collapsed') { throw 'Santa did not finish crossing' }
        if ($XmasFx.Children.Count -ne $backCount -or $XmasSky.Children.Count -ne $skyCount) { throw 'Animation added objects' }
    }
    if (-not [object]::ReferenceEquals($weatherFlakes, $script:Flakes)) { throw 'Christmas overwrote weather snowflakes' }
    $UI.Sky.Visibility = 'Collapsed'; Step-Christmas 700
    $UI.Sky.Visibility = 'Visible'; Step-Christmas 701
    $script:Cfg.theme = 'classic'; Set-Theme
    if ($XmasFx.Visibility -ne 'Collapsed' -or $XmasSky.Visibility -ne 'Collapsed' -or $UI.SkyFx.Visibility -ne 'Visible') { throw 'Switching themes did not restore weather' }
    $script:Cfg.theme = 'christmas'; Set-Theme; $win.UpdateLayout()
    if ($script:Scene.id -ne 'christmas' -or $XmasSky.Visibility -ne 'Visible') { throw 'Christmas did not resume' }
    'PASS: Christmas translations, seasonal boundaries, snow, garland, Santa cycle at three scales, bounded objects and theme switching'
} finally {
    $win.Close()
}
