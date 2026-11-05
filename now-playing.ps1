# The Most szól widget's bridge to Windows' media sessions (SMTC, a WinRT API Java cannot reach). The rune mod starts
# it with Windows PowerShell 5.1 while the widget is enabled and reads its standard output: one JSON object per line,
# written only when something changed.
#   {"type":"track","title":...,"artist":...,"playing":true,"positionMs":...,"endMs":...,"updatedMs":...}
#   {"type":"cover","png":"<base64 PNG: the thumbnail's centre square, at most 256x256>"}  (new track; "" without one)
#   {"type":"none"}                                                                  (nothing playing)
# It reads nothing but the current media session, writes nothing to disk, and exits when the game process is gone.
param([Parameter(Mandatory = $true)][int]$ParentPid)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($operation, [Type]$type) {
    $task = $asTaskGeneric.MakeGenericMethod($type).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
    $task.Result
}

$managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
$propertiesType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
$streamType = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]
$inputStreamType = [Windows.Storage.Streams.IInputStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
# PowerShell 5.1 sees the opened thumbnail as a bare COM object and cannot pick this overload itself.
$asStreamForRead = [System.IO.WindowsRuntimeStreamExtensions].GetMethod('AsStreamForRead', [Type[]]@($inputStreamType))
# Browsers hand Windows small thumbnails (YouTube 150x84, Spotify 120x120): never scale one up, only down.
$maxCoverSize = 256

function Send([hashtable]$message) {
    [Console]::Out.WriteLine(($message | ConvertTo-Json -Compress))
    [Console]::Out.Flush()
}

# The thumbnail's centre square, at most $maxCoverSize, as base64 PNG; "" when there is none or it cannot be read.
function Cover($reference) {
    if ($null -eq $reference) { return '' }
    try {
        $winrtStream = Await ($reference.OpenReadAsync()) $streamType
        $stream = $asStreamForRead.Invoke($null, @($winrtStream))
        $image = [System.Drawing.Image]::FromStream($stream)
        try {
            $side = [Math]::Min($image.Width, $image.Height)
            $source = New-Object System.Drawing.Rectangle ([int](($image.Width - $side) / 2)), ([int](($image.Height - $side) / 2)), $side, $side
            $coverSize = [Math]::Min($side, $maxCoverSize)
            $bitmap = New-Object System.Drawing.Bitmap $coverSize, $coverSize
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($image, (New-Object System.Drawing.Rectangle 0, 0, $coverSize, $coverSize), $source, [System.Drawing.GraphicsUnit]::Pixel)
            $graphics.Dispose()
            $png = New-Object System.IO.MemoryStream
            $bitmap.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
            $bitmap.Dispose()
            return [Convert]::ToBase64String($png.ToArray())
        } finally {
            $image.Dispose()
            $stream.Dispose()
        }
    } catch {
        return ''
    }
}

$manager = Await ($managerType::RequestAsync()) $managerType
$lastTrack = $null
$lastLine = $null
while ($null -ne (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) {
    $message = @{ type = 'none' }
    $track = $null
    try {
        $session = $manager.GetCurrentSession()
        if ($null -ne $session) {
            $properties = Await ($session.TryGetMediaPropertiesAsync()) $propertiesType
            $timeline = $session.GetTimelineProperties()
            if ($properties.Title) {
                $track = "$($session.SourceAppUserModelId)`n$($properties.Title)`n$($properties.Artist)"
                if ($track -ne $lastTrack) {
                    Send @{ type = 'cover'; png = (Cover $properties.Thumbnail) }
                }
                $message = @{
                    type       = 'track'
                    title      = [string]$properties.Title
                    artist     = [string]$properties.Artist
                    playing    = $session.GetPlaybackInfo().PlaybackStatus.ToString() -eq 'Playing'
                    positionMs = [long]$timeline.Position.TotalMilliseconds
                    endMs      = [long]$timeline.EndTime.TotalMilliseconds
                    updatedMs  = [long]$timeline.LastUpdatedTime.ToUnixTimeMilliseconds()
                }
            }
        }
    } catch {
        $message = @{ type = 'none' }
        $track = $null
    }
    $lastTrack = $track
    $line = $message | ConvertTo-Json -Compress
    if ($line -ne $lastLine) {
        [Console]::Out.WriteLine($line)
        [Console]::Out.Flush()
        $lastLine = $line
    }
    Start-Sleep -Milliseconds 1000
}
