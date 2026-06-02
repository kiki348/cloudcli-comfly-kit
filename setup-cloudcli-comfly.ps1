param(
  [string]$Model = "claude-sonnet-4-6-thinking",
  [string]$ApiBaseUrl = "https://ai.comfly.org/v1/chat/completions",
  [int]$RouterPort = 3456,
  [int]$CloudCliPort = 3001,
  [switch]$InstallClaudeDesktop,
  [switch]$SkipStart
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Convert-SecureStringToPlainText {
  param([securestring]$Secure)
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
  try {
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

Require-Command node
Require-Command npm.cmd

$nodeMajor = [int]((node --version).TrimStart("v").Split(".")[0])
if ($nodeMajor -lt 18) {
  throw "Node.js 18+ is required. Current: $(node --version)"
}

Write-Host "Installing CLI packages..." -ForegroundColor Cyan
npm.cmd install -g @anthropic-ai/claude-code@latest @musistudio/claude-code-router@latest @cloudcli-ai/cloudcli@latest

if ($InstallClaudeDesktop) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Installing official Claude Desktop via winget..." -ForegroundColor Cyan
    winget install --id Anthropic.Claude --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
  } else {
    Write-Warning "winget not found; skipping Claude Desktop install."
  }
}

$existingKey = [Environment]::GetEnvironmentVariable("COMFLY_API_KEY", "User")
if ($existingKey) {
  $reuse = Read-Host "COMFLY_API_KEY already exists. Reuse it? [Y/n]"
  if ($reuse -match "^(n|N)") {
    $secureKey = Read-Host "Enter Comfly API key" -AsSecureString
    $plainKey = Convert-SecureStringToPlainText $secureKey
    [Environment]::SetEnvironmentVariable("COMFLY_API_KEY", $plainKey, "User")
    $env:COMFLY_API_KEY = $plainKey
  } else {
    $env:COMFLY_API_KEY = $existingKey
  }
} else {
  $secureKey = Read-Host "Enter Comfly API key" -AsSecureString
  $plainKey = Convert-SecureStringToPlainText $secureKey
  [Environment]::SetEnvironmentVariable("COMFLY_API_KEY", $plainKey, "User")
  $env:COMFLY_API_KEY = $plainKey
}

$homeDir = [Environment]::GetFolderPath("UserProfile")
$routerDir = Join-Path $homeDir ".claude-code-router"
$claudeDir = Join-Path $homeDir ".claude"
New-Item -ItemType Directory -Force -Path $routerDir | Out-Null
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

$routerConfig = @{
  HOST = "127.0.0.1"
  PORT = $RouterPort
  LOG = $true
  LOG_LEVEL = "info"
  API_TIMEOUT_MS = 600000
  Providers = @(
    @{
      name = "comfly"
      api_base_url = $ApiBaseUrl
      api_key = '$COMFLY_API_KEY'
      models = @($Model)
      transformer = @{
        use = @("enhancetool")
      }
    }
  )
  Router = @{
    default = "comfly,$Model"
    background = "comfly,$Model"
    think = "comfly,$Model"
    longContext = "comfly,$Model"
    webSearch = "comfly,$Model"
  }
}

$routerConfigPath = Join-Path $routerDir "config.json"
$routerConfig | ConvertTo-Json -Depth 20 | Set-Content -Path $routerConfigPath -Encoding UTF8

$claudeSettings = @{
  env = @{
    ANTHROPIC_BASE_URL = "http://127.0.0.1:$RouterPort"
    ANTHROPIC_AUTH_TOKEN = "test"
    NO_PROXY = "127.0.0.1"
    DISABLE_TELEMETRY = "true"
    DISABLE_COST_WARNINGS = "true"
    API_TIMEOUT_MS = "600000"
  }
}

$claudeSettingsPath = Join-Path $claudeDir "settings.json"
$claudeSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $claudeSettingsPath -Encoding UTF8

# Do not set ANTHROPIC_* as global user environment variables.
# Official Claude Desktop may read them and break. Claude Code reads ~/.claude/settings.json.
foreach ($name in @("ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "NO_PROXY", "DISABLE_TELEMETRY", "DISABLE_COST_WARNINGS", "API_TIMEOUT_MS")) {
  [Environment]::SetEnvironmentVariable($name, $null, "User")
}

if (-not $SkipStart) {
  Write-Host "Starting Claude Code Router..." -ForegroundColor Cyan
  & "$env:APPDATA\npm\ccr.cmd" restart | Out-Host
  & "$env:APPDATA\npm\ccr.cmd" status | Out-Host

  $out = Join-Path $env:TEMP "cloudcli-out.log"
  $err = Join-Path $env:TEMP "cloudcli-err.log"
  $cloudcliCmd = "$env:APPDATA\npm\cloudcli.cmd"
  $startScript = "`$env:COMFLY_API_KEY=[Environment]::GetEnvironmentVariable('COMFLY_API_KEY','User'); & '$cloudcliCmd' --port $CloudCliPort"

  Write-Host "Starting CloudCLI on http://localhost:$CloudCliPort ..." -ForegroundColor Cyan
  Start-Process -FilePath powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $startScript) -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err | Out-Null
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "CloudCLI: http://localhost:$CloudCliPort"
Write-Host "Router config: $routerConfigPath"
Write-Host "Claude settings: $claudeSettingsPath"
Write-Host "Model routed to: $Model"
Write-Host ""
Write-Host "Recommended model selection in CloudCLI: Claude -> Sonnet"
