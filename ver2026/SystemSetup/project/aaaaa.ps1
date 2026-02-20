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

Write-Host "==================="
Write-Output "OneDriveのリンク解除"
Write-Host "==================="
#oneDriveのリンクを解除
Stop-Process -Name OneDrive -Force

Write-Host "==================="
Write-Output "OneDriveのスタートアップの無効化"
Write-Host "==================="
#oneDireveのスタートアップの無効化
Get-Process | Where-Object {$_.MainWindowTitle -like "*OneDrive*"} | Stop-Process -Force

Write-Host "==================="
Write-Output "OneDriveのアンインストール"
Write-Host "==================="
#oneDriveのアンインストール
winget uninstall --id Microsoft.OneDrive

Write-Host "==================="
Write-Output "OneDriveのファイルの削除"
Write-Host "==================="
# oneDriveのファイルを削除
Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force

# アプリのインストールするIDリスト
$appLists = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Zoom.Zoom",
    "Microsoft.VisualStudioCode",
    "Valve.Steam",
    "Unity.UnityHub",
    "BlenderFoundation.Blender",
    "Fork.Fork",
    "GitHub.GitHubDesktop",
    "Microsoft.VisualStudio.2022.Community",
    "Microsoft.VisualStudio.Community"
)

# アプリのインストール
foreach ($app in $appLists) {
    Write-Host "==================="
    Write-Output "セットアップ中: $app"
    Write-Host "==================="
    winget install --id $app
}
#visualStudioのセットアップ
# Visual Studio Community(最新) + Workloads をまとめて入れる
$vsId = "Microsoft.VisualStudio.Community"
Write-Host "==================="
Write-Output "セットアップ中: $vsId"
Write-Host "==================="

Write-Host "==================="
Write-Output "ワークスペースを設定: $vsId"
Write-Host "==================="
# Workloads
$vsOverride = @(
  "--passive",
  "--norestart",
  "--wait",
  "--add Microsoft.VisualStudio.Workload.ManagedDesktop",
  "--add Microsoft.VisualStudio.Workload.NativeDesktop",
  "--add Microsoft.VisualStudio.Workload.Universal",
  "--add Microsoft.VisualStudio.Workload.NativeGame",
  "--add Microsoft.VisualStudio.Workload.ManagedGame"
) -join " "

#visualStudio(最新)のインストール
winget install -e --id $vsId `
  --accept-package-agreements --accept-source-agreements `
  --override $vsOverride

#visualStudio2022のセットアップ
Write-Host "==================="
Write-Output "ワークスペースを設定: visualStudio2022"
Write-Host "==================="
#-NoNewWindow -Waitはパワーシェル以外の所をひらかないようにする
$installerPath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe"
$arguments = @(
    "modify --installPath `"C:\Program Files\Microsoft Visual Studio\2022\Community`"",
    "--add Microsoft.VisualStudio.Workload.ManagedDesktop",
    "--add Microsoft.VisualStudio.Workload.NativeDesktop",
    "--add Microsoft.VisualStudio.Workload.Universal",
    "--add Microsoft.VisualStudio.Workload.NativeGame",
    "--add Microsoft.VisualStudio.Workload.ManagedGame",
    "--passive",
    "--norestart"
) -join " "
Start-Process -FilePath $installerPath -ArgumentList $arguments -NoNewWindow -Wait

Write-Host "==================="
Write-Output "Unityのインストール: 6000.0.68f1"
Write-Host "==================="

# インストーラーの場所
$installer = Join-Path $PSScriptRoot "UnitySetup64-6000.0.68f1.exe"

#保存先 
$installPath = "C:\Unity\6000.0.68f1"

Write-Host "installer = $installer"
Write-Host "installPath = $installPath"

#フォルダが存在するかを確認
if(!(Test-Path $installPath)){
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null 
}

# Unityをインストール（終了コード確認）
$p = Start-Process -FilePath $installer `
    -ArgumentList @("/S", "/D=$installPath") `
    -Wait -PassThru

Write-Host "ExitCode = $($p.ExitCode)"

Write-Host "==================="
Write-Output "GSUserを追加"
Write-Host "==================="
#アカウントを追加
net user GSUser "" /add
net localgroup Users GSUser /add

Write-Host "==================="
Write-Output "ノートンのアンインストール"
Write-Host "==================="
#ノートンのアンインストール
winget uninstall --id NGC --silent