@echo off
REM =====================================================
REM Enhanced Claude - System A: Session Persistence & Searchable History
REM Windows Installer
REM
REM This installer sets up:
REM - Session recovery after context compaction (RLM-based)
REM - Live session indexing for intelligent recovery
REM - Searchable conversation history
REM - History search suggestions
REM
REM Usage: install.bat
REM =====================================================

setlocal EnableDelayedExpansion

echo ==============================================
echo   Enhanced Claude - System A Installer
echo   Session Persistence ^& Searchable History
echo ==============================================
echo.

REM Set paths
set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "HOOKS_DIR=%CLAUDE_DIR%\hooks"
set "LOGS_DIR=%HOOKS_DIR%\logs"
set "SKILLS_DIR=%CLAUDE_DIR%\skills"
set "SESSIONS_DIR=%CLAUDE_DIR%\sessions"
set "HISTORY_DIR=%CLAUDE_DIR%\history"
set "SETTINGS_FILE=%CLAUDE_DIR%\settings.json"

REM Create timestamp for backup
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "BACKUP_DIR=%CLAUDE_DIR%\backups\system-a-%dt:~0,8%_%dt:~8,6%"

echo Creating directories...
if not exist "%HOOKS_DIR%" mkdir "%HOOKS_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if not exist "%SKILLS_DIR%\history" mkdir "%SKILLS_DIR%\history"
if not exist "%SESSIONS_DIR%" mkdir "%SESSIONS_DIR%"
if not exist "%HISTORY_DIR%" mkdir "%HISTORY_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

REM Backup existing settings
if exist "%SETTINGS_FILE%" (
    echo Backing up existing settings...
    copy "%SETTINGS_FILE%" "%BACKUP_DIR%\settings.json.backup" >nul
)

echo Installing hooks via PowerShell...

REM Use PowerShell to create the hook files (handles multiline content better)
powershell -ExecutionPolicy Bypass -Command ^"^
$hooksDir = '%HOOKS_DIR%'; ^
$skillsDir = '%SKILLS_DIR%'; ^
$settingsFile = '%SETTINGS_FILE%'; ^
^
# Create hook_logger.py ^
$hookLogger = @' ^
#!/usr/bin/env python3 ^
import os ^
import json ^
import traceback ^
from datetime import datetime ^
from pathlib import Path ^
^
LOG_DIR = Path(os.path.expanduser('~/.claude/hooks/logs')) ^
MAX_LOG_SIZE = 1_000_000 ^
MAX_LOG_FILES = 3 ^
^
class HookLogger: ^
    def __init__(self, hook_name): ^
        self.hook_name = hook_name ^
        self.log_dir = LOG_DIR ^
        self.log_dir.mkdir(parents=True, exist_ok=True) ^
        self.log_file = self.log_dir / f'{hook_name}.log' ^
        self._rotate_if_needed() ^
^
    def _rotate_if_needed(self): ^
        if self.log_file.exists() and self.log_file.stat().st_size > MAX_LOG_SIZE: ^
            for i in range(MAX_LOG_FILES - 1, 0, -1): ^
                old_file = self.log_dir / f'{self.hook_name}.{i}.log' ^
                new_file = self.log_dir / f'{self.hook_name}.{i + 1}.log' ^
                if old_file.exists(): ^
                    if i + 1 >= MAX_LOG_FILES: ^
                        old_file.unlink() ^
                    else: ^
                        old_file.rename(new_file) ^
            backup = self.log_dir / f'{self.hook_name}.1.log' ^
            self.log_file.rename(backup) ^
^
    def _write(self, level, message, **kwargs): ^
        timestamp = datetime.now().isoformat() ^
        entry = {'timestamp': timestamp, 'level': level, 'hook': self.hook_name, 'message': message} ^
        if kwargs.get('exc_info'): ^
            entry['traceback'] = traceback.format_exc() ^
        if kwargs.get('data'): ^
            entry['data'] = kwargs['data'] ^
        try: ^
            with open(self.log_file, 'a') as f: ^
                f.write(json.dumps(entry) + '\n') ^
        except: ^
            pass ^
