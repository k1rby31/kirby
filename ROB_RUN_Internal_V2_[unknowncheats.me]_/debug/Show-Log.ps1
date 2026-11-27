param(
    [string]$LogDirectory = (Join-Path $env:LOCALAPPDATA 'RobRunInternal'),
    [switch]$Plain,
    [string]$Channel,
    [string]$Message,
    [switch]$ReadInput
)

$accent = '5B7DB5'
$accentFile = Join-Path $LogDirectory 'accent.txt'
if (Test-Path -LiteralPath $accentFile -PathType Leaf) {
    $saved = Get-Content -LiteralPath $accentFile -TotalCount 1 -ErrorAction SilentlyContinue
    if ($saved -match '\A[0-9a-fA-F]{6}\z') { $accent = $saved }
}
$rgb = 0, 2, 4 | ForEach-Object { [Convert]::ToInt32($accent.Substring($_, 2), 16) }
$escape = [char]27
$useColor = !$Plain -and !$([Console]::IsOutputRedirected) -and $Host.UI.SupportsVirtualTerminal

function Write-LogLine([string]$Line) {
    if (!$useColor -or $Line.Length -lt 2) {
        Write-Output $Line
        return
    }
    $output = [Text.StringBuilder]::new()
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $amount = $i / ($Line.Length - 1)
        $r = [int](255 + ($rgb[0] - 255) * $amount)
        $g = [int](255 + ($rgb[1] - 255) * $amount)
        $b = [int](255 + ($rgb[2] - 255) * $amount)
        [void]$output.Append("${escape}[38;2;$r;$g;${b}m$($Line[$i])")
    }
    [void]$output.Append("${escape}[0m")
    Write-Output $output.ToString()
}

if ($Channel) {
    if ($ReadInput) {
        while ($null -ne ($line = [Console]::ReadLine())) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $stamp = [DateTime]::Now.ToString('MM/dd/yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
            Write-LogLine "< Amphetamine > [$stamp] $Channel > $line"
        }
    } elseif ($Message) {
        $stamp = [DateTime]::Now.ToString('MM/dd/yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
        Write-LogLine "< Amphetamine > [$stamp] $Channel > $Message"
    }
    return
}

$shown = $false
foreach ($source in @(@{ File = 'entry.log'; Channel = 'entry' },
                      @{ File = 'rr_internal.log'; Channel = 'overlay' })) {
    $file = Get-Item -LiteralPath (Join-Path $LogDirectory $source.File) -ErrorAction SilentlyContinue
    if (!$file) { continue }
    foreach ($line in (Get-Content -LiteralPath $file.FullName -Tail 6 -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith('< Amphetamine > [')) {
            Write-LogLine $line
        } else {
            $stamp = $file.LastWriteTime.ToString('MM/dd/yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
            Write-LogLine "< Amphetamine > [$stamp] $($source.Channel) > $line"
        }
        $shown = $true
    }
}
if (!$shown) {
    $stamp = [DateTime]::Now.ToString('MM/dd/yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
    Write-LogLine "< Amphetamine > [$stamp] overlay > No log entries yet."
}
