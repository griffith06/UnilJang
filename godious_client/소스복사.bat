@echo off
chcp 65001 >nul
setlocal

:: ==========================================================
:: ★ 여기에 매번 바뀌는 작업 폴더 이름을 적어주세요.
:: ==========================================================
set "WORK_NAME=2_게임루프최적화"

:: (공통 타겟 기본 경로 - 수정할 필요 없음)
set "BASE_TARGET_DIR=F:\private\god\작업히스토리\%WORK_NAME%"


:: ==========================================================
:: 1. 첫 번째 폴더 복사 (GodiusClient)
:: ==========================================================
set "SOURCE_DIR=F:\private\god\cl\GodiusClient"
set "TARGET_DIR=%BASE_TARGET_DIR%\GodiusClient"

echo [알림] GodiusClient 파일 복사를 시작합니다...
echo 원본 경로: %SOURCE_DIR%
echo 대상 경로: %TARGET_DIR%
echo.

if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
)
robocopy "%SOURCE_DIR%" "%TARGET_DIR%" *.ini *.cpp *.ico *.h *.sln *.c *.rc *.vcxproj /S /R:0 /W:0


:: ==========================================================
:: 2. 두 번째 폴더 복사 (RESTools)
:: ==========================================================
set "SOURCE_DIR=F:\private\god\cl\RESTools"
set "TARGET_DIR=%BASE_TARGET_DIR%\RESTools"

echo.
echo [알림] RESTools 파일 복사를 시작합니다...
echo 원본 경로: %SOURCE_DIR%
echo 대상 경로: %TARGET_DIR%
echo.

if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
)
robocopy "%SOURCE_DIR%" "%TARGET_DIR%" *.ini *.cpp *.ico *.h *.sln *.c *.rc *.vcxproj /S /R:0 /W:0


echo.
echo [완료] 파일 복사 작업이 끝났습니다.
pause