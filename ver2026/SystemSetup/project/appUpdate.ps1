# ===================
# 管理者でなければ管理者として再実行
# ===================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Write-Host "ps1ファイルとして保存されていません。ps1ファイルとして保存してから実行してください。"
        Read-Host "Enterキーで終了"
        exit
    }

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`"" `
        -Verb RunAs

    exit
}

# ===================
# 基本設定
# ===================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

Write-Host "==============================="
Write-Host "アプリ更新を開始します"
Write-Host "==============================="
Write-Host "実行内容:"
Write-Host "1. Wi-Fi設定の読み込み"
Write-Host "2. wingetアプリの更新"
Write-Host "3. Blender Portable の更新"
Write-Host "4. Epic Games Launcher の更新"
Write-Host "5. Windows Update の適用"
Write-Host "6. 必要に応じて再起動"
Write-Host "==============================="

# ===================
# 関数：ZIPファイルか確認
# ===================
function Test-ZipFile {
    param (
        [string] $FilePath
    )

    if (!(Test-Path $FilePath)) {
        return $false
    }

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    if ($bytes.Length -lt 2) {
        return $false
    }

    $signature = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 2)

    return ($signature -eq "PK")
}

# ===================
# 関数：Blender Portable のURLを取得
# ===================
function Get-BlenderPortableUrl {
    $DownloadPageUrl = "https://www.blender.org/download/"

    Write-Host "Blender公式ダウンロードページを確認しています..."

    $page = Invoke-WebRequest `
        -Uri $DownloadPageUrl `
        -UseBasicParsing `
        -ErrorAction Stop

    $html = $page.Content

    $html = $html -replace "\\/", "/"
    $html = $html -replace "&amp;", "&"

    $patterns = @(
        "https://www\.blender\.org/download/release/Blender[0-9\.]+/blender-[0-9\.]+-windows-x64\.zip",
        "https://download\.blender\.org/release/Blender[0-9\.]+/blender-[0-9\.]+-windows-x64\.zip"
    )

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($html, $pattern)

        if ($matches.Count -gt 0) {
            $url = $matches[0].Value

            # www.blender.org/download/release はHTMLを返すことがあるため、
            # 実ファイル配布用の download.blender.org/release に変換する
            $url = $url -replace "^https://www\.blender\.org/download/release/", "https://download.blender.org/release/"

            return $url
        }
    }

    throw "Blender Portable のダウンロードURLが見つかりませんでした。"
}

# ===================
# 関数：ファイルダウンロード
# ===================
function Download-File {
    param (
        [string] $Url,
        [string] $OutFile
    )

    Write-Host "ダウンロード元: $Url"
    Write-Host "保存先: $OutFile"

    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        try {
            Start-BitsTransfer `
                -Source $Url `
                -Destination $OutFile `
                -ErrorAction Stop

            return
        }
        catch {
            Write-Host "BITSでのダウンロードに失敗しました。Invoke-WebRequestで再試行します。"
        }
    }

    Invoke-WebRequest `
        -Uri $Url `
        -OutFile $OutFile `
        -UseBasicParsing `
        -ErrorAction Stop
}

# ===================
# 関数：ショートカット作成
# ===================
function New-Shortcut {
    param (
        [string] $ShortcutPath,
        [string] $TargetPath,
        [string] $WorkingDirectory,
        [string] $Description
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)

    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $shortcut.IconLocation = "$TargetPath,0"

    $shortcut.Save()
}