^
    def debug(self, msg, **kwargs): self._write('DEBUG', msg, **kwargs) ^
    def info(self, msg, **kwargs): self._write('INFO', msg, **kwargs) ^
    def warning(self, msg, **kwargs): self._write('WARNING', msg, **kwargs) ^
    def error(self, msg, **kwargs): self._write('ERROR', msg, **kwargs) ^
    def log_input(self, hook_input): ^
        sanitized = {'prompt_length': len(hook_input.get('prompt', '')), 'prompt_preview': hook_input.get('prompt', '')[:100], 'cwd': hook_input.get('cwd', ''), 'has_transcript': bool(hook_input.get('transcript_path'))} ^
        self.debug('Hook input received', data=sanitized) ^
    def log_output(self, output): ^
        self.debug('Hook output', data=output) ^
'@ ^
$hookLogger | Out-File -FilePath (Join-Path $hooksDir 'hook_logger.py') -Encoding utf8; ^
Write-Host '  Created: hook_logger.py'; ^
^
# Create history-search.py ^
$historySearch = @' ^
#!/usr/bin/env python3 ^
import json, sys, os ^
from datetime import datetime ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('history-search') ^
INDEX_PATH = os.path.expanduser('~/.claude/history/index.json') ^
MIN_SCORE = 8 ^
COMMON = {'a','an','the','with','and','or','for','to','in','on','by','is','are','was','were','be','been','have','has','had','do','does','did','will','would','could','should','may','might','this','that','these','those','it','its','i','me','my','you','your','we','our','they','them','their','what','which','who','how','when','where','why','can','help','want','need','please','make','create','add','use','using','get','set','new','file'} ^
def load_index(): ^
    try: ^
        with open(INDEX_PATH) as f: return json.load(f) ^
    except: return {'sessions': {}, 'topics': {}} ^
def norm_path(cwd): ^
    if not cwd: return None ^
    n = cwd.replace('/', '-').replace(' ', '-') ^
    return n if n.startswith('-') else '-' + n ^
def score_session(s, words): ^
    score, topics = 0, [] ^
    for t in s.get('topics', []): ^
        tl = t.lower() ^
        if tl in words: score += 4; topics.append(t) ^
        elif set(tl.replace('-',' ').split()) & words - COMMON: score += 2; topics.append(t) ^
    return score, topics[:5] ^
