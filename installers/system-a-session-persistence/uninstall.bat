@echo off
REM =====================================================
REM Enhanced Claude - System A: Uninstaller
REM Session Persistence & Searchable History
REM Windows Version
REM =====================================================

setlocal EnableDelayedExpansion

echo ==============================================
echo   Enhanced Claude - System A Uninstaller
echo   Session Persistence ^& Searchable History
echo ==============================================
echo.

set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "HOOKS_DIR=%CLAUDE_DIR%\hooks"
set "SKILLS_DIR=%CLAUDE_DIR%\skills"
set "SETTINGS_FILE=%CLAUDE_DIR%\settings.json"

echo Removing System A hooks...

REM Remove hooks
if exist "%HOOKS_DIR%\session-recovery.py" (
    del "%HOOKS_DIR%\session-recovery.py"
    echo   Removed: session-recovery.py
)
if exist "%HOOKS_DIR%\live-session-indexer.py" (
    del "%HOOKS_DIR%\live-session-indexer.py"
    echo   Removed: live-session-indexer.py
)
if exist "%HOOKS_DIR%\history-indexer.py" (
    del "%HOOKS_DIR%\history-indexer.py"
    echo   Removed: history-indexer.py
)
if exist "%HOOKS_DIR%\history-search.py" (
    del "%HOOKS_DIR%\history-search.py"
    echo   Removed: history-search.py
)

echo Removing System A skill...

REM Remove history skill
if exist "%SKILLS_DIR%\history" (
    rmdir /s /q "%SKILLS_DIR%\history"
    echo   Removed: history skill
)

echo Updating settings.json...

REM Use PowerShell to update settings
powershell -ExecutionPolicy Bypass -Command ^"^
$sf = '%SETTINGS_FILE%'; ^
if (Test-Path $sf) { ^
    $settings = Get-Content $sf -Raw | ConvertFrom-Json; ^
    if ($settings.hooks) { ^
        $scripts = @('history-search.py','history-indexer.py','live-session-indexer.py','session-recovery.py'); ^
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

echo.
echo ==============================================
echo   Uninstallation Complete!
echo ==============================================
echo.
echo Removed components:
echo   - 4 hooks
echo   - 1 skill (history)
echo.
echo Preserved:
echo   - Session data in ~/.claude/sessions/
echo   - History index in ~/.claude/history/
echo   - hook_logger.py (may be used by other systems)
echo.
echo Restart Claude Code or run /hooks to reload hooks.
echo.

endlocal
