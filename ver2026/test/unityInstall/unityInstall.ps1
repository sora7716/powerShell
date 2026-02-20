# 管理者でなければ管理者に変更
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

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