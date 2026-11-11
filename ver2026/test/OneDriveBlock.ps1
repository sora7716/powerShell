# OneDriveの起動禁止設定（Home版向け：レジストリ編集）のテスト用スクリプト
# 参考: https://shirakawaroom.com/2025/10/25/post-tips-14689/

# 管理者権限でなければ、管理者として自分自身を再実行する
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

#ログの準備
$LogDir = Join-Path $PSScriptRoot "Logs"
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir ("oneDriveBlock_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# 設定するレジストリの一覧
$settings = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSyncNGSC" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "DisableOneDrive" }
)

Write-Host "==================="
Write-Output "OneDriveの起動禁止設定"
Write-Host "==================="
foreach ($s in $settings) {
    try {
        # 既存キーに New-Item -Force すると他の値が消えるため、無い場合のみ作成する
        if (-not (Test-Path $s.Path)) {
            New-Item -Path $s.Path -Force | Out-Null
            Write-Log "キーを作成しました: $($s.Path)"
        }
        New-ItemProperty -Path $s.Path -Name $s.Name -Value 1 -PropertyType DWord -Force | Out-Null

        # 書き込めたか確認
        $value = (Get-ItemProperty -Path $s.Path -Name $s.Name -ErrorAction Stop).($s.Name)
        if ($value -eq 1) {
            Write-Log "設定を確認しました: $($s.Path)\$($s.Name) = $value"
        }
        else {
            Write-Log "設定値が想定と違います: $($s.Path)\$($s.Name) = $value" "ERROR"
        }
    }
    catch {
        Write-Log "設定中に例外が発生しました: $($s.Path)\$($s.Name) エラー$($_.Exception.Message)" "ERROR"
    }
}

Write-Host "ログ: $LogFile"
Read-Host "Enterキーで終了します"
