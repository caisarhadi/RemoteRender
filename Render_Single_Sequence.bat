@echo off
REM Selective Batch Render Script
REM Prompts the user for a 4-digit sequence code to render a specific queue.

if exist "RenderConfig.bat" (
    call "RenderConfig.bat"
    goto SKIP_CONFIG
)

set ENGINE="C:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
set PROJECT="D:\Project\MyProject.uproject"

:PROMPT_CONFIG
echo =========================================================
echo FIRST TIME SETUP
echo =========================================================
echo 1. Engine : %ENGINE%
echo 2. Project: %PROJECT%
echo.
set /p CHANGE_PATHS="Are these default paths correct? (Y/N): "
if /I "%CHANGE_PATHS%"=="Y" goto SAVE_CONFIG
if /I "%CHANGE_PATHS%"=="N" goto CUSTOM_CONFIG
goto PROMPT_CONFIG

:CUSTOM_CONFIG
echo.
set /p USER_ENGINE="Enter NEW Engine Path: "
if not "%USER_ENGINE%"=="" set ENGINE="%USER_ENGINE:"=%"
set /p USER_PROJECT="Enter NEW Project Path: "
if not "%USER_PROJECT%"=="" set PROJECT="%USER_PROJECT:"=%"

:SAVE_CONFIG
echo set ENGINE=%ENGINE%> "RenderConfig.bat"
echo set PROJECT=%PROJECT%>> "RenderConfig.bat"
echo.
echo Configuration saved to "RenderConfig.bat"! You won't be asked again.
echo.

:SKIP_CONFIG
set ARGS=-game -windowed -ResX=1280 -ResY=720 -log -notexturestreaming -unattended -nosound

echo =========================================================
echo SELECTIVE MOVIE RENDER QUEUE LAUNCHER
echo =========================================================
echo Available Sequences:
echo [0010] Opening Sequence
echo [0090] False Confidence
echo [0110] Staying Still
echo [0130] Dial Drunk
echo [0190] Northern Attitude
echo [0210] Orange Juice
echo.

set /p INPUT="Enter the 4-digit sequence code to render: "

if "%INPUT%"=="0010" goto SEQ_0010
if "%INPUT%"=="0090" goto SEQ_0090
if "%INPUT%"=="0110" goto SEQ_0110
if "%INPUT%"=="0130" goto SEQ_0130
if "%INPUT%"=="0190" goto SEQ_0190
if "%INPUT%"=="0210" goto SEQ_0210

echo.
echo Invalid input. The code must be one of: 0010, 0090, 0110, 0130, 0190, 0210.
timeout /t 5
exit /b

REM ---------------------------------------------------------
REM ROUTING LOGIC
REM ---------------------------------------------------------
:SEQ_0010
set QUEUE=/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0010_OpeningSequence.NK_RenderQueue_0010_OpeningSequence
goto RENDER

:SEQ_0090
set QUEUE=/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0090_FalseConfidence.NK_RenderQueue_0090_FalseConfidence
goto RENDER

:SEQ_0110
set QUEUE=/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0110_StayingStill.NK_RenderQueue_0110_StayingStill
goto RENDER

:SEQ_0130
set QUEUE=/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0130_DialDrunk.NK_RenderQueue_0130_DialDrunk
goto RENDER

:SEQ_0190
set QUEUE=/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0190_NorthernAttitude.NK_RenderQueue_0190_NorthernAttitude
goto RENDER

:SEQ_0210
set QUEUE=/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0210_OrangeJuice.NK_RenderQueue_0210_OrangeJuice
goto RENDER

REM ---------------------------------------------------------
REM EXECUTE RENDER COMMAND
REM ---------------------------------------------------------
:RENDER
echo.
echo Launching Render for Sequence %INPUT%...
%ENGINE% %PROJECT% %ARGS% -MoviePipelineConfig="%QUEUE%"
echo.
echo Render Complete!
timeout /t 5
exit /b
