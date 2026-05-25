Write-Host "==============================="
Write-Host "PCセットアップを開始します"
Write-Host "==============================="
Write-Host "実行内容:"
Write-Host "1. 管理者権限の確認"
Write-Host "2. Wi-Fi設定の読み込み"
Write-Host "8. GSUserの追加"
Write-Host "3. Windowsアップデートの確認"
Write-Host "4. OneDriveの停止・削除"
Write-Host "5. 基本アプリのインストール"
Write-Host "6. Visual Studioの設定"
Write-Host "7. Unityのインストール"
Write-Host "9. ノートンの削除"
Write-Host "==============================="

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

#ちょっと待つ(終了反映)
Start-Sleep -Seconds 5

#Logフォルダのパスを作成
$LogDir = Join-Path $PSScriptRoot "Logs"

#Logフォルダを追加
if(!(Test-Path $LogDir)){
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

#.logのパスを作成
$LogFile = Join-Path $LogDir ("setup_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")

#.logの追加
New-Item -ItemType File -Path $LogFile -Force | Out-Null

#ログを追加する関数
function Write-Log {
    param (
        [string] $Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string] $Level = "INFO"
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$time [$Level] $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

Write-Log "pcSetup.ps1 を開始しました"

Write-Host "==================="
Write-Output "GSUserを追加"
Write-Host "==================="
try {
    #アカウントを追加
    net user GSUser "" /add
    net localgroup Users GSUser /add
    if ($LASTEXITCODE -eq 0) {
      Write-Log "アカウントを追加に成功しました。"
    }else {
      Write-Log "アカウントを追加に失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "アカウントを追加中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

#Windowsアップデート
Write-Host "==================="
Write-Host "更新チェック: Windows Update"
Write-Host "==================="
try {
    # PSWindowsUpdate がなければインストール
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "PSWindowsUpdate をインストールします"

        Install-Module PSWindowsUpdate `
            -Force `
            -Scope CurrentUser `
            -AllowClobber `
            -Confirm:$false `
            -ErrorAction Stop
    }

    Import-Module PSWindowsUpdate -Force -ErrorAction Stop

    # 先に更新があるか確認
    $updates = Get-WindowsUpdate -ErrorAction Stop

    if ($null -eq $updates -or $updates.Count -eq 0) {
        Write-Log "Windows Update: 更新はありません。次の処理へ進みます。"
    }
    else {
        Write-Log "Windows Update: 更新があります。インストールします。"

        # インストール（再起動はまだしない）
        $result = Install-WindowsUpdate `
            -AcceptAll `
            -Install `
            -IgnoreReboot `
            -PassThru `
            -ErrorAction Stop

        # 再起動が必要かチェック
        $needReboot = $false

        if ($result | Where-Object { $_.RebootRequired -eq $true }) {
            $needReboot = $true
        }

        # 追加の保険
        if (-not $needReboot) {
            try {
                $rebootStatus = Get-WURebootStatus
                if ($rebootStatus.RebootRequired -eq $true) {
                    $needReboot = $true
                }
            }
            catch {
                Write-Log "再起動状態の確認に失敗しました。$($_.Exception.Message)" "WARN"
            }
        }

        if ($needReboot) {
            Write-Log "Windows Update: 再起動が必要です。再起動します。"
            Restart-Computer -Force
        }
        else {
            Write-Log "Windows Update: 再起動なし。次の処理へ進みます。"
        }
    }
}
catch {
    Write-Log "Windows Update 処理中にエラーが発生しました。$($_.Exception.Message)" "ERROR"
}

Write-Host "==================="
Write-Output "OneDriveのアンインストール"
Write-Host "==================="
try {
    #oneDriveのアンインストール
    winget uninstall --id Microsoft.OneDrive
    if ($LASTEXITCODE -eq 0) {
      Write-Log "OneDriveのアンインストールに成功しました。"
    }else {
      Write-Log "OneDriveのアンインストールに失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "OneDriveのアンインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

Write-Host "==================="
Write-Output "OneDriveのファイルの削除"
Write-Host "==================="
try {
    # oneDriveのファイルを削除
    Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force
    if ($LASTEXITCODE -eq 0) {
      Write-Log "OneDriveのファイルの削除に成功しました。"
    }else {
      Write-Log "OneDriveのファイルの削除に失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "OneDriveのファイルの削除中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

# アプリのインストールするIDリスト
$appLists = @(
    "Google.Chrome",
    "SlackTechnologies.Slack",
    "Zoom.Zoom",
    "Microsoft.VisualStudioCode",
    "Valve.Steam",
    "Unity.UnityHub",
    "GIMP.GIMP.3",
    "FireAlpaca.FireAlpaca",
    "BlenderFoundation.Blender",
    "NickeManarin.ScreenToGif",
    "Fork.Fork"
)

# アプリのインストール
foreach ($app in $appLists) {
    Write-Host "==================="
    Write-Output "セットアップ中: $app"
    Write-Host "==================="

    try {
        # まずは全ユーザー向けインストールを試す
        Write-Log "$app を machine scope でインストールします。"

        winget install -e --id $app `
            --source winget `
            --scope machine `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity

        $machineExitCode = $LASTEXITCODE

        if ($machineExitCode -eq 0) {
            Write-Log "$app の machine scope インストールに成功しました。"
        }
        else {
            Write-Log "$app の machine scope インストールに失敗しました。ExitCode=$machineExitCode 通常インストールを試します。" "WARN"

            # machine scope が受け付けられなかった場合、通常インストールを試す
            winget install -e --id $app `
                --source winget `
                --silent `
                --accept-package-agreements `
                --accept-source-agreements `
                --disable-interactivity

            $normalExitCode = $LASTEXITCODE

            if ($normalExitCode -eq 0) {
                Write-Log "$app の通常インストールに成功しました。"
            }
            else {
                Write-Log "$app の通常インストールにも失敗しました。ExitCode=$normalExitCode" "ERROR"
            }
        }
    }
    catch {
        Write-Log "$app のインストール中に例外が発生しました。エラー: $($_.Exception.Message)" "ERROR"
    }
}

#visualStudioのセットアップ
# Visual Studio Community(最新) + Workloads をまとめて入れる
$vsId = "Microsoft.VisualStudio.Community"

Write-Host "==================="
Write-Output "Visual Studio Community + Workload をインストール"
Write-Host "==================="

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

try {
    winget install -e --id $vsId `
        --source winget `
        --accept-package-agreements `
        --accept-source-agreements `
        --override $vsOverride

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Visual Studio Community + Workload のインストールに成功しました。"
    } else {
        Write-Log "Visual Studio Community + Workload のインストールに失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
} catch {
    Write-Log "Visual Studio Community + Workload のインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}
  
Write-Host "==================="
Write-Output "Unityのインストール: 6000.0.68f1"
Write-Host "==================="

# インストーラーの場所
$installer = Join-Path $PSScriptRoot "UnitySetup64-6000.0.68f1.exe"

#保存先 
$installPath = "C:\Unity\6000.0.68f1"

Write-Host "installer = $installer"
Write-Host "installPath = $installPath"

#.logに書き込み
Write-Log "installer = $installer"
Write-Log "installPath = $installPath"

#フォルダが存在するかを確認
if(!(Test-Path $installPath)){
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null 
}

try {
     #Unityをインストール（終了コード確認）
     $p = Start-Process -FilePath $installer `
    -ArgumentList @("/S", "/D=$installPath") `
    -Wait -PassThru
    Write-Host "ExitCode = $($p.ExitCode)"
    if ($LASTEXITCODE -eq 0) {
      Write-Log "Unityをインストールに成功しました。"
    }else {
      Write-Log "Unityをインストールに失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "Unityをインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

Write-Host "==================="
Write-Output "ノートンのアンインストール"
Write-Host "==================="
try {
    #ノートンのアンインストール
    winget uninstall --id NGC --silent
    if ($LASTEXITCODE -eq 0) {
      Write-Log "ノートンのアンインストールに成功しました。"
    }else {
      Write-Log "ノートンのアンインストールに失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "ノートンのアンインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}