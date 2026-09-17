@echo off
chcp 65001 >nul
cd /d "%~dp0"
if exist ".tools\godot\Godot_v4.6-stable_win64.exe" (
  start "" ".tools\godot\Godot_v4.6-stable_win64.exe" --editor --path "%~dp0godot"
) else (
  echo 使用 Godot 4.6 打开 godot\project.godot。
  pause
)
