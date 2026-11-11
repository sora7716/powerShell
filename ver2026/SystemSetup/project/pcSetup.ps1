# ===================
# 基本設定
# ===================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

Write-Host "==================="
Write-Host "KamataEngine と Blender Portable の配置を開始します"
Write-Host "==================="

# ===================
# Blender Portable のURLを取得する関数
# ===================
function Get-BlenderPortableUrl {
    $DownloadPageUrl = "https://www.blender.org/download/"

    Write-Host "Blender公式ダウンロードページを確認しています..."

    $page = Invoke-WebRequest `
        -Uri $DownloadPageUrl `
        -UseBasicParsing `
        -ErrorAction Stop

    $html = $page.Content

    # HTML内の表記ゆれ対策
    $html = $html -replace "\\/", "/"
    $html = $html -replace "&amp;", "&"

    # Blender Windows Portable zip のURLを探す
    $patterns = @(
        "https://www\.blender\.org/download/release/Blender[0-9\.]+/blender-[0-9\.]+-windows-x64\.zip",
        "https://download\.blender\.org/release/Blender[0-9\.]+/blender-[0-9\.]+-windows-x64\.zip"
    )

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($html, $pattern)

        if ($matches.Count -gt 0) {
            $url = $matches[0].Value

            # www.blender.org/download/release はHTMLを返すことがあるため、
            # 実ファイル配布用の download.blender.org/release に変換する
            $url = $url -replace "^https://www\.blender\.org/download/release/", "https://download.blender.org/release/"

            return $url
        }
    }

    throw "Blender Portable のダウンロードURLが見つかりませんでした。"
}

# ===================
# ZIPファイルか確認する関数
# ===================
function Test-ZipFile {
    param (
        [string] $FilePath
    )

    if (!(Test-Path $FilePath)) {
        return $false
    }

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    if ($bytes.Length -lt 2) {
        return $false
    }

    # ZIPファイルは先頭が PK になる
    $signature = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 2)

    return ($signature -eq "PK")
}

# ===================
# ファイルをダウンロードする関数
# ===================
function Download-File {
    param (
        [string] $Url,
        [string] $OutFile
    )

    Write-Host "ダウンロード元: $Url"
    Write-Host "保存先: $OutFile"

    # BITSが使えるならBITSを優先
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        try {
            Start-BitsTransfer `
                -Source $Url `
                -Destination $OutFile `
                -ErrorAction Stop

            return
        }
        catch {
            Write-Host "BITSでのダウンロードに失敗しました。Invoke-WebRequestで再試行します。"
        }
    }

    Invoke-WebRequest `
        -Uri $Url `
        -OutFile $OutFile `
        -UseBasicParsing `
        -ErrorAction Stop
}

# ===================
# ショートカットを作成する関数
# ===================
function New-Shortcut {
    param (
        [string] $ShortcutPath,
        [string] $TargetPath,
        [string] $WorkingDirectory,
        [string] $Description
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)

    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $shortcut.IconLocation = "$TargetPath,0"

    $shortcut.Save()
}

Write-Host "==============================="
Write-Host "PCセットアップを開始します"
Write-Host "==============================="
Write-Host "実行内容:"
Write-Host "1. 管理者権限の確認"
Write-Host "2. Wi-Fi設定の読み込み"
Write-Host "3. GSUserの追加"
Write-Host "4. Windowsアップデートの確認"
Write-Host "5. OneDriveの停止・削除"
Write-Host "6. 基本アプリのインストール"
Write-Host "7. Visual Studioの設定"
Write-Host "8. Unityのインストール"
Write-Host "9. KamataEngineをGSUserに追加"
Write-Host "10. Blender PortableをGSUserに追加"
Write-Host "11. ノートンの削除"
Write-Host "==============================="

# 管理者でなければ管理者として再実行
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        throw "このスクリプトを .ps1 ファイルとして保存して実行してください。"
    }

    $PowerShellExe = if ($PSVersionTable.PSEdition -eq 'Core') {
        (Get-Command pwsh.exe -ErrorAction Stop).Source
    } else {
        (Get-Command powershell.exe -ErrorAction Stop).Source
    }

    Start-Process $PowerShellExe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

