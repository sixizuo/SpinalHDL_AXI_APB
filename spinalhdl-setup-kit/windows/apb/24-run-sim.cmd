@echo off
rem ============================================================================
rem  24-run-sim.cmd -- APB3 crossbar Vivado simulation launcher (Windows side)
rem
rem  Usage:
rem      24-run-sim.cmd          batch : build project, run sim, print PASS/FAIL
rem      24-run-sim.cmd gui      open Vivado waveform window and stay there
rem
rem  Same structure as 14-run-sim.cmd, only the tcl and project dir change.
rem  Keep this file pure ASCII (see the note in 14-run-sim.cmd).
rem ============================================================================
setlocal enabledelayedexpansion

pushd "%~dp0..\.." & set "KIT=%CD%" & popd

rem ------------------------------------------------------------------ find Vivado
set "VIV=%VIVADO_BIN%"
if not "!VIV!"=="" goto have_viv

for /f "delims=" %%p in ('where vivado.bat 2^>nul') do (
    set "VIV=%%p"
    goto have_viv
)

for %%R in ("C:\AMDDesignTools" "D:\AMDDesignTools" "E:\AMDDesignTools" "C:\Xilinx\Vivado" "D:\Xilinx\Vivado") do (
    if exist "%%~R" (
        for /f "delims=" %%v in ('dir /b /ad /o-n "%%~R" 2^>nul') do (
            if not defined FOUND (
                if exist "%%~R\%%v\Vivado\bin\vivado.bat" set "FOUND=%%~R\%%v\Vivado\bin\vivado.bat"
                if exist "%%~R\%%v\bin\vivado.bat" set "FOUND=%%~R\%%v\bin\vivado.bat"
            )
        )
    )
)
set "VIV=!FOUND!"

:have_viv
if "!VIV!"=="" (
    echo [ERROR] vivado.bat not found.
    echo         Set VIVADO_BIN first, for example:
    echo             set VIVADO_BIN=C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat
    exit /b 1
)

rem ------------------------------------------------------------------ mode
set "MODE=%~1"
if "!MODE!"=="" set "MODE=batch"

if not exist "%KIT%\vivado-sim\apb" mkdir "%KIT%\vivado-sim\apb"

echo Using Vivado : !VIV!
echo Mode         : !MODE!
echo Project dir  : %KIT%\vivado-sim\apb\proj
echo.

if /i "!MODE!"=="gui" (
    "!VIV!" -mode gui -source "%~dp024-run-sim.tcl" -tclargs gui
) else (
    "!VIV!" -mode batch -notrace -nojournal -log "%KIT%\vivado-sim\apb\vivado.log" -source "%~dp024-run-sim.tcl" -tclargs batch
)

set "RC=%ERRORLEVEL%"
echo.
if exist "%KIT%\vivado-sim\apb\verdict.txt" (
    set /p V=<"%KIT%\vivado-sim\apb\verdict.txt"
    echo Verdict: !V!
)
if not "%RC%"=="0" (
    echo.
    echo [HINT] If several Vivado versions are installed, this launcher picked the
    echo        newest one. If that one has no license, point VIVADO_BIN to the
    echo        version you actually use, for example:
    echo            set VIVADO_BIN=C://AMDDesignTools//2025.2//Vivado//bin//vivado.bat
)
exit /b %RC%
