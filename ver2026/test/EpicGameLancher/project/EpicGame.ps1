#EpicGameLauncherの更新
$epicGameLauncherId = "EpicGames.EpicGamesLauncher"

#Epicを完全に止める
Get-Process EpicGamesLauncher, EpicWebHelper -ErrorAction SilentlyContinue | Stop-Process -Force
#ちょっと待つ(終了反映)
Start-Sleep -Seconds 2
#更新
winget upgrade -e --id $epicGameLauncherId --accept-package-agreements --accept-source-agreements