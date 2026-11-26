# Install the agent-conventions Skill for every agent tool on this machine (Windows).
#   irm https://raw.githubusercontent.com/zhoushoujianwork/agent-conventions/main/install.ps1 | iex
# Real copies go to ~\.agents\skills (read directly by Codex, Gemini CLI, Antigravity CLI); Claude Code and
# Antigravity get copies in their own skill folders. No symlinks on Windows.
param([string]$Ref = "main", [switch]$Uninstall)
$ErrorActionPreference = "Stop"
$Repo = "zhoushoujianwork/agent-conventions"; $Mark = ".branch-flow"; $Skills = @("agent-conventions", "branch-flow", "agents-layout")  # the last two are v0.1/v0.2 names
$HomeDir = if ($env:BRANCH_FLOW_HOME) { $env:BRANCH_FLOW_HOME } else { $HOME }
$Shared = Join-Path $HomeDir ".agents\skills"
$Targets = @(
  @{ Id = "claude";     Dir = Join-Path $HomeDir ".claude\skills";              Marker = Join-Path $HomeDir ".claude" },
  @{ Id = "agy";        Dir = Join-Path $HomeDir ".gemini\config\skills";       Marker = Join-Path $HomeDir ".gemini\config" },
  @{ Id = "agy-legacy"; Dir = Join-Path $HomeDir ".gemini\antigravity\skills";  Marker = Join-Path $HomeDir ".gemini\antigravity" }
)
$Retired = @((Join-Path $HomeDir ".codex\skills"), (Join-Path $HomeDir ".gemini\skills"))
function Ours($Path) { Test-Path (Join-Path $Path $Mark) }
function Drop($Path, $Label) { if (Ours $Path) { Remove-Item -Recurse -Force $Path; "removed  ${Label}: $Path" } }

if ($Uninstall) {
  foreach ($s in $Skills) {
    foreach ($t in $Targets) { Drop (Join-Path $t.Dir $s) $t.Id }
    foreach ($r in $Retired) { Drop (Join-Path $r $s) "retired" }
    Drop (Join-Path $Shared $s) "agents"
  }
  return
}

$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("agent-conventions-" + [Guid]::NewGuid())
New-Item -ItemType Directory $Tmp | Out-Null
try {
  $Zip = Join-Path $Tmp "src.zip"
  Invoke-WebRequest "https://github.com/$Repo/archive/$Ref.zip" -OutFile $Zip -UseBasicParsing
  Expand-Archive $Zip $Tmp
  $Src = Get-ChildItem $Tmp -Directory -Recurse -Depth 1 | Where-Object { $_.Name -eq "skills" } | Select-Object -First 1
  if (-not $Src -or -not (Test-Path (Join-Path $Src.FullName "agent-conventions\SKILL.md"))) { throw "download did not contain skills/" }
  foreach ($dir in Get-ChildItem $Src.FullName -Directory) {
    $s = $dir.Name; if (-not (Test-Path (Join-Path $dir.FullName "SKILL.md"))) { continue }
    $Real = Join-Path $Shared $s
    if ((Test-Path $Real) -and -not (Ours $Real)) { throw "refusing to overwrite ${Real}: not installed by agent-conventions" }
    if (Test-Path $Real) { Remove-Item -Recurse -Force $Real }
    New-Item -ItemType Directory -Force $Shared | Out-Null
    Copy-Item -Recurse $dir.FullName $Real
    Set-Content (Join-Path $Real $Mark) $Ref
    "installed agents: $Real"
    foreach ($r in $Retired) { Drop (Join-Path $r $s) "retired" }
    foreach ($t in $Targets) {
      if (-not (Test-Path $t.Marker)) { "skipped  $($t.Id): $($t.Marker) not found"; continue }
      $d = Join-Path $t.Dir $s
      if ((Test-Path $d) -and -not (Ours $d)) { "skipped  $($t.Id): $d exists and was not installed by agent-conventions"; continue }
      if (Test-Path $d) { Remove-Item -Recurse -Force $d }
      New-Item -ItemType Directory -Force $t.Dir | Out-Null
      Copy-Item -Recurse $Real $d
      "installed $($t.Id): $d"
    }
  }
  foreach ($old in @("branch-flow", "agents-layout")) {
    foreach ($t in $Targets) { Drop (Join-Path $t.Dir $old) "old $($t.Id)" }
    foreach ($r in $Retired) { Drop (Join-Path $r $old) "retired" }
    Drop (Join-Path $Shared $old) "old agents"
  }
} finally { Remove-Item -Recurse -Force $Tmp }
