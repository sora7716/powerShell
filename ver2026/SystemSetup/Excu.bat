
@echo off
setlocal EnableExtensions

echo 実行する番号を選んでください
echo 0: PCセットアップ
echo 1: アプリの更新のみ
echo.

set "number="
set /p number=番号を入力してください: 

echo 入力された番号: [%number%]
echo.

set "pcSetup=%~dp0project\pcSetup.ps1"
set "appUpdate=%~dp0project\appUpdate.ps1"

echo pcSetup: "%pcSetup%"
echo appUpdate: "%appUpdate%"
echo.

if "%number%"=="0" goto RUN0
if "%number%"=="1" goto RUN1

echo 無効な入力です
goto END

:RUN0
echo PCセットアップします
if not exist "%pcSetup%" (
    echo 見つかりません: "%pcSetup%"
    goto END
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%pcSetup%"
goto END

:RUN1
echo アプリ更新します
if not exist "%appUpdate%" (
    echo 見つかりません: "%appUpdate%"
    goto END
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%appUpdate%"
goto END

:END
echo.
echo 終了します
pause
