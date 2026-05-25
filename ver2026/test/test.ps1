Write-Host "==============================="
Write-Host "PCセットアップを開始します"
Write-Host "==============================="
Write-Host "実行内容:"
Write-Host "1. 管理者権限の確認"
Write-Host "2. Wi-Fi設定の読み込み"
Write-Host "3. OneDriveの停止・削除"
Write-Host "4. 基本アプリのインストール"
Write-Host "5. Visual Studioの設定"
Write-Host "6. Unityのインストール"
Write-Host "7. GSUserの追加"
Write-Host "8. ノートンの削除"
Write-Host "==============================="

Write-Host "==============================="
Write-Host "アプリ更新を開始します"
Write-Host "==============================="
Write-Host "実行内容:"
Write-Host "1. 管理者権限の確認"
Write-Host "2. Wi-Fi設定の読み込み"
Write-Host "3. アプリの更新"
Write-Host "4. Epic Games Launcherの更新"
Write-Host "5. Windows Updateの適用"
Write-Host "6. 必要に応じて再起動"
Write-Host "==============================="

#フォルダのパスを作成
$LogDir = Join-Path $PSScriptRoot "Logs"

Write-Host "LogDir = [$LogDir]"

#フォルダを追加
if(!(Test-Path $LogDir)){
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

#.logのパスを作成
$LogFile = Join-Path $LogDir ("setup_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")

#.logの追加
New-Item -ItemType File -Path $LogDir -Force | Out-Null

Write-Host "LogFile = [$LogFile]"

#ログを追加する関数
function Write-Log {
    param (
        [string] $Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string] $Level = "INFO"
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$time [$Level] $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}


Write-Log "pcSetup.ps1 を開始しました"
Write-Log "実行ユーザー: $env:USERNAME"
Write-Log "ログ保存先: $LogDir"