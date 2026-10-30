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

Write-Host "==================="
Write-Host "KamataEngine と Blender Portable の配置を開始します"
Write-Host "==================="

# ===================
# Blender Portable のURLを取得する関数
# ===================
function Get-BlenderPortableUrl {
    $DownloadPageUrl = "https://www.blender.org/download/"

    Write-Host "Blender公式ダウンロードページを確認しています..."

    $page = Invoke-WebRequest `
        -Uri $DownloadPageUrl `
        -UseBasicParsing `
        -ErrorAction Stop

    $html = $page.Content

    # HTML内の表記ゆれ対策
    $html = $html -replace "\\/", "/"
    $html = $html -replace "&amp;", "&"

    # Blender Windows Portable zip のURLを探す
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
# ZIPファイルか確認する関数
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

    # ZIPファイルは先頭が PK になる
    $signature = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 2)

    return ($signature -eq "PK")
}

# ===================
# ファイルをダウンロードする関数
# ===================
function Download-File {
    param (
        [string] $Url,
        [string] $OutFile
    )

    Write-Host "ダウンロード元: $Url"
    Write-Host "保存先: $OutFile"

    # BITSが使えるならBITSを優先
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
# ショートカットを作成する関数
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
# メイン処理
# ===================
try {
    # ps1ファイルが置いてあるフォルダ
    $ScriptDir = $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
        $ScriptDir = (Get-Location).Path
    }

    Write-Host "スクリプトの場所: $ScriptDir"

    # ===================
    # KamataEngine.zip を C:\ にコピー
    # ===================
    Write-Host "-------------------"
    Write-Host "KamataEngine.zip のコピーを開始します"

    $SourceKamataZip = Join-Path $ScriptDir "KamataEngine.zip"
    $DestKamataZip = "C:\KamataEngine.zip"
    $KamataEngineExtractDir = "C:\KamataEngine"

    Write-Host "コピー元: $SourceKamataZip"
    Write-Host "コピー先: $DestKamataZip"

    if (!(Test-Path $SourceKamataZip)) {
        throw "KamataEngine.zip が見つかりません。ps1ファイルと同じフォルダに置いてください。"
    }

    if (!(Test-ZipFile -FilePath $SourceKamataZip)) {
        throw "コピー元の KamataEngine.zip が正しいzipファイルではありません。"
    }

    Copy-Item `
        -Path $SourceKamataZip `
        -Destination $DestKamataZip `
        -Force `
        -ErrorAction Stop

    $sourceHash = (Get-FileHash $SourceKamataZip -Algorithm SHA256).Hash
    $destHash = (Get-FileHash $DestKamataZip -Algorithm SHA256).Hash

    if ($sourceHash -ne $destHash) {
        throw "KamataEngine.zip のコピー確認に失敗しました。コピー元とコピー先が一致していません。"
    }

    Write-Host "KamataEngine.zip のコピーが完了しました。"

    # ===================
    # KamataEngine.zip を C:\KamataEngine に展開
    # ===================
    Write-Host "-------------------"
    Write-Host "KamataEngine.zip を C:\KamataEngine に展開します"

    if (Test-Path $KamataEngineExtractDir) {
        Write-Host "既存の C:\KamataEngine を削除します。"
        Remove-Item $KamataEngineExtractDir -Recurse -Force -ErrorAction Stop
    }

    New-Item -ItemType Directory -Path $KamataEngineExtractDir -Force | Out-Null

    Expand-Archive `
        -Path $DestKamataZip `
        -DestinationPath $KamataEngineExtractDir `
        -Force `
        -ErrorAction Stop

    Write-Host "KamataEngine.zip の展開が完了しました。"
    Write-Host "展開先: $KamataEngineExtractDir"

    # ===================
    # Blender Portable をダウンロード
    # ===================
    Write-Host "-------------------"
    Write-Host "Blender Portable のダウンロードを開始します"

    $TempDir = Join-Path $env:TEMP "BlenderPortableSetup"
    $BlenderZip = Join-Path $TempDir "blender-portable.zip"
    $BlenderDestRoot = "C:\Blender"

    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    $BlenderDownloadUrl = Get-BlenderPortableUrl

    Write-Host "Blender Portable のダウンロードURL:"
    Write-Host $BlenderDownloadUrl

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
        throw "ダウンロードしたBlenderファイルがzipではありません。URLがHTMLページを返している可能性があります。"
    }

    Write-Host "Blender Portable zip のダウンロードが完了しました。"

    # ===================
    # Blender を C:\Blender に展開
    # ===================
    Write-Host "-------------------"
    Write-Host "Blender Portable を C:\Blender に展開します"

    if (Test-Path $BlenderDestRoot) {
        Write-Host "既存の C:\Blender を削除します。"
        Remove-Item $BlenderDestRoot -Recurse -Force -ErrorAction Stop
    }

    New-Item -ItemType Directory -Path $BlenderDestRoot -Force | Out-Null

    Expand-Archive `
        -Path $BlenderZip `
        -DestinationPath $BlenderDestRoot `
        -Force `
        -ErrorAction Stop

    Write-Host "Blender Portable の展開が完了しました。"

    # blender.exe を探す
    Write-Host "blender.exe を探しています..."

    $BlenderExe = Get-ChildItem `
        -Path $BlenderDestRoot `
        -Filter "blender.exe" `
        -Recurse |
        Select-Object -First 1

    if ($null -eq $BlenderExe) {
        throw "展開後に blender.exe が見つかりませんでした。"
    }

    $BlenderFolder = Split-Path $BlenderExe.FullName -Parent

    Write-Host "Blender本体を見つけました。"
    Write-Host "Blender本体: $($BlenderExe.FullName)"

    # Blenderをポータブル扱いにするための portable フォルダ
    $PortableDir = Join-Path $BlenderFolder "portable"

    New-Item -ItemType Directory -Path $PortableDir -Force | Out-Null

    Write-Host "Blender用の portable フォルダを作成しました。"
    Write-Host "portableフォルダ: $PortableDir"

    # ===================
    # Blenderのショートカットをデスクトップに作成
    # ===================
    Write-Host "-------------------"
    Write-Host "Blender Portable のショートカットをデスクトップに作成します"

    $PublicDesktop = "C:\Users\Public\Desktop"

    if (!(Test-Path $PublicDesktop)) {
        Write-Host "Public Desktop が見つからないため作成します。"
        New-Item -ItemType Directory -Path $PublicDesktop -Force | Out-Null
    }

    $BlenderShortcutPath = Join-Path $PublicDesktop "Blender Portable.lnk"

    if (Test-Path $BlenderShortcutPath) {
        Write-Host "既存のBlenderショートカットを削除します。"
        Remove-Item $BlenderShortcutPath -Force
    }

    New-Shortcut `
        -ShortcutPath $BlenderShortcutPath `
        -TargetPath $BlenderExe.FullName `
        -WorkingDirectory $BlenderFolder `
        -Description "Blender Portable"

    Write-Host "Blender Portable のショートカットを作成しました。"
    Write-Host "ショートカット: $BlenderShortcutPath"

    # ===================
    # 成功表示
    # ===================
    Write-Host "==================="
    Write-Host "成功しました"
    Write-Host "KamataEngine.zip: $DestKamataZip"
    Write-Host "KamataEngine展開先: $KamataEngineExtractDir"
    Write-Host "Blenderフォルダ: $BlenderFolder"
    Write-Host "Blender本体: $($BlenderExe.FullName)"
    Write-Host "portableフォルダ: $PortableDir"
    Write-Host "Blenderショートカット: $BlenderShortcutPath"
    Write-Host "==================="
}
catch {
    Write-Host "==================="
    Write-Host "失敗しました"
    Write-Host "エラー内容:"
    Write-Host $_.Exception.Message
    Write-Host "==================="
}

Read-Host "Enterキーで終了"