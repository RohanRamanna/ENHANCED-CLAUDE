@echo off
REM Enhanced Claude - System B: Uninstaller
setlocal EnableDelayedExpansion

echo ==============================================
echo   Enhanced Claude - System B Uninstaller
echo   RLM Detection ^& Processing
echo ==============================================
echo.

set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "HOOKS_DIR=%CLAUDE_DIR%\hooks"
set "SKILLS_DIR=%CLAUDE_DIR%\skills"
set "SETTINGS_FILE=%CLAUDE_DIR%\settings.json"

echo Removing System B hooks...
if exist "%HOOKS_DIR%\large-input-detector.py" (
    del "%HOOKS_DIR%\large-input-detector.py"
    echo   Removed: large-input-detector.py
)

echo Removing System B skill...
if exist "%SKILLS_DIR%\rlm" (
    rmdir /s /q "%SKILLS_DIR%\rlm"
    echo   Removed: rlm skill
)

echo Updating settings.json...
powershell -ExecutionPolicy Bypass -Command ^"^
$sf = '%SETTINGS_FILE%'; ^
if (Test-Path $sf) { ^
    $settings = Get-Content $sf -Raw | ConvertFrom-Json; ^
    if ($settings.hooks) { ^
        foreach ($event in @($settings.hooks.PSObject.Properties.Name)) { ^
            $filtered = @(); ^
            foreach ($hg in $settings.hooks.$event) { ^
                $newHooks = @(); ^
                foreach ($h in $hg.hooks) { ^
                    if ($h.command -notlike '*large-input-detector.py*') { $newHooks += $h } ^
                } ^
                if ($newHooks.Count -gt 0) { $hg.hooks = $newHooks; $filtered += $hg } ^
            } ^
            if ($filtered.Count -gt 0) { $settings.hooks.$event = $filtered } ^
            else { $settings.hooks.PSObject.Properties.Remove($event) } ^
        } ^
        $settings | ConvertTo-Json -Depth 10 | Out-File $sf -Encoding utf8 ^
    } ^
} ^
^"

echo.
echo ==============================================
echo   Uninstallation Complete!
echo ==============================================
echo.
echo Note: RLM tools in rlm_tools/ directory were preserved.
echo.

endlocal
