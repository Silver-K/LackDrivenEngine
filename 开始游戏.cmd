@echo off
chcp 65001 >nul
cd /d "%~dp0"
if exist ".tools\godot\Godot_v4.6-stable_win64.exe" (
  start "" ".tools\godot\Godot_v4.6-stable_win64.exe" --path "%~dp0godot"
  exit /b 0
)
if defined GODOT_PATH (
  start "" "%GODOT_PATH%" --path "%~dp0godot"
  exit /b 0
)
where godot >nul 2>nul
if not errorlevel 1 (
  start "" godot --path "%~dp0godot"
  exit /b 0
)
echo 请用 Godot 4.6 或更新版本打开 godot\project.godot，然后按 F6 或 F5。
echo 也可以设置 GODOT_PATH 为 Godot 可执行文件的完整路径。
pause
