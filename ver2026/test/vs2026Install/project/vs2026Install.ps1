# 管理者でなければ昇格
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
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
