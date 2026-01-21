@echo off
REM =====================================================
REM Enhanced Claude - System B: RLM Detection & Processing
REM Windows Installer
REM =====================================================

setlocal EnableDelayedExpansion

echo ==============================================
echo   Enhanced Claude - System B Installer
echo   RLM Detection ^& Processing
echo ==============================================
echo.

set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "HOOKS_DIR=%CLAUDE_DIR%\hooks"
set "LOGS_DIR=%HOOKS_DIR%\logs"
set "SKILLS_DIR=%CLAUDE_DIR%\skills"
set "PROJECT_DIR=%CD%"
set "RLM_TOOLS_DIR=%PROJECT_DIR%\rlm_tools"
set "RLM_CONTEXT_DIR=%PROJECT_DIR%\rlm_context"
set "SETTINGS_FILE=%CLAUDE_DIR%\settings.json"

for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "BACKUP_DIR=%CLAUDE_DIR%\backups\system-b-%dt:~0,8%_%dt:~8,6%"

echo Creating directories...
if not exist "%HOOKS_DIR%" mkdir "%HOOKS_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if not exist "%SKILLS_DIR%\rlm" mkdir "%SKILLS_DIR%\rlm"
if not exist "%RLM_TOOLS_DIR%" mkdir "%RLM_TOOLS_DIR%"
if not exist "%RLM_CONTEXT_DIR%\chunks" mkdir "%RLM_CONTEXT_DIR%\chunks"
if not exist "%RLM_CONTEXT_DIR%\results" mkdir "%RLM_CONTEXT_DIR%\results"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

if exist "%SETTINGS_FILE%" (
    echo Backing up existing settings...
    copy "%SETTINGS_FILE%" "%BACKUP_DIR%\settings.json.backup" >nul
)

echo Installing hooks and RLM tools via PowerShell...

powershell -ExecutionPolicy Bypass -Command ^"^
$hooksDir = '%HOOKS_DIR%'; ^
$skillsDir = '%SKILLS_DIR%'; ^
$rlmToolsDir = '%RLM_TOOLS_DIR%'; ^
$settingsFile = '%SETTINGS_FILE%'; ^
^
# Create hook_logger.py if not exists ^
if (-not (Test-Path (Join-Path $hooksDir 'hook_logger.py'))) { ^
    $hookLogger = @' ^
import os, json, traceback ^
from datetime import datetime ^
from pathlib import Path ^
LOG_DIR = Path(os.path.expanduser('~/.claude/hooks/logs')) ^
class HookLogger: ^
    def __init__(self, hook_name): ^
        self.hook_name = hook_name ^
        self.log_dir = LOG_DIR ^
        self.log_dir.mkdir(parents=True, exist_ok=True) ^
        self.log_file = self.log_dir / f'{hook_name}.log' ^
    def _write(self, level, message, **kwargs): ^
        entry = {'timestamp': datetime.now().isoformat(), 'level': level, 'hook': self.hook_name, 'message': message} ^
        try: ^
            with open(self.log_file, 'a') as f: f.write(json.dumps(entry) + '\n') ^
        except: pass ^
    def debug(self, msg, **kwargs): self._write('DEBUG', msg, **kwargs) ^
    def info(self, msg, **kwargs): self._write('INFO', msg, **kwargs) ^
    def error(self, msg, **kwargs): self._write('ERROR', msg, **kwargs) ^
    def log_input(self, hi): self.debug('Input', data={'len': len(hi.get('prompt',''))}) ^
    def log_output(self, o): self.debug('Output', data=o) ^
'@ ^
    $hookLogger | Out-File -FilePath (Join-Path $hooksDir 'hook_logger.py') -Encoding utf8 ^
    Write-Host '  Created: hook_logger.py' ^
} ^
^
# Create large-input-detector.py ^
$detector = @' ^
import json, sys, os ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('large-input-detector') ^
SUGGEST=50000 ^
STRONG=150000 ^
def main(): ^
    logger.info('Hook started') ^
    try: hi = json.load(sys.stdin) ^
    except: sys.exit(0) ^
    prompt = hi.get('prompt','') ^
    if not prompt: sys.exit(0) ^
    cc, tc = len(prompt), len(prompt)//4 ^
    if cc >= STRONG: ^
        msg = f'[LARGE INPUT - RLM RECOMMENDED]\\nInput: {cc:,} chars (~{tc:,} tokens)\\n\\nUse RLM workflow:\\n1. python rlm_tools/probe.py input.txt\\n2. python rlm_tools/chunk.py input.txt --output rlm_context/chunks/\\n3. Process with subagents\\n4. python rlm_tools/aggregate.py rlm_context/results/' ^
    elif cc >= SUGGEST: ^
        msg = f'[LARGE INPUT NOTICE]\\nInput: {cc:,} chars (~{tc:,} tokens)\\nConsider RLM workflow for comprehensive analysis.' ^
    else: sys.exit(0) ^
    print(json.dumps({'hookSpecificOutput':{'additionalContext':msg}}), flush=True) ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$detector | Out-File -FilePath (Join-Path $hooksDir 'large-input-detector.py') -Encoding utf8 ^
Write-Host '  Created: large-input-detector.py' ^
^
# Create RLM tools (simplified versions) ^
$probe = @' ^
import argparse, json, sys ^
from pathlib import Path ^
def main(): ^
    parser = argparse.ArgumentParser() ^
    parser.add_argument('input_file') ^
    parser.add_argument('--json', action='store_true') ^
    args = parser.parse_args() ^
    try: ^
        with open(args.input_file, 'r', encoding='utf-8', errors='ignore') as f: text = f.read() ^
    except Exception as e: print(f'Error: {e}'); sys.exit(1) ^
    result = {'file': args.input_file, 'char_count': len(text), 'line_count': len(text.split('\\n')), 'token_estimate': len(text)//4, 'recommended_chunks': max(1, len(text)//200000)} ^
    if args.json: print(json.dumps(result, indent=2)) ^
    else: ^
        print(f'File: {result[\"file\"]}') ^
        print(f'Characters: {result[\"char_count\"]:,}') ^
        print(f'Lines: {result[\"line_count\"]:,}') ^
        print(f'Est. Tokens: {result[\"token_estimate\"]:,}') ^
        print(f'Recommended Chunks: {result[\"recommended_chunks\"]}') ^
if __name__ == '__main__': main() ^
'@ ^
$probe | Out-File -FilePath (Join-Path $rlmToolsDir 'probe.py') -Encoding utf8 ^
Write-Host '  Created: rlm_tools/probe.py' ^
^
$chunk = @' ^
import argparse, json, sys, os ^
from pathlib import Path ^
def main(): ^
    parser = argparse.ArgumentParser() ^
    parser.add_argument('input_file') ^
    parser.add_argument('--size', type=int, default=200000) ^
    parser.add_argument('--overlap', type=int, default=500) ^
    parser.add_argument('--output', '-o', default='rlm_context/chunks') ^
    args = parser.parse_args() ^
    with open(args.input_file, 'r', encoding='utf-8', errors='ignore') as f: text = f.read() ^
    os.makedirs(args.output, exist_ok=True) ^
    chunks, start, num = [], 0, 1 ^
    while start < len(text): ^
        end = min(start + args.size, len(text)) ^
        if end < len(text): ^
            nl = text.rfind('\\n', start + args.size - 1000, end + 100) ^
            if nl > start: end = nl + 1 ^
        chunk_text = text[start:end] ^
        filename = f'chunk_{num:03d}.txt' ^
        with open(os.path.join(args.output, filename), 'w', encoding='utf-8') as f: f.write(chunk_text) ^
        chunks.append({'filename': filename, 'char_count': len(chunk_text), 'chunk_num': num}) ^
        start = end - args.overlap if end < len(text) else end ^
        num += 1 ^
    manifest = {'total_chunks': len(chunks), 'chunks': chunks} ^
    with open(os.path.join(args.output, 'manifest.json'), 'w') as f: json.dump(manifest, f, indent=2) ^
    print(f'Created {len(chunks)} chunks in {args.output}/') ^
if __name__ == '__main__': main() ^
'@ ^
$chunk | Out-File -FilePath (Join-Path $rlmToolsDir 'chunk.py') -Encoding utf8 ^
Write-Host '  Created: rlm_tools/chunk.py' ^
^
$aggregate = @' ^
import argparse, json, sys ^
from glob import glob ^
from pathlib import Path ^
def main(): ^
    parser = argparse.ArgumentParser() ^
    parser.add_argument('results_dir') ^
    parser.add_argument('--pattern', default='*.txt') ^
    parser.add_argument('--query', '-q') ^
    args = parser.parse_args() ^
    files = sorted(glob(str(Path(args.results_dir) / args.pattern))) ^
    if not files: print('No files found'); sys.exit(1) ^
    output = [f'# Aggregated Results ({len(files)} files)\\n'] ^
    for f in files: ^
        with open(f, 'r', encoding='utf-8', errors='ignore') as fp: content = fp.read() ^
        output.append(f'## {Path(f).name}\\n{content[:5000]}\\n') ^
    print('\\n'.join(output)) ^
if __name__ == '__main__': main() ^
'@ ^
$aggregate | Out-File -FilePath (Join-Path $rlmToolsDir 'aggregate.py') -Encoding utf8 ^
Write-Host '  Created: rlm_tools/aggregate.py' ^
^
# Create RLM skill ^
$skillMd = @' ^
# RLM: Reading Language Model ^
^
Process documents larger than ~50K characters. ^
^
## Quick Start ^
^
1. python rlm_tools/probe.py input.txt ^
2. python rlm_tools/chunk.py input.txt --output rlm_context/chunks/ ^
3. Process chunks with Task subagents ^
4. python rlm_tools/aggregate.py rlm_context/results/ ^
^
## Auto-Detection ^
^
The large-input-detector hook suggests RLM for inputs >50K chars. ^
'@ ^
$skillMd | Out-File -FilePath (Join-Path $skillsDir 'rlm\SKILL.md') -Encoding utf8 ^
Write-Host '  Created: rlm/SKILL.md' ^
^
$skillMeta = '{\"name\":\"rlm\",\"tags\":[\"rlm\",\"large-documents\",\"chunking\"],\"useCount\":0}' ^
$skillMeta | Out-File -FilePath (Join-Path $skillsDir 'rlm\metadata.json') -Encoding utf8 ^
^
# Update settings.json ^
$settings = @{} ^
if (Test-Path $settingsFile) { try { $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable } catch {} } ^
if (-not $settings.hooks) { $settings.hooks = @{} } ^
$hd = $hooksDir.Replace('\', '/') ^
if (-not $settings.hooks['UserPromptSubmit']) { $settings.hooks['UserPromptSubmit'] = @() } ^
$settings.hooks['UserPromptSubmit'] += @{hooks=@(@{type='command';command=\"python3 $hd/large-input-detector.py\"})} ^
$settings | ConvertTo-Json -Depth 10 | Out-File $settingsFile -Encoding utf8 ^
Write-Host '  Settings updated' ^
^"

echo.
echo ==============================================
echo   Installation Complete!
echo ==============================================
echo.
echo Installed:
echo   - 2 hooks (large-input-detector, hook_logger)
echo   - 1 skill (rlm)
echo   - RLM tools in %RLM_TOOLS_DIR%
echo.
echo Restart Claude Code or run /hooks to reload.
echo.

endlocal
