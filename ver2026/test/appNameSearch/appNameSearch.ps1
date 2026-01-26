# アプリのインストールするIDリスト
$appLists = @(
    "Google Chrome",
    "Slack",
    "Zoom Workplace",
    "Microsoft Visual StudioCode",
    "Steam",
    "Epic Games Launcher",
    "Unity Hub",
    "blender",
    "VisualStudio Community 2022",
    "VisualStudio Community 2026"
)

# アプリのインストール
foreach ($app in $appLists) {
    Write-Host "==================="
    Write-Output "更新チェック: $app"
    Write-Host "==================="
    winget upgrade --name $app
}
