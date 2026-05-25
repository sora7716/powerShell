# 管理者でなければ管理者へ変更
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

Write-Host "==============================="
Write-Host "PCセットアップを開始します"
Write-Host "==============================="
Write-Host "実行内容:"
Write-Host "1. 管理者権限の確認"
Write-Host "2. Wi-Fi設定の読み込み"
Write-Host "4. 基本アプリのインストール"
Write-Host "5. Visual Studioの設定"
Write-Host "==============================="

#ちょっと待つ(終了反映)
Start-Sleep -Seconds 5

# アプリのインストールするIDリスト
$appLists = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Zoom.Zoom",
    "Microsoft.VisualStudioCode",
    "GIMP.GIMP.3",
    "FireAlpaca.FireAlpaca",
    "BlenderFoundation.Blender",
    "NickeManarin.ScreenToGif",
    "Fork.Fork",
    "Microsoft.VisualStudio.Community",
    "Docker.DockerDesktop"
)

# アプリのインストール
foreach ($app in $appLists) {
    Write-Host "==================="
    Write-Output "セットアップ中: $app"
    Write-Host "==================="
    try {
        #アプリのインストール
        winget install --id $app
       if ($LASTEXITCODE -eq 0) {
        Write-Log "$app のインストールに成功しました。"
       }else {
        Write-Log "$app のインストールに失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
       }
    }catch {
        Write-Log "$app のインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
    }
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
try {
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
    Write-Log "ワークスペースを設定に成功しました。"
    if ($LASTEXITCODE -eq 0) {
      Write-Log "ワークスペースを設定に成功しました。"
    }else {
      Write-Log "ワークスペースを設定に失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "ワークスペースを設定中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

try {
    #visualStudio(最新)のインストール
    winget install -e --id $vsId `
    --accept-package-agreements --accept-source-agreements `
    --override $vsOverride
    if ($LASTEXITCODE -eq 0) {
      Write-Log "visualStudio(最新)のインストールに成功しました。"
    }else {
      Write-Log "visualStudio(最新)のインストールに失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "visualStudio(最新)のインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

