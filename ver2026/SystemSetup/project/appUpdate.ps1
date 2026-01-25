# 管理者でなければ昇格
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

#wifiに接続(xmlファイルを読み込んで)
netsh wlan add profile filename="$PSScriptRoot\wifiPassword.xml" user=current
#ちょっと待つ(終了反映)
Start-Sleep -Seconds 5

# アプリのインストールするIDリスト
$appLists = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Zoom.Zoom",
    "Microsoft.VisualStudioCode",
    "Valve.Steam",
    "Unity.UnityHub",
    "BlenderFoundation.Blender",
    "Microsoft.VisualStudio.2022.Community",
    "Microsoft.VisualStudio.Community"
)

# アプリのインストール
foreach ($app in $appLists) {
    Write-Host "==================="
    Write-Output "更新チェック: $app"
    Write-Host "==================="
    winget upgrade --id $app
}

#EpicGameLauncherの更新
$epicGameLauncherId = "EpicGames.EpicGamesLauncher"
Write-Host "==================="
Write-Output "更新チェック: $epicGameLauncherId"
Write-Host "==================="

#Epicを完全に止める
Get-Process EpicGamesLauncher, EpicWebHelper -ErrorAction SilentlyContinue | Stop-Process -Force
#ちょっと待つ(終了反映)
Start-Sleep -Seconds 2
#更新
winget upgrade -e --id $epicGameLauncherId --accept-package-agreements --accept-source-agreements

#Windowsアップデート
Write-Host "==================="
Write-Host "更新チェック: WindowsUpdate"
Write-Host "==================="

#PSWindowwsUpdateをなければインストール
if(-not (Get-Module -ListAvailable -Name PSWindowsUpdate)){
  Install-Module PSWindowsUpdate -Force -Scope CurrentUser
}

Import-Module PSWindowsUpdate

#更新があればインストール
Install-WindowsUpdate -AcceptAll -Install -IgnoreReboot
# 更新があるか確認
$updates = Get-WindowsUpdate

if ($null -eq $updates -or $updates.Count -eq 0) {
    exit 0
}

# インストール（再起動はまだしない）
$result = Install-WindowsUpdate -AcceptAll -Install -IgnoreReboot -PassThru

# 再起動が必要かチェック
$needReboot = $false

if ($result | Where-Object { $_.RebootRequired -eq $true }) {
    $needReboot = $true
}

# 追加の保険（システム側の再起動フラグ確認）
if (-not $needReboot) {
    try {
        $needReboot = (Get-WURebootStatus).RebootRequired
    } catch {}
}

# 必要なら再起動
if ($needReboot) {
    Write-Host "Windows Update: 再起動あり。再起動後に終了します。"
    Restart-Computer -Force
} else {
    Write-Host "Windows Update: 再起動なし。再起動をせずに終了します。"
}