def main(): ^
    logger.info('Hook started') ^
    try: hook_input = json.load(sys.stdin) ^
    except: sys.exit(0) ^
    prompt, cwd = hook_input.get('prompt',''), hook_input.get('cwd','') ^
    if len(prompt) < 10: sys.exit(0) ^
    words = set(prompt.lower().replace('-',' ').split()) - COMMON ^
    if len(words) < 2: sys.exit(0) ^
    index = load_index() ^
    sessions = index.get('sessions', {}) ^
    if not sessions: sys.exit(0) ^
    proj = norm_path(cwd) ^
    scored = [] ^
    for sid, s in sessions.items(): ^
        if proj and s.get('project') != proj: continue ^
        sc, t = score_session(s, words) ^
        if sc >= MIN_SCORE: scored.append({'score':sc,'id':sid,'date':s.get('date','?'),'topics':t,'lines':s.get('line_count',0)}) ^
    scored.sort(key=lambda x: x['score'], reverse=True) ^
    if scored: ^
        lines = ['[HISTORY MATCH] Found relevant past work:'] ^
        for m in scored[:3]: ^
            lines.append(f\"  - {m['date']}: {', '.join(m['topics'][:3])} (score:{m['score']}, {m['lines']} lines)\") ^
            lines.append(f\"    Load: /history load {m['id'][:8]}\") ^
        print(json.dumps({'hookSpecificOutput':{'additionalContext':'\\n'.join(lines)}}), flush=True) ^
    logger.info('Hook completed') ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$historySearch | Out-File -FilePath (Join-Path $hooksDir 'history-search.py') -Encoding utf8; ^
Write-Host '  Created: history-search.py'; ^
^
# Create history-indexer.py (minimal version) ^
$historyIndexer = @' ^
#!/usr/bin/env python3 ^
import json, sys, os, re ^
from datetime import datetime ^
from pathlib import Path ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('history-indexer') ^
HISTORY_DIR = os.path.expanduser('~/.claude/history') ^
INDEX_PATH = os.path.join(HISTORY_DIR, 'index.json') ^
PROJECTS_DIR = os.path.expanduser('~/.claude/projects') ^
KEYWORDS = {'authentication','auth','database','sql','api','hooks','rlm','skills','testing','deployment','error','fix','debug','refactor'} ^
def ensure_dir(): os.makedirs(HISTORY_DIR, exist_ok=True) ^
def load_index(): ^
    try: ^
        with open(INDEX_PATH) as f: return json.load(f) ^
    except: return {'version':1,'sessions':{},'topics':{}} ^
def save_index(idx): ^
    ensure_dir() ^
    idx['last_indexed'] = datetime.now().isoformat() ^
    with open(INDEX_PATH,'w') as f: json.dump(idx, f, indent=2) ^
def find_sessions(): ^
    s = [] ^
    if not os.path.exists(PROJECTS_DIR): return s ^
    for p in Path(PROJECTS_DIR).iterdir(): ^
        if not p.is_dir() or p.name.startswith('.'): continue ^
        for j in p.glob('*.jsonl'): ^
            if 'subagents' in str(j): continue ^
            s.append({'path':str(j),'project':p.name,'session_id':j.stem}) ^
    return s ^
def extract_topics(c): ^
    t = set() ^
    cl = c.lower() ^
    for k in KEYWORDS: ^
        if k in cl: t.add(k) ^
    return t ^
def index_session(si): ^
    try: ^
        with open(si['path']) as f: lines = f.readlines() ^
    except: return None ^
    topics, date = set(), None ^
    for l in lines: ^
        try: ^
            m = json.loads(l.strip()) ^
            if not date and m.get('timestamp'): date = m['timestamp'].split('T')[0] ^
            if m.get('type') == 'user': ^
                c = m.get('message',{}).get('content','') ^
                if isinstance(c,str): topics.update(extract_topics(c)) ^
        except: pass ^
    return {'id':si['session_id'],'project':si['project'],'file':si['path'],'date':date or datetime.now().strftime('%Y-%m-%d'),'line_count':len(lines),'topics':list(topics)[:30]} ^
def main(): ^
    logger.info('Hook started') ^
    try: json.load(sys.stdin) ^
    except: pass ^
    idx = load_index() ^
    existing = set(idx.get('sessions',{}).keys()) ^
    new = 0 ^
    for si in find_sessions(): ^
        sid = si['session_id'] ^
        if sid in existing: continue ^
        entry = index_session(si) ^
        if entry: idx['sessions'][sid] = entry; new += 1 ^
    if new > 0: save_index(idx); logger.info(f'Indexed {new} new sessions') ^
    print('{\"continue\": true}') ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$historyIndexer | Out-File -FilePath (Join-Path $hooksDir 'history-indexer.py') -Encoding utf8; ^
Write-Host '  Created: history-indexer.py'; ^
^
# Create live-session-indexer.py (minimal version) ^
$liveIndexer = @' ^
#!/usr/bin/env python3 ^
import json, sys, os ^
from datetime import datetime ^
from pathlib import Path ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('live-session-indexer') ^
SESSIONS_DIR = os.path.expanduser('~/.claude/sessions') ^
PROJECTS_DIR = os.path.expanduser('~/.claude/projects') ^
def find_session(): ^
    if not os.path.exists(PROJECTS_DIR): return None ^
    best, bt = None, 0 ^
    for p in Path(PROJECTS_DIR).iterdir(): ^
        if not p.is_dir() or p.name.startswith('.'): continue ^
        for j in p.glob('*.jsonl'): ^
            if 'subagents' in str(j): continue ^
            mt = j.stat().st_mtime ^
            if mt > bt: bt = mt; best = {'path':str(j),'project':p.name,'session_id':j.stem} ^
    return best ^
def main(): ^
    logger.info('Hook started') ^
    try: json.load(sys.stdin) ^
    except: pass ^
    si = find_session() ^
    if not si: print('{\"continue\": true}'); sys.exit(0) ^
    sd = os.path.join(SESSIONS_DIR, si['session_id']) ^
    os.makedirs(sd, exist_ok=True) ^
    ip = os.path.join(sd, 'segments.json') ^
    try: ^
        with open(ip) as f: idx = json.load(f) ^
    except: idx = {'version':1,'session_id':si['session_id'],'segments':[],'last_indexed_line':0} ^
    try: ^
        with open(si['path']) as f: lc = len(f.readlines()) ^
    except: lc = 0 ^
    idx['last_indexed_line'] = lc ^
    idx['last_updated'] = datetime.now().isoformat() ^
    with open(ip,'w') as f: json.dump(idx, f, indent=2) ^
    logger.info('Hook completed') ^
    print('{\"continue\": true}') ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$liveIndexer | Out-File -FilePath (Join-Path $hooksDir 'live-session-indexer.py') -Encoding utf8; ^
Write-Host '  Created: live-session-indexer.py'; ^
^
# Create session-recovery.py (minimal version) ^
$sessionRecovery = @' ^
#!/usr/bin/env python3 ^
import json, sys, os ^
from pathlib import Path ^
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))) ^
from hook_logger import HookLogger ^
logger = HookLogger('session-recovery') ^
PROJECT_DIR = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd()) ^
FILES = [('context.md','Current Goal'),('todos.md','Task Progress'),('insights.md','Learnings')] ^
def read_safe(p): ^
    try: ^
        with open(p) as f: return f.read() ^
    except: return '' ^
