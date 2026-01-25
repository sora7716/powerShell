#wifiに接続(xmlファイルを読み込んで)
netsh wlan add profile filename="$PSScriptRoot\wifiPassword.xml" user=current

# Visual Studio Community（最新） + Workloads をまとめて入れる
$vsId = "Microsoft.VisualStudio.Community"

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

winget install -e --id $vsId `
  --accept-package-agreements --accept-source-agreements `
  --override $vsOverride

