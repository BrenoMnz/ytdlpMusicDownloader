$email = Get-Content "email.txt"
$URL = Read-Host "Insert the youtube video or playlist URL"

Set-Location -Path $DownloadPath
yt-dlp -f bestaudio --extract-audio --audio-format mp3 -o "%(title)s.%(ext)s" "$URL"

$UserAgent = "MyMusicDownloader/1.0 ($email)"

Get-ChildItem -Filter "*.mp3" | ForEach-Object {
    $File = $_.Name
    Write-Host "Processando: $File"
    
    $Title = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $Artist = "Unknown"
    $Song = "Unknown"
    $Album = "Unknown"
    $Year = "Unknown"
    
    If ($Title -match "^(.*) - (.*?)\s*(?:\([^)]*\))?\s*(?:\[[^]]*\])?$") {
        $Artist = $matches[1].Trim()
        $Song = $matches[2].Trim()
    }
    
    $SearchURL = "https://musicbrainz.org/ws/2/recording/?query=recording:$([uri]::EscapeDataString($Song)) AND artist:$([uri]::EscapeDataString($Artist))&fmt=json"
    $Headers = @{ "User-Agent" = $UserAgent }
    $JSON = Invoke-RestMethod -Uri $SearchURL -Method Get -Headers $Headers
    
    If ($JSON.recordings.Count -gt 0) {
        $MBData = $JSON.recordings[0]
        If ($MBData.title) { $Song = $MBData.title }
        If ($MBData."artist-credit".Count -gt 0) { $Artist = $MBData."artist-credit"[0].name }
        If ($MBData.releases.Count -gt 0) {
            $Album = $MBData.releases[0].title
            $Year = $MBData.releases[0].date.Substring(0,4)
        }
    }
    
    $NewName = "$Artist - $Song.mp3"
    Rename-Item -Path $File -NewName $NewName
    
    ffmpeg -i "$NewName" -metadata title="$Song" -metadata artist="$Artist" -metadata album="$Album" -metadata year="$Year" -codec copy "temp_$NewName"
    Move-Item -Path "temp_$NewName" -Destination "$NewName" -Force
    
    Write-Host "Metadados aplicados: $NewName"
}

Write-Host "Processo concluído!"