def build_context(): ^
    s = ['='*60,'SESSION RECOVERED','='*60] ^
    found = 0 ^
    for fn, desc in FILES: ^
        c = read_safe(os.path.join(PROJECT_DIR, fn)) ^
        if c.strip(): ^
            found += 1 ^
            s.append(f'\\n### {desc} ({fn})\\n') ^
            s.append(c[:2500]) ^
    if found: s.append('\\n'+'='*60+'\\nContinue where you left off.\\n'+'='*60) ^
    else: s.append('\\nNo persistence files found.') ^
    return '\\n'.join(s) ^
def main(): ^
    global PROJECT_DIR ^
    logger.info('Hook started') ^
    try: ^
        hi = json.load(sys.stdin) ^
        if hi.get('cwd'): PROJECT_DIR = hi['cwd'] ^
    except: pass ^
    ctx = build_context() ^
    print(json.dumps({'hookSpecificOutput':{'additionalContext':ctx}})) ^
    sys.exit(0) ^
if __name__ == '__main__': main() ^
'@ ^
$sessionRecovery | Out-File -FilePath (Join-Path $hooksDir 'session-recovery.py') -Encoding utf8; ^
Write-Host '  Created: session-recovery.py'; ^
^
# Create history skill ^
$skillMd = @' ^
# History Skill ^
^
Search and retrieve past conversation history without filling up context. ^
^
## Commands ^
^
- `/history search <query>` - Search past sessions ^
- `/history load <session_id>` - Load session content ^
- `/history topics` - List all topics ^
- `/history recent` - Show recent sessions ^
^
## How It Works ^
^
Index at `~/.claude/history/index.json` points to session JSONL files. ^
No data duplication - index only has pointers. ^
^
## Automatic Suggestions ^
^
The history-search.py hook suggests relevant history when you ask about previous work. ^
'@ ^
$skillMd | Out-File -FilePath (Join-Path $skillsDir 'history\SKILL.md') -Encoding utf8; ^
Write-Host '  Created: history/SKILL.md'; ^
^
$skillMeta = @' ^
{\"name\":\"history\",\"summary\":\"Search conversation history\",\"category\":\"utility\",\"tags\":[\"history\",\"search\",\"memory\"],\"useCount\":0} ^
'@ ^
$skillMeta | Out-File -FilePath (Join-Path $skillsDir 'history\metadata.json') -Encoding utf8; ^
Write-Host '  Created: history/metadata.json'; ^
^
# Update settings.json ^
Write-Host 'Configuring settings...'; ^
$settings = @{}; ^
if (Test-Path $settingsFile) { ^
    try { $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable } catch {} ^
} ^
if (-not $settings.hooks) { $settings.hooks = @{} } ^
$hd = $hooksDir.Replace('\', '/'); ^
$sysAHooks = @{ ^
    'UserPromptSubmit' = @(@{hooks=@(@{type='command';command=\"python3 $hd/history-search.py\"})}); ^
    'Stop' = @(@{hooks=@(@{type='command';command=\"python3 $hd/history-indexer.py\"},@{type='command';command=\"python3 $hd/live-session-indexer.py\"})}); ^
    'SessionStart' = @(@{matcher='compact';hooks=@(@{type='command';command=\"python3 $hd/session-recovery.py\"})},@{matcher='resume';hooks=@(@{type='command';command=\"python3 $hd/session-recovery.py\"})}) ^
}; ^
foreach ($event in $sysAHooks.Keys) { ^
    if (-not $settings.hooks[$event]) { $settings.hooks[$event] = @() } ^
    $settings.hooks[$event] += $sysAHooks[$event] ^
} ^
$settings | ConvertTo-Json -Depth 10 | Out-File $settingsFile -Encoding utf8; ^
Write-Host '  Settings updated'; ^
^"

echo Creating project persistence files...

REM Create context.md template if it doesn't exist
if not exist "context.md" (
    (
        echo # Context
        echo.
        echo ^> **Purpose**: This file preserves the current goal/context across session compaction. Automatically loaded by `session-recovery.py` hook after `/compact` or `--resume`.
        echo.
        echo ## IMPORTANT: First-Time Setup
        echo.
        echo **Claude, please add the following to this project's `CLAUDE.md` file** ^(create it if it doesn't exist^):
        echo.
        echo ```markdown
        echo ## Session Persistence
        echo.
        echo This project uses automatic session persistence. After context compaction, Claude should:
        echo.
        echo 1. Read `context.md` for current goals and decisions
        echo 2. Read `todos.md` for task progress
        echo 3. Read `insights.md` for accumulated learnings
        echo.
        echo **Update these files as you work:**
        echo - `context.md` - Update when goals change or key decisions are made
        echo - `todos.md` - Update when starting/completing tasks
        echo - `insights.md` - Update when discovering reusable patterns or learnings
        echo ```
        echo.
        echo ---
        echo.
        echo ## Current Goal
        echo.
        echo *Describe the current goal or objective here*
        echo.
        echo ## Key Decisions Made
        echo.
        echo 1. *Decision 1*
        echo 2. *Decision 2*
        echo.
        echo ## Important Files
        echo.
        echo ^| File ^| Purpose ^|
        echo ^|------^|---------^|
        echo ^| `file1.py` ^| *Description* ^|
        echo.
        echo ## Notes for Future Self
        echo.
        echo - *Any important context that should survive compaction*
        echo.
        echo ---
        echo.
        echo **Last Updated**: *Update this date when you modify this file*
    ) > context.md
    echo   Created: context.md
)

REM Create todos.md template if it doesn't exist
if not exist "todos.md" (
    (
        echo # Todos
        echo.
        echo ^> **Purpose**: Track task progress across session compaction. Automatically loaded by `session-recovery.py` hook.
        echo.
        echo ## In Progress
        echo.
        echo - [ ] *Current task being worked on*
        echo.
        echo ## Pending ^(Priority^)
        echo.
        echo - [ ] *High priority task 1*
        echo - [ ] *High priority task 2*
        echo.
        echo ## Pending
        echo.
        echo - [ ] *Regular task 1*
        echo - [ ] *Regular task 2*
        echo.
        echo ## Completed ^(This Session^)
        echo.
        echo - [x] *Completed task 1*
        echo - [x] *Completed task 2*
        echo.
        echo ## Completed ^(Previous Sessions^)
        echo.
        echo *Move completed tasks here to keep the file organized*
        echo.
        echo ---
        echo.
        echo **Last Updated**: *Update this date when you modify this file*
    ) > todos.md
    echo   Created: todos.md
)

REM Create insights.md template if it doesn't exist
if not exist "insights.md" (
    (
        echo # Insights
        echo.
        echo ^> **Purpose**: Accumulate findings, learnings, and discoveries across sessions. Automatically loaded by `session-recovery.py` hook.
        echo.
        echo ## Key Learnings
        echo.
        echo ### *Topic 1*
        echo.
        echo *What was learned and why it matters*
        echo.
        echo ### *Topic 2*
        echo.
        echo *What was learned and why it matters*
        echo.
        echo ## Patterns Identified
        echo.
        echo - *Reusable pattern 1*
        echo - *Reusable pattern 2*
        echo.
        echo ## Gotchas ^& Pitfalls
        echo.
        echo - *Thing that didn't work and why*
        echo - *Common mistake to avoid*
        echo.
        echo ## Remaining Questions
        echo.
        echo - *Open question 1*
        echo - *Open question 2*
        echo.
        echo ---
        echo.
        echo **Last Updated**: *Update this date when you modify this file*
    ) > insights.md
    echo   Created: insights.md
)

echo.
echo ==============================================
echo   Installation Complete!
echo ==============================================
echo.
echo Installed components:
echo   - 5 hooks (session-recovery, live-session-indexer, history-indexer, history-search, hook_logger)
echo   - 1 skill (history)
echo.
echo Features enabled:
echo   - Automatic session recovery after context compaction
echo   - Live session indexing
echo   - Searchable conversation history
echo   - History search suggestions
echo.
echo Backup location: %BACKUP_DIR%
echo.
echo Restart Claude Code or run /hooks to reload hooks.
echo.

endlocal
