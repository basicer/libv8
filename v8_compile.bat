@echo off

setlocal

set "dir=%~dp0"
set "v8Dir=%dir%\v8"

if not exist "%v8Dir%" (
  echo V8 not found at %v8Dir%
  exit /b 1
)

set "depotToolsDir=%dir%\depot_tools"

if not exist "%depotToolsDir%" (
  echo Error: depot_tools directory not found at %depotToolsDir%
  exit /b 1
)

set "DEPOT_TOOLS_DIR=%depotToolsDir%"
set "DEPOT_TOOLS_WIN_TOOLCHAIN=0"

set "Path=%DEPOT_TOOLS_DIR%;%Path%"

for /F "delims=" %%i in ('call "%dir%\scripts\get_os.bat"') do (
  set "os=%%i"
)

for /F "delims=" %%i in ('call "%dir%\scripts\get_arch.bat"') do (
  set "targetCpu=%%i"
)

echo Building V8 for %os% %targetCpu%

setlocal EnableDelayedExpansion

set "args="

for /F "usebackq eol=# tokens=*" %%i in ("%dir%\args\%os%.gn") do (
  set "args=!args!%%i "
)

endlocal & set "gnArgs=%args%"

set "ccWrapper="

where sccache >nul 2>nul
if not errorlevel 1 (
  set "ccWrapper=sccache"
)

set "gnArgs=%gnArgs%cc_wrapper=""%ccWrapper%"""
set "gnArgs=%gnArgs% target_cpu=""%targetCpu%"""
set "gnArgs=%gnArgs% v8_target_cpu=""%targetCpu%"""

pushd "%dir%\v8"

rem Apply local Windows fixes after gclient sync, before generating build files.
rem See patches\README.md for upstream attribution and patch scope.
for %%p in ("%dir%patches\windows-*.patch") do (
  call :apply_patch "%%~fp"
  if errorlevel 1 (
    popd
    exit /b 1
  )
)

call gn gen ".\out\release" --args="%gnArgs%"
if errorlevel 1 (
  echo Failed to generate build files.
  exit /b %errorlevel%
)

echo ==================== Build args start ====================
call gn args ".\out\release" --list > "%dir%\gn-args_%os%.txt"
type "%dir%\gn-args_%os%.txt"
echo ==================== Build args end ====================

call ninja -C ".\out\release" -j %NUMBER_OF_PROCESSORS% v8_monolith
if errorlevel 1 (
  echo Build failed.
  exit /b %errorlevel%
)

dir ".\out\release\obj\v8_*.lib"

popd

endlocal
exit /b 0

:apply_patch
rem Cached source trees may already contain these changes.
git apply --reverse --check "%~1" >nul 2>nul
if not errorlevel 1 exit /b 0
git apply --check "%~1"
if errorlevel 1 (
  echo Failed to check Windows patch: %~nx1
  exit /b 1
)
git apply "%~1"
if errorlevel 1 (
  echo Failed to apply Windows patch: %~nx1
  exit /b 1
)
exit /b 0
