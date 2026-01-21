@echo off
REM =====================================================
REM Enhanced Claude - System C: Auto Skills & Skills Library
REM Windows Installer
REM =====================================================

setlocal EnableDelayedExpansion

echo ==============================================
echo   Enhanced Claude - System C Installer
echo   Auto Skills ^& Skills Library
echo ==============================================
echo.

set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "HOOKS_DIR=%CLAUDE_DIR%\hooks"
set "LOGS_DIR=%HOOKS_DIR%\logs"
set "SKILLS_DIR=%CLAUDE_DIR%\skills"
set "SETTINGS_FILE=%CLAUDE_DIR%\settings.json"

for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "BACKUP_DIR=%CLAUDE_DIR%\backups\system-c-%dt:~0,8%_%dt:~8,6%"

echo Creating directories...
if not exist "%HOOKS_DIR%" mkdir "%HOOKS_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if not exist "%SKILLS_DIR%" mkdir "%SKILLS_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

if exist "%SETTINGS_FILE%" (
    echo Backing up existing settings...
    copy "%SETTINGS_FILE%" "%BACKUP_DIR%\settings.json.backup" >nul
)

echo Installing hooks and skills via PowerShell...

powershell -ExecutionPolicy Bypass -Command ^"^
$hooksDir = '%HOOKS_DIR%'; ^
$skillsDir = '%SKILLS_DIR%'; ^
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
            with open(self.log_file, 'a') as f: f.write(json.dumps(entry) + '\\n') ^
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
# Create skill-matcher.py ^
$matcher = @' ^
import json, sys, os ^
from datetime import datetime, timedelta ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('skill-matcher') ^
INDEX = os.path.expanduser('~/.claude/skills/skill-index/index.json') ^
def load_index(): ^
    try: ^
        with open(INDEX) as f: return json.load(f) ^
    except: return {'skills': []} ^
def score(skill, pl, pw): ^
    s = 0 ^
    for t in [x.lower() for x in skill.get('tags', [])]: ^
        if t in pl: s += 3 ^
        for tw in t.split('-'): ^
            if tw in pw and len(tw) > 2: s += 2 ^
    if skill.get('category', '').lower() in pl: s += 5 ^
    sw = set(skill.get('summary', '').lower().split()) ^
    s += len((pw & sw) - {'a','an','the','with','and','or','for','to','in','on','by','is','are'}) * 2 ^
    for p in skill.get('name', '').lower().replace('-',' ').split(): ^
        if p in pw and len(p) > 2: s += 3 ^
    return s ^
