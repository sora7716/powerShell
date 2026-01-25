#wifiに接続(xmlファイルを読み込んで)
netsh wlan add profile filename="$PSScriptRoot\wifiPassword.xml" user=current
#RemoteSignedに状態をセット
Set-ExecutionPolicy RemoteSigned

# アプリのインストールするIDリスト
$appLists = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Zoom.Zoom",
    "Microsoft.VisualStudioCode",
    "Valve.Steam",
    "EpicGames.EpicGamesLauncher",
    "Unity.UnityHub",
    "BlenderFoundation.Blender",
    "Microsoft.VisualStudio.2022.Community"
)

# アプリのインストール
foreach ($app in $appLists) {
    winget install --id $app
}
#状態をセットにBypass
Set-ExecutionPolicy Bypass