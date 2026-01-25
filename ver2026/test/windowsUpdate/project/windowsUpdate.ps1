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

#Windowsアップデート
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
    # Write-Host "Windows Update: 更新なし。"
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
    # Write-Host "Windows Update: 再起動が必要。再起動する。"
    Restart-Computer -Force
} else {
    #Write-Host "Windows Update: 再起動不要。完了。"
}