def main(): ^
    logger.info('Started') ^
    try: hi = json.load(sys.stdin) ^
    except: sys.exit(0) ^
    prompt = hi.get('prompt', '') ^
    if not prompt: sys.exit(0) ^
    pl, pw = prompt.lower(), set(prompt.lower().replace('-',' ').replace('_',' ').split()) ^
    idx = load_index() ^
    scored = [(score(sk, pl, pw), sk) for sk in idx.get('skills', []) if score(sk, pl, pw) >= 10] ^
    scored.sort(key=lambda x: x[0], reverse=True) ^
    if scored: ^
        lines = ['[SKILL MATCH] Relevant skills detected:'] ^
        for sc, sk in scored[:3]: ^
            lines.append(f\"  - {sk.get('name')} (score:{sc}): {sk.get('summary', '')}\") ^
            lines.append(f\"    Load: cat ~/.claude/skills/{sk.get('name')}/SKILL.md\") ^
        print(json.dumps({'hookSpecificOutput': {'additionalContext': '\\n'.join(lines)}}), flush=True) ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$matcher | Out-File -FilePath (Join-Path $hooksDir 'skill-matcher.py') -Encoding utf8 ^
Write-Host '  Created: skill-matcher.py' ^
^
# Create skill-tracker.py ^
$tracker = @' ^
import json, sys, os, re ^
from datetime import datetime ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('skill-tracker') ^
SKILLS = os.path.expanduser('~/.claude/skills') ^
def main(): ^
    logger.info('Started') ^
    try: hi = json.load(sys.stdin) ^
    except: sys.exit(0) ^
    if hi.get('tool_name') != 'Read': sys.exit(0) ^
    fp = hi.get('tool_input', {}).get('file_path', '') ^
    m = re.search(r'skills/([^/]+)/SKILL\\.md$', fp) ^
    if m and m.group(1) != 'skill-index': ^
        name = m.group(1) ^
        mp = os.path.join(SKILLS, name, 'metadata.json') ^
        md = {} ^
        if os.path.exists(mp): ^
            try: ^
                with open(mp) as f: md = json.load(f) ^
            except: pass ^
        md['useCount'] = md.get('useCount', 0) + 1 ^
        md['lastUsed'] = datetime.now().strftime('%Y-%m-%d') ^
        try: ^
            with open(mp, 'w') as f: json.dump(md, f, indent=2) ^
            logger.info(f'Updated {name}') ^
        except: pass ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$tracker | Out-File -FilePath (Join-Path $hooksDir 'skill-tracker.py') -Encoding utf8 ^
Write-Host '  Created: skill-tracker.py' ^
^
# Create detect-learning.py ^
$detect = @' ^
import json, sys, os, re ^
from datetime import datetime ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('detect-learning') ^
def main(): ^
    logger.info('Started') ^
    try: hi = json.load(sys.stdin) ^
    except: print('{\"continue\": true}'); sys.exit(0) ^
    tp = hi.get('transcript_path', '') ^
    if not tp or not os.path.exists(tp): print('{\"continue\": true}'); sys.exit(0) ^
    msgs = [] ^
    try: ^
        with open(tp) as f: ^
            for l in f: ^
                if l.strip(): ^
                    try: msgs.append(json.loads(l)) ^
                    except: pass ^
    except: pass ^
    if len(msgs) < 5: print('{\"continue\": true}'); sys.exit(0) ^
    errors, success = 0, 0 ^
    for m in msgs[-30:]: ^
        c = str(m) ^
        if any(re.search(p, c) for p in ['error:', 'Error:', 'failed', 'Failed', 'exception']): errors += 1 ^
        elif any(re.search(p, c, re.I) for p in ['worked', 'success', 'fixed']): success += 1 ^
    if errors >= 3 and success >= 1: ^
        pf = os.path.expanduser('~/.claude/pending-learning-moment.json') ^
        with open(pf, 'w') as f: json.dump({'detected_at': datetime.now().isoformat(), 'reason': f'{errors} failures then success'}, f) ^
    print('{\"continue\": true}'); sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$detect | Out-File -FilePath (Join-Path $hooksDir 'detect-learning.py') -Encoding utf8 ^
Write-Host '  Created: detect-learning.py' ^
^
# Create learning-moment-pickup.py ^
$pickup = @' ^
import json, sys, os ^
from datetime import datetime ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('learning-moment-pickup') ^
PF = os.path.expanduser('~/.claude/pending-learning-moment.json') ^
def main(): ^
    if not os.path.exists(PF): sys.exit(0) ^
    try: ^
        with open(PF) as f: m = json.load(f) ^
        age = (datetime.now() - datetime.fromisoformat(m['detected_at'])).total_seconds() / 3600 ^
        if age > 24: os.remove(PF); sys.exit(0) ^
        os.remove(PF) ^
        out = {'hookSpecificOutput': {'additionalContext': f\"[LEARNING MOMENT]\\n{m['reason']}\\nConsider saving as a skill (/skill-creator) or noting in insights.md.\"}} ^
        print(json.dumps(out), flush=True) ^
    except: ^
        if os.path.exists(PF): os.remove(PF) ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$pickup | Out-File -FilePath (Join-Path $hooksDir 'learning-moment-pickup.py') -Encoding utf8 ^
Write-Host '  Created: learning-moment-pickup.py' ^
^
# Create skills ^
$skillsData = @{ ^
    'skill-index' = @{summary='Index and discover skills';tags=@('discovery','search','index');category='meta'} ^
    'skill-creator' = @{summary='Auto-detect learning moments, create skills';tags=@('learning','skills','automation');category='meta'} ^
    'skill-updater' = @{summary='Update skills when they fail';tags=@('learning','maintenance');category='meta'} ^
    'skill-loader' = @{summary='Lazy-load skills efficiently';tags=@('loading','context','efficiency');category='meta'} ^
    'skill-health' = @{summary='Track skill usage and quality';tags=@('tracking','quality','analytics');category='meta'} ^
    'skill-improver' = @{summary='Suggest skill improvements';tags=@('improvement','proactive');category='meta'} ^
    'skill-tracker' = @{summary='Track skill usage metrics';tags=@('tracking','metrics','automation');category='meta'} ^
    'skill-validator' = @{summary='Validate skills still work';tags=@('validation','testing');category='meta'} ^
    'skill-matcher' = @{summary='Smart skill discovery';tags=@('discovery','matching','search');category='meta'} ^
    'web-research' = @{summary='Fallback research when stuck';tags=@('research','web','fallback');category='meta'} ^
    'llm-api-tool-use' = @{summary='Claude API tool use';tags=@('anthropic','llm','tool-use','python');category='api'} ^
    'deno2-http-kv-server' = @{summary='Deno 2 HTTP server with KV';tags=@('deno','http','kv','typescript');category='setup'} ^
    'hono-bun-sqlite-api' = @{summary='REST API with Hono, Bun, SQLite';tags=@('hono','bun','sqlite','api');category='setup'} ^
    'udcp' = @{summary='Update docs, commit, push';tags=@('git','commit','workflow');category='meta'} ^
    'markdown-to-pdf' = @{summary='Convert Markdown to PDF';tags=@('markdown','pdf','documentation');category='setup'} ^
    'history' = @{summary='Search past conversation history';tags=@('history','search','memory');category='utility'} ^
    'rlm' = @{summary='Process large documents with chunking';tags=@('rlm','large-documents','chunking');category='processing'} ^
    'hook-development' = @{summary='Develop Claude Code hooks';tags=@('hooks','automation','claude-code');category='development'} ^
} ^
^
foreach ($name in $skillsData.Keys) { ^
    $sd = Join-Path $skillsDir $name ^
    New-Item -ItemType Directory -Force -Path $sd | Out-Null ^
    $info = $skillsData[$name] ^
    $skillMd = \"---`nname: $name`ndescription: $($info.summary)`n---`n`n# $name`n`n$($info.summary)\" ^
    $skillMd | Out-File -FilePath (Join-Path $sd 'SKILL.md') -Encoding utf8 ^
    $meta = @{name=$name;category=$info.category;tags=$info.tags;useCount=0;successCount=0;failureCount=0;lastUsed=$null} ^
    $meta | ConvertTo-Json | Out-File -FilePath (Join-Path $sd 'metadata.json') -Encoding utf8 ^
} ^
Write-Host '  Created 18 skills' ^
^
# Create index.json ^
$indexSkills = @() ^
foreach ($name in $skillsData.Keys) { ^
    $info = $skillsData[$name] ^
    $indexSkills += @{name=$name;category=$info.category;tags=$info.tags;summary=$info.summary;dependencies=@();lastUsed=$null;useCount=0} ^
} ^
$index = @{skills=$indexSkills;lastUpdated=(Get-Date -Format 'yyyy-MM-dd');categories=@('meta','setup','api','utility','processing','development')} ^
$index | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $skillsDir 'skill-index\\index.json') -Encoding utf8 ^
^
# Update settings.json ^
$settings = @{} ^
if (Test-Path $settingsFile) { try { $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable } catch {} } ^
if (-not $settings.hooks) { $settings.hooks = @{} } ^
$hd = $hooksDir.Replace('\\', '/') ^
if (-not $settings.hooks['UserPromptSubmit']) { $settings.hooks['UserPromptSubmit'] = @() } ^
$settings.hooks['UserPromptSubmit'] += @{hooks=@(@{type='command';command=\"python3 $hd/skill-matcher.py\"},@{type='command';command=\"python3 $hd/learning-moment-pickup.py\"})} ^
if (-not $settings.hooks['PostToolUse']) { $settings.hooks['PostToolUse'] = @() } ^
$settings.hooks['PostToolUse'] += @{matcher='Read';hooks=@(@{type='command';command=\"python3 $hd/skill-tracker.py\"})} ^
if (-not $settings.hooks['Stop']) { $settings.hooks['Stop'] = @() } ^
$settings.hooks['Stop'] += @{hooks=@(@{type='command';command=\"python3 $hd/detect-learning.py\"})} ^
$settings | ConvertTo-Json -Depth 10 | Out-File $settingsFile -Encoding utf8 ^
Write-Host '  Settings updated' ^
^"

echo.
echo ==============================================
echo   Installation Complete!
echo ==============================================
echo.
echo Installed:
echo   - 5 hooks (skill-matcher, skill-tracker, detect-learning,
echo              learning-moment-pickup, hook_logger)
echo   - 18 skills
echo.
echo Restart Claude Code or run /hooks to reload.
echo.

endlocal
