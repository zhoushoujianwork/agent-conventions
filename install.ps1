# Install the branch-flow Skill for every agent tool found on this machine (Windows).
#   irm https://raw.githubusercontent.com/zhoushoujianwork/branch-flow/main/install.ps1 | iex
# Copies (no symlinks) into ~\.agents\skills and each tool's skill folder that exists.
param([string]$Ref = "main", [switch]$Uninstall)
$ErrorActionPreference = "Stop"
$Name = "branch-flow"; $Repo = "zhoushoujianwork/branch-flow"
$HomeDir = if ($env:BRANCH_FLOW_HOME) { $env:BRANCH_FLOW_HOME } else { $HOME }
$Canonical = Join-Path $HomeDir ".agents\skills\$Name"
$Targets = @(
  @{ Id = "claude"; Dir = Join-Path $HomeDir ".claude\skills"; Marker = Join-Path $HomeDir ".claude" },
  @{ Id = "codex";  Dir = Join-Path $HomeDir ".codex\skills";  Marker = Join-Path $HomeDir ".codex" },
  @{ Id = "agy";    Dir = Join-Path $HomeDir ".gemini\antigravity\skills"; Marker = Join-Path $HomeDir ".gemini\antigravity" },
  @{ Id = "gemini"; Dir = Join-Path $HomeDir ".gemini\skills"; Marker = Join-Path $HomeDir ".gemini" }
)
function Owned($Path) { Test-Path (Join-Path $Path ".branch-flow") }

if ($Uninstall) {
  foreach ($t in $Targets) { $d = Join-Path $t.Dir $Name; if (Owned $d) { Remove-Item -Recurse -Force $d; "removed  $($t.Id): $d" } }
  if (Owned $Canonical) { Remove-Item -Recurse -Force $Canonical; "removed  agents: $Canonical" }
  return
}

$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("branch-flow-" + [Guid]::NewGuid())
New-Item -ItemType Directory $Tmp | Out-Null
try {
  $Zip = Join-Path $Tmp "src.zip"
  Invoke-WebRequest "https://github.com/$Repo/archive/$Ref.zip" -OutFile $Zip -UseBasicParsing
  Expand-Archive $Zip $Tmp
  $Src = Get-ChildItem $Tmp -Directory -Recurse | Where-Object { $_.FullName -like "*\skills\$Name" } | Select-Object -First 1
  if (-not $Src -or -not (Test-Path (Join-Path $Src.FullName "SKILL.md"))) { throw "download did not contain skills/$Name" }
  if ((Test-Path $Canonical) -and -not (Owned $Canonical)) { throw "refusing to overwrite $Canonical: it was not installed by branch-flow" }
  if (Test-Path $Canonical) { Remove-Item -Recurse -Force $Canonical }
  New-Item -ItemType Directory -Force (Split-Path $Canonical) | Out-Null
  Copy-Item -Recurse $Src.FullName $Canonical
  Set-Content (Join-Path $Canonical ".branch-flow") $Ref
  "installed agents: $Canonical"
  foreach ($t in $Targets) {
    if (-not (Test-Path $t.Marker)) { "skipped  $($t.Id): $($t.Marker) not found"; continue }
    $d = Join-Path $t.Dir $Name
    if ((Test-Path $d) -and -not (Owned $d)) { "skipped  $($t.Id): $d exists and was not installed by branch-flow"; continue }
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
    New-Item -ItemType Directory -Force $t.Dir | Out-Null
    Copy-Item -Recurse $Canonical $d
    "installed $($t.Id): $d"
  }
} finally { Remove-Item -Recurse -Force $Tmp }