# Wi-Fi設定は任意。同梱ファイルがそのPC用である場合だけ読み込む。
$WifiProfilePath = Join-Path $PSScriptRoot "wifiPassword.xml"
if (Test-Path $WifiProfilePath) {
    try {
        $Netsh = Get-Command netsh.exe -ErrorAction Stop
        & $Netsh.Source wlan add profile "filename=$WifiProfilePath" user=current | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Wi-Fiプロファイルを読み込みました。"
        } else {
            Write-Host "Wi-Fiプロファイルを読み込めませんでした。ExitCode=$LASTEXITCODE"
        }
    } catch {
        Write-Host "Wi-Fi設定をスキップします: $($_.Exception.Message)"
    }
} else {
    Write-Host "wifiPassword.xml がないため、Wi-Fi設定をスキップします。"
}

# ログはインストール元が読み取り専用でも保存できる共通データ領域へ出す。
$LogDir = Join-Path $env:ProgramData "GSSetup\Logs"

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
    # LocalAccountsモジュールで空パスワードのローカルユーザーを作成する。
    # 既存ユーザーは変更せず、ローカルUsersグループへの所属だけ確認する。
    $existingUser = Get-LocalUser -Name "GSUser" -ErrorAction SilentlyContinue
    if (-not $existingUser) {
        New-LocalUser -Name "GSUser" -NoPassword -Description "セットアップ用ユーザー" -ErrorAction Stop | Out-Null
        Write-Log "GSUserをパスワードなしで作成しました。"
    } else {
        Write-Log "GSUserはすでに存在するため、作成をスキップします。"
    }

    $usersGroup = Get-LocalGroup -SID 'S-1-5-32-545' -ErrorAction Stop
    $member = Get-LocalGroupMember -Group $usersGroup -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '\\GSUser$' }
    if (-not $member) {
        Add-LocalGroupMember -Group $usersGroup -Member "GSUser" -ErrorAction Stop
    }
    Write-Log "GSUserを標準ユーザーグループに追加しました。"
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
            Write-Log "Windows Update: 再起動が必要です。作業中のデータ保護のため自動再起動は行いません。" "WARN"
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
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "wingetが見つからないため、OneDriveのアンインストールをスキップします。"
    }
    winget uninstall --id Microsoft.OneDrive --exact --silent --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
      Write-Log "OneDriveのアンインストールに成功しました。"
    }elseif ($LASTEXITCODE -eq -1978335212) {
      # 0x8A150014: 該当パッケージなし（既にアンインストール済み）
      Write-Log "OneDriveは既にアンインストールされています。"
    }else {
      Write-Log "OneDriveのアンインストールに失敗しました。ExitCode=$LASTEXITCODE" "ERROR"
    }
}catch {
    Write-Log "OneDriveのアンインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

Write-Host "==================="
Write-Output "OneDriveの起動禁止設定"
Write-Host "==================="
try {
    # グループポリシー「OneDrive をファイル記憶域として使用できないようにする」に相当
    $oneDrivePolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
    # 既存キーに New-Item -Force すると他の値が消えるため、無い場合のみ作成する
    if (-not (Test-Path $oneDrivePolicyKey)) { New-Item -Path $oneDrivePolicyKey -Force | Out-Null }
    New-ItemProperty -Path $oneDrivePolicyKey -Name "DisableFileSyncNGSC" -Value 1 -PropertyType DWord -Force | Out-Null

    $explorerPolicyKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (-not (Test-Path $explorerPolicyKey)) { New-Item -Path $explorerPolicyKey -Force | Out-Null }
    New-ItemProperty -Path $explorerPolicyKey -Name "DisableOneDrive" -Value 1 -PropertyType DWord -Force | Out-Null

    Write-Log "OneDriveの起動禁止設定に成功しました。"
}catch {
    Write-Log "OneDriveの起動禁止設定中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

Write-Host "==================="
Write-Output "OneDriveのファイルの削除"
Write-Host "==================="
try {
    # ユーザーデータを巻き込むため、OneDriveの同期フォルダーは削除しない。
    Write-Log "OneDriveのユーザーデータは保持しました。"
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

        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            throw "wingetが見つかりません。App Installerを導入してから再実行してください。"
        }

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
$installPath = Join-Path $env:ProgramFiles "Unity\6000.0.68f1"

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
     if (-not (Test-Path $installer)) {
        throw "Unityインストーラーが同じフォルダーにありません。Unityの処理をスキップします。"
     }
     $p = Start-Process -FilePath $installer `
    -ArgumentList @("/S", "/D=$installPath") `
    -Wait -PassThru
    Write-Host "ExitCode = $($p.ExitCode)"
    if ($p.ExitCode -eq 0) {
      Write-Log "Unityをインストールに成功しました。"
    }else {
      Write-Log "Unityをインストールに失敗しました。ExitCode=$($p.ExitCode)" "ERROR"
    }
}catch {
    Write-Log "Unityをインストール中に例外が発生しました。エラー$($_.Exception.Message)" "ERROR"
}

try {
    # ps1ファイルが置いてあるフォルダ
    $ScriptDir = $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
        $ScriptDir = (Get-Location).Path
    }

    Write-Host "スクリプトの場所: $ScriptDir"

    # ===================
    # KamataEngine.zip を C:\ にコピー
    # ===================
    Write-Host "-------------------"
    Write-Host "KamataEngine.zip のコピーを開始します"

    $SourceKamataZip = Join-Path $ScriptDir "KamataEngine.zip"
    $DestKamataZip = Join-Path $env:SystemDrive "KamataEngine.zip"
    $KamataEngineExtractDir = Join-Path $env:SystemDrive "KamataEngine"

    Write-Host "コピー元: $SourceKamataZip"
    Write-Host "コピー先: $DestKamataZip"

    if (!(Test-Path $SourceKamataZip)) {
        throw "KamataEngine.zip が見つかりません。ps1ファイルと同じフォルダに置いてください。"
    }

    if (!(Test-ZipFile -FilePath $SourceKamataZip)) {
        throw "コピー元の KamataEngine.zip が正しいzipファイルではありません。"
    }

    Copy-Item `
        -Path $SourceKamataZip `
        -Destination $DestKamataZip `
        -Force `
        -ErrorAction Stop

    $sourceHash = (Get-FileHash $SourceKamataZip -Algorithm SHA256).Hash
    $destHash = (Get-FileHash $DestKamataZip -Algorithm SHA256).Hash

    if ($sourceHash -ne $destHash) {
        throw "KamataEngine.zip のコピー確認に失敗しました。コピー元とコピー先が一致していません。"
    }

    Write-Host "KamataEngine.zip のコピーが完了しました。"

    # ===================
    # KamataEngine.zip を C:\KamataEngine に展開
    # ===================
    Write-Host "-------------------"
    Write-Host "KamataEngine.zip を C:\KamataEngine に展開します"

    if (Test-Path $KamataEngineExtractDir) {
        Write-Host "既存の C:\KamataEngine を削除します。"
        Remove-Item $KamataEngineExtractDir -Recurse -Force -ErrorAction Stop
    }

    New-Item -ItemType Directory -Path $KamataEngineExtractDir -Force | Out-Null

    Expand-Archive `
        -Path $DestKamataZip `
        -DestinationPath $KamataEngineExtractDir `
        -Force `
        -ErrorAction Stop

    Write-Host "KamataEngine.zip の展開が完了しました。"
    Write-Host "展開先: $KamataEngineExtractDir"

    # ===================
    # Blender Portable をダウンロード
    # ===================
    Write-Host "-------------------"
    Write-Host "Blender Portable のダウンロードを開始します"

    $TempDir = Join-Path $env:TEMP "BlenderPortableSetup"
    $BlenderZip = Join-Path $TempDir "blender-portable.zip"
    $BlenderDestRoot = Join-Path $env:SystemDrive "Blender"

    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    $BlenderDownloadUrl = Get-BlenderPortableUrl

    Write-Host "Blender Portable のダウンロードURL:"
    Write-Host $BlenderDownloadUrl

    if (Test-Path $BlenderZip) {
        Write-Host "古いBlender zipを削除します。"
        Remove-Item $BlenderZip -Force
    }

    Write-Host "Blender Portable をダウンロードしています。時間がかかる場合があります..."

    Download-File `
        -Url $BlenderDownloadUrl `
        -OutFile $BlenderZip

    if (!(Test-Path $BlenderZip)) {
        throw "Blender Portable のzipがダウンロードされませんでした。"
    }

    $blenderZipSize = (Get-Item $BlenderZip).Length
    Write-Host "ダウンロードしたBlender zipのサイズ: $blenderZipSize bytes"

    if (!(Test-ZipFile -FilePath $BlenderZip)) {
        throw "ダウンロードしたBlenderファイルがzipではありません。URLがHTMLページを返している可能性があります。"
    }

    Write-Host "Blender Portable zip のダウンロードが完了しました。"

    # ===================
    # Blender を C:\Blender に展開
    # ===================
    Write-Host "-------------------"
    Write-Host "Blender Portable を C:\Blender に展開します"

    if (Test-Path $BlenderDestRoot) {
        Write-Host "既存の C:\Blender を削除します。"
        Remove-Item $BlenderDestRoot -Recurse -Force -ErrorAction Stop
    }

    New-Item -ItemType Directory -Path $BlenderDestRoot -Force | Out-Null

    Expand-Archive `
        -Path $BlenderZip `
        -DestinationPath $BlenderDestRoot `
        -Force `
        -ErrorAction Stop

    Write-Host "Blender Portable の展開が完了しました。"

    # blender.exe を探す
    Write-Host "blender.exe を探しています..."

    $BlenderExe = Get-ChildItem `
        -Path $BlenderDestRoot `
        -Filter "blender.exe" `
        -Recurse |
        Select-Object -First 1

    if ($null -eq $BlenderExe) {
        throw "展開後に blender.exe が見つかりませんでした。"
    }

    $BlenderFolder = Split-Path $BlenderExe.FullName -Parent

    Write-Host "Blender本体を見つけました。"
    Write-Host "Blender本体: $($BlenderExe.FullName)"

    # Blenderをポータブル扱いにするための portable フォルダ
    $PortableDir = Join-Path $BlenderFolder "portable"

    New-Item -ItemType Directory -Path $PortableDir -Force | Out-Null

    Write-Host "Blender用の portable フォルダを作成しました。"
    Write-Host "portableフォルダ: $PortableDir"

    # ===================
    # Blenderのショートカットをデスクトップに作成
    # ===================
    Write-Host "-------------------"
    Write-Host "Blender Portable のショートカットをデスクトップに作成します"

    $PublicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')

    if (!(Test-Path $PublicDesktop)) {
        Write-Host "Public Desktop が見つからないため作成します。"
        New-Item -ItemType Directory -Path $PublicDesktop -Force | Out-Null
    }

    $BlenderShortcutPath = Join-Path $PublicDesktop "Blender Portable.lnk"

    if (Test-Path $BlenderShortcutPath) {
        Write-Host "既存のBlenderショートカットを削除します。"
        Remove-Item $BlenderShortcutPath -Force
    }

    New-Shortcut `
        -ShortcutPath $BlenderShortcutPath `
        -TargetPath $BlenderExe.FullName `
        -WorkingDirectory $BlenderFolder `
        -Description "Blender Portable"

    Write-Host "Blender Portable のショートカットを作成しました。"
    Write-Host "ショートカット: $BlenderShortcutPath"

    # ===================
    # 成功表示
    # ===================
    Write-Host "==================="
    Write-Host "成功しました"
    Write-Host "KamataEngine.zip: $DestKamataZip"
    Write-Host "KamataEngine展開先: $KamataEngineExtractDir"
    Write-Host "Blenderフォルダ: $BlenderFolder"
    Write-Host "Blender本体: $($BlenderExe.FullName)"
    Write-Host "portableフォルダ: $PortableDir"
    Write-Host "Blenderショートカット: $BlenderShortcutPath"
    Write-Host "==================="
}
catch {
    Write-Host "==================="
    Write-Host "失敗しました"
    Write-Host "エラー内容:"
    Write-Host $_.Exception.Message
    Write-Host "==================="
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

Read-Host "Enterキーで終了"
