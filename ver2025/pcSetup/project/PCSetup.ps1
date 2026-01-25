#wifiに接続(xmlファイルを読み込んで)
$xmlFilePath=Read-Host "xmlFilePath"
netsh wlan add profile filename=$xmlFilePath user=current
#RemoteSignedに状態をセット
Set-ExecutionPolicy RemoteSigned
#oneDriveのリンクを解除
Stop-Process -Name OneDrive -Force
#oneDireveのスタートアップの無効化
Get-Process | Where-Object {$_.MainWindowTitle -like "*OneDrive*"} | Stop-Process -Force
#oneDriveのアンインストール
winget uninstall --id Microsoft.OneDrive
# oneDriveのファイルを削除
Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force

# アプリのインストールするIDリスト
$appLists = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Zoom.Zoom",
    "Microsoft.VisualStudioCode",
    "Valve.Steam",
    "EpicGames.EpicGamesLauncher",
    "Unity.UnityHub",
    "Microsoft.VisualStudio.2022.Community"
)

# アプリのインストール
foreach ($app in $appLists) {
    winget install --id $app
}

#visualStudioのセットアップ
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
#アカウントを追加
net user GSUser "" /add
net localgroup Users GSUser /add
#状態をセットにBypass
Set-ExecutionPolicy Bypass
#ノートンのアンインストール
winget uninstall --id NGC --silent