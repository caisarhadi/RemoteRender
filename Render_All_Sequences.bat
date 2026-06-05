@echo off
REM Complete Batch Render Script
REM This script will render multiple queues sequentially.

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

REM Base arguments for all renders
REM -nosound is added to prevent real-time audio playback/looping during the render.
set ARGS=-game -windowed -ResX=1280 -ResY=720 -log -notexturestreaming -unattended -nosound

echo =========================================================
echo Starting Full Batch Render...
echo =========================================================

echo.
echo Rendering Queue 1/6: NK_RenderQueue_0010_OpeningSequence
%ENGINE% %PROJECT% %ARGS% -MoviePipelineConfig="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0010_OpeningSequence.NK_RenderQueue_0010_OpeningSequence"

echo.
echo Rendering Queue 2/6: NK_RenderQueue_0110_StayingStill
%ENGINE% %PROJECT% %ARGS% -MoviePipelineConfig="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0110_StayingStill.NK_RenderQueue_0110_StayingStill"

echo.
echo Rendering Queue 3/6: NK_RenderQueue_0210_OrangeJuice
%ENGINE% %PROJECT% %ARGS% -MoviePipelineConfig="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0210_OrangeJuice.NK_RenderQueue_0210_OrangeJuice"

echo.
echo Rendering Queue 4/6: NK_RenderQueue_0190_NorthernAttitude
%ENGINE% %PROJECT% %ARGS% -MoviePipelineConfig="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0190_NorthernAttitude.NK_RenderQueue_0190_NorthernAttitude"

echo.
echo Rendering Queue 5/6: NK_RenderQueue_0130_DialDrunk
%ENGINE% %PROJECT% %ARGS% -MoviePipelineConfig="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0130_DialDrunk.NK_RenderQueue_0130_DialDrunk"

echo.
echo Rendering Queue 6/6: NK_RenderQueue_0090_FalseConfidence
%ENGINE% %PROJECT% %ARGS% -MoviePipelineConfig="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0090_FalseConfidence.NK_RenderQueue_0090_FalseConfidence"

echo.
echo =========================================================
echo All Batch Renders Completed Successfully!
echo =========================================================
timeout /t 5