# ===================
# 関数：Blender Portable 更新
# ===================
function Update-BlenderPortable {
    Write-Host "==============================="
    Write-Host "Blender Portable の更新を開始します"
    Write-Host "==============================="

    $BlenderDestRoot = "C:\Blender"
    $TempDir = Join-Path $env:TEMP "BlenderPortableUpdate"
    $BlenderZip = Join-Path $TempDir "blender-portable.zip"
    $PortableBackupDir = Join-Path $TempDir "portable-backup"

    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    $BlenderDownloadUrl = Get-BlenderPortableUrl
    $BlenderZipFileName = Split-Path $BlenderDownloadUrl -Leaf
    $LatestFolderName = [System.IO.Path]::GetFileNameWithoutExtension($BlenderZipFileName)

    $LatestBlenderFolder = Join-Path $BlenderDestRoot $LatestFolderName
    $LatestBlenderExe = Join-Path $LatestBlenderFolder "blender.exe"

    Write-Host "取得したBlender Portable URL:"
    Write-Host $BlenderDownloadUrl
    Write-Host "最新版フォルダ名: $LatestFolderName"

    # すでに最新版フォルダがある場合
    if (Test-Path $LatestBlenderExe) {
        Write-Host "Blender Portable はすでに最新版の可能性があります。更新をスキップします。"

        $PortableDir = Join-Path $LatestBlenderFolder "portable"

        if (!(Test-Path $PortableDir)) {
            Write-Host "portableフォルダがないため作成します。"
            New-Item -ItemType Directory -Path $PortableDir -Force | Out-Null
        }

        $PublicDesktop = "C:\Users\Public\Desktop"
        if (!(Test-Path $PublicDesktop)) {
            New-Item -ItemType Directory -Path $PublicDesktop -Force | Out-Null
        }

        $BlenderShortcutPath = Join-Path $PublicDesktop "Blender Portable.lnk"

        New-Shortcut `
            -ShortcutPath $BlenderShortcutPath `
            -TargetPath $LatestBlenderExe `
            -WorkingDirectory $LatestBlenderFolder `
            -Description "Blender Portable"

        Write-Host "ショートカットを確認・作成しました。"
        Write-Host "Blender本体: $LatestBlenderExe"
        Write-Host "ショートカット: $BlenderShortcutPath"
        return
    }

    # 既存のportableフォルダをバックアップ
    if (Test-Path $PortableBackupDir) {
        Remove-Item $PortableBackupDir -Recurse -Force
    }

    $CurrentBlenderExe = $null

    if (Test-Path $BlenderDestRoot) {
        $CurrentBlenderExe = Get-ChildItem `
            -Path $BlenderDestRoot `
            -Filter "blender.exe" `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    if ($null -ne $CurrentBlenderExe) {
        $CurrentBlenderFolder = Split-Path $CurrentBlenderExe.FullName -Parent
        $CurrentPortableDir = Join-Path $CurrentBlenderFolder "portable"

        if (Test-Path $CurrentPortableDir) {
            Write-Host "既存のportableフォルダをバックアップします。"
            Copy-Item `
                -Path $CurrentPortableDir `
                -Destination $PortableBackupDir `
                -Recurse `
                -Force
        }
        else {
            Write-Host "既存のportableフォルダはありません。"
        }
    }
    else {
        Write-Host "既存のBlender Portableは見つかりませんでした。新規配置として処理します。"
    }

    # Blender zipをダウンロード
    if (Test-Path $BlenderZip) {
        Write-Host "古いBlender zipを削除します。"
        Remove-Item $BlenderZip -Force
    }

    Write-Host "Blender Portable をダウンロードしています。時間がかかる場合があります..."

    Download-File `
        -Url $BlenderDownloadUrl `
        -OutFile $BlenderZip

    if (!(Test-Path $BlenderZip)) {
        throw "Blender Portable のzipがダウンロードされませんでした。"
    }

    $blenderZipSize = (Get-Item $BlenderZip).Length
    Write-Host "ダウンロードしたBlender zipのサイズ: $blenderZipSize bytes"

    if (!(Test-ZipFile -FilePath $BlenderZip)) {
        throw "ダウンロードしたBlender Portable がzipではありません。"
    }

    Write-Host "Blender Portable zip のダウンロードが完了しました。"

    # C:\Blender を入れ替え
    if (Test-Path $BlenderDestRoot) {
        Write-Host "既存の C:\Blender を削除します。"
        Remove-Item $BlenderDestRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $BlenderDestRoot -Force | Out-Null

    Write-Host "Blender Portable を C:\Blender に展開します。"

    Expand-Archive `
        -Path $BlenderZip `
        -DestinationPath $BlenderDestRoot `
        -Force `
        -ErrorAction Stop

    $NewBlenderExe = Get-ChildItem `
        -Path $BlenderDestRoot `
        -Filter "blender.exe" `
        -Recurse |
        Select-Object -First 1

    if ($null -eq $NewBlenderExe) {
        throw "展開後に blender.exe が見つかりませんでした。"
    }

    $NewBlenderFolder = Split-Path $NewBlenderExe.FullName -Parent
    $NewPortableDir = Join-Path $NewBlenderFolder "portable"

    # portableフォルダを復元、なければ新規作成
    if (Test-Path $PortableBackupDir) {
        Write-Host "portableフォルダを復元します。"
        Copy-Item `
            -Path $PortableBackupDir `
            -Destination $NewPortableDir `
            -Recurse `
            -Force
    }
    else {
        Write-Host "portableフォルダを新規作成します。"
        New-Item -ItemType Directory -Path $NewPortableDir -Force | Out-Null
    }

    # ショートカット作成
    $PublicDesktop = "C:\Users\Public\Desktop"

    if (!(Test-Path $PublicDesktop)) {
        New-Item -ItemType Directory -Path $PublicDesktop -Force | Out-Null
    }

    $BlenderShortcutPath = Join-Path $PublicDesktop "Blender Portable.lnk"

    if (Test-Path $BlenderShortcutPath) {
        Write-Host "既存のBlenderショートカットを削除します。"
        Remove-Item $BlenderShortcutPath -Force
    }

    New-Shortcut `
        -ShortcutPath $BlenderShortcutPath `
        -TargetPath $NewBlenderExe.FullName `
        -WorkingDirectory $NewBlenderFolder `
        -Description "Blender Portable"

    Write-Host "Blender Portable の更新が完了しました。"
    Write-Host "Blender本体: $($NewBlenderExe.FullName)"
    Write-Host "portableフォルダ: $NewPortableDir"
    Write-Host "ショートカット: $BlenderShortcutPath"
}

# ===================
# Wi-Fi設定の読み込み
# ===================
try {
    $WifiProfilePath = Join-Path $PSScriptRoot "wifiPassword.xml"

    if (Test-Path $WifiProfilePath) {
        Write-Host "==============================="
        Write-Host "Wi-Fi設定を読み込みます"
        Write-Host "==============================="

        netsh wlan add profile filename="$WifiProfilePath" user=current
    }
    else {
        Write-Host "wifiPassword.xml が見つからないため、Wi-Fi設定の読み込みをスキップします。"
    }
}
catch {
    Write-Host "Wi-Fi設定の読み込みに失敗しました。"
    Write-Host $_.Exception.Message
}

Start-Sleep -Seconds 5

# ===================
# wingetアプリ更新
# ===================
# BlenderFoundation.Blender は Portable版にしたため削除
$appLists = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Zoom.Zoom",
    "Microsoft.VisualStudioCode",
    "Valve.Steam",
    "Unity.UnityHub",
    "GIMP.GIMP.3",
    "FireAlpaca.FireAlpaca",
    "NickeManarin.ScreenToGif",
    "Fork.Fork",
    "GitHub.GitHubDesktop",
    "Microsoft.VisualStudio.Community"
)

