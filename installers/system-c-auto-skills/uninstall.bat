@echo off
REM =====================================================
REM Enhanced Claude - System C: Uninstaller
REM Auto Skills & Skills Library
REM Windows Version
REM =====================================================

setlocal EnableDelayedExpansion

echo ==============================================
echo   Enhanced Claude - System C Uninstaller
echo   Auto Skills ^& Skills Library
echo ==============================================
echo.

set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "HOOKS_DIR=%CLAUDE_DIR%\hooks"
set "SKILLS_DIR=%CLAUDE_DIR%\skills"
set "SETTINGS_FILE=%CLAUDE_DIR%\settings.json"

echo Removing System C hooks...

REM Remove hooks
if exist "%HOOKS_DIR%\skill-matcher.py" (
    del "%HOOKS_DIR%\skill-matcher.py"
    echo   Removed: skill-matcher.py
)
if exist "%HOOKS_DIR%\skill-tracker.py" (
    del "%HOOKS_DIR%\skill-tracker.py"
    echo   Removed: skill-tracker.py
)
if exist "%HOOKS_DIR%\detect-learning.py" (
    del "%HOOKS_DIR%\detect-learning.py"
    echo   Removed: detect-learning.py
)
if exist "%HOOKS_DIR%\learning-moment-pickup.py" (
    del "%HOOKS_DIR%\learning-moment-pickup.py"
    echo   Removed: learning-moment-pickup.py
)

echo Removing System C skills...

REM Remove all skills
for %%s in (skill-index skill-creator skill-updater skill-loader skill-health skill-improver skill-tracker skill-validator skill-matcher web-research llm-api-tool-use deno2-http-kv-server hono-bun-sqlite-api udcp markdown-to-pdf history rlm hook-development) do (
    if exist "%SKILLS_DIR%\%%s" (
        rmdir /s /q "%SKILLS_DIR%\%%s"
        echo   Removed: %%s
    )
)

echo Updating settings.json...

REM Use PowerShell to update settings
powershell -ExecutionPolicy Bypass -Command ^"^
$sf = '%SETTINGS_FILE%'; ^
if (Test-Path $sf) { ^
    $settings = Get-Content $sf -Raw | ConvertFrom-Json; ^
    if ($settings.hooks) { ^
        $scripts = @('skill-matcher.py','skill-tracker.py','detect-learning.py','learning-moment-pickup.py'); ^
        foreach ($event in @($settings.hooks.PSObject.Properties.Name)) { ^
            $filtered = @(); ^
            foreach ($hg in $settings.hooks.$event) { ^
                $newHooks = @(); ^
                foreach ($h in $hg.hooks) { ^
                    $remove = $false; ^
                    foreach ($s in $scripts) { if ($h.command -like \"*$s*\") { $remove = $true } } ^
                    if (-not $remove) { $newHooks += $h } ^
                } ^
                if ($newHooks.Count -gt 0) { $hg.hooks = $newHooks; $filtered += $hg } ^
            } ^
            if ($filtered.Count -gt 0) { $settings.hooks.$event = $filtered } ^
            else { $settings.hooks.PSObject.Properties.Remove($event) } ^
        } ^
        $settings | ConvertTo-Json -Depth 10 | Out-File $sf -Encoding utf8; ^
        Write-Host '  Settings updated'; ^
    } ^
} ^
^"

REM Remove pending learning moment file
if exist "%CLAUDE_DIR%\pending-learning-moment.json" (
    del "%CLAUDE_DIR%\pending-learning-moment.json"
    echo   Removed: pending-learning-moment.json
)

echo.
echo ==============================================
echo   Uninstallation Complete!
echo ==============================================
echo.
echo Removed components:
echo   - 4 hooks
echo   - 18 skills
echo.
echo Preserved:
echo   - hook_logger.py (may be used by other systems)
echo.
echo Restart Claude Code or run /hooks to reload hooks.
echo.

endlocal