foreach ($app in $appLists) {
    Write-Host "==================="
    Write-Host "更新チェック: $app"
    Write-Host "==================="

    try {
        winget upgrade `
            --id $app `
            -e `
            --accept-package-agreements `
            --accept-source-agreements
    }
    catch {
        Write-Host "更新中にエラーが発生しました: $app"
        Write-Host $_.Exception.Message
    }
}

# ===================
# Blender Portable 更新
# ===================
try {
    Update-BlenderPortable
}
catch {
    Write-Host "==============================="
    Write-Host "Blender Portable の更新に失敗しました"
    Write-Host "エラー内容:"
    Write-Host $_.Exception.Message
    Write-Host "==============================="
}

# ===================
# Epic Games Launcher 更新
# ===================
$epicGameLauncherId = "EpicGames.EpicGamesLauncher"

Write-Host "==================="
Write-Host "更新チェック: $epicGameLauncherId"
Write-Host "==================="

try {
    Write-Host "Epic Games Launcher を終了します。"
    Get-Process EpicGamesLauncher, EpicWebHelper -ErrorAction SilentlyContinue | Stop-Process -Force

    Start-Sleep -Seconds 2

    winget upgrade `
        --id $epicGameLauncherId `
        -e `
        --accept-package-agreements `
        --accept-source-agreements
}
catch {
    Write-Host "Epic Games Launcher の更新に失敗しました。"
    Write-Host $_.Exception.Message
}

# ===================
# Windows Update
# ===================
Write-Host "==================="
Write-Host "更新チェック: Windows Update"
Write-Host "==================="

try {
    # NuGet Provider がなければ入れる
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Host "NuGet Provider をインストールします。"
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    }

    # PSGalleryを信頼済みにする
    try {
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    }
    catch {}

    # PSWindowsUpdate がなければインストール
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "PSWindowsUpdate をインストールします。"
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser
    }

    Import-Module PSWindowsUpdate

    Write-Host "Windows Update の一覧を取得します。"

    $updates = Get-WindowsUpdate

    if ($null -eq $updates -or $updates.Count -eq 0) {
        Write-Host "Windows Update: 更新はありません。"
        Write-Host "処理を終了します。"
        Read-Host "Enterキーで終了"
        exit 0
    }

    Write-Host "Windows Update をインストールします。"

    $result = Install-WindowsUpdate `
        -AcceptAll `
        -Install `
        -IgnoreReboot `
        -PassThru

    $needReboot = $false

    if ($result | Where-Object { $_.RebootRequired -eq $true }) {
        $needReboot = $true
    }

    if (-not $needReboot) {
        try {
            $needReboot = (Get-WURebootStatus).RebootRequired
        }
        catch {}
    }

    if ($needReboot) {
        Write-Host "Windows Update: 再起動が必要です。再起動します。"
        Restart-Computer -Force
    }
    else {
        Write-Host "Windows Update: 再起動は不要です。"
    }
}
catch {
    Write-Host "Windows Update の処理に失敗しました。"
    Write-Host "エラー内容:"
    Write-Host $_.Exception.Message
}

Write-Host "==============================="
Write-Host "アプリ更新処理が完了しました"
Write-Host "==============================="

Read-Host "Enterキーで終了"