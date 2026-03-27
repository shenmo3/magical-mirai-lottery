chcp 65001 > $null

# Change to the directory where the script is located
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition)

# Check if Node.js is installed
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Output "未安装 Node.js。正在安装 Node.js..."
  # Download and install Node.js
  $tempInstallerPath = "$env:TEMP\node-v22.14.0-x64.msi"
  Invoke-WebRequest -Uri "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi" -OutFile $tempInstallerPath
  Start-Process msiexec.exe -ArgumentList "/passive /package $tempInstallerPath" -NoNewWindow -Wait
  Remove-Item -Path $tempInstallerPath
  if ($LASTEXITCODE -ne 0) {
    Write-Output "安装 Node.js 失败。正在退出..."
    Pause
    exit 1
  }
}

# Reload the environment variables to include Node.js
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Install dependencies
Write-Output "正在安装依赖项..."
npm install
if ($LASTEXITCODE -ne 0) {
  Write-Output "安装依赖项失败。正在退出..."
  Pause
  exit 1
}

# Install Playwright dependency
Write-Output "正在安装 Playwright 依赖项..."
npm install playwright
if ($LASTEXITCODE -ne 0) {
  Write-Output "安装 Playwright 依赖项失败。正在退出..."
  Pause
  exit 1
}

# Install Playwright browsers
Write-Output "正在安装 Playwright 浏览器..."
$env:PLAYWRIGHT_BROWSERS_PATH = "0"
npx playwright install > $null 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Output "安装 Playwright 浏览器失败。正在退出..."
  Pause
  exit 1
}

# List of lottery urls and their corresponding names and dates
$lotteryUrls = @(
  @{ Name = "オフィシャルWEB抽選先行（一次受付）"; Url = "http://pia.jp/v/magicalmirai26-1/"; Date = "2026年3月13日(金) 12:00 ～ 4月1日(水) 23:59"; Type = "domestic" },
  @{ Name = "オフィシャルWEB抽選先行（二次受付）"; Url = "http://pia.jp/v/magicalmirai26-2/"; Date = "2026年4月10日(金) 12:00 ～ 5月6日(水) 23:59" ; Type = "domestic" },
  @{ Name = "チケットぴあ 特別先行"; Url = "http://pia.jp/piajp/v/magicalmirai26-p2/"; Date = "2025年05月16日(金) 昼12:00 ～ 2025年06月02日(月) 23:59" ; Type = "domestic" },
  @{ Name = "Advance lottery reservation from website"; Url = "http://pia.jp/v/magicalmirai26en-1/"; Date = "April 10th (Fri.), 2026, 12:00 JST - May 6th (Wed.), 2026, 23:59 JST" ; Type = "overseas" },
  @{ Name = "Advance lottery reservation from website"; Url = "http://pia.jp/v/magicalmirai26en-2/"; Date = "May 15th (Fri.), 2026, 12:00 JST - June 3rd (Wed.), 2026, 23:59 JST"; Type = "overseas" }
)

Write-Output "==============================="
Write-Output "魔法未来国内申请填表器"
Write-Output "==============================="

function Show-Menu {
  Write-Host "请选择一个选项:"
  Write-Host "1. 以测试模式运行脚本"
  Write-Host "2. 以提交模式运行脚本"
  Write-Host "3. Bot防护测试"
  Write-Host "4. 查票模式"
  Write-Host "5. 退出"
  $choice = Read-Host "输入你的选择"
  return $choice
}

do {
  $choice = Show-Menu
  switch ($choice) {
    1 { $mode = "dryrun"; break }
    2 { $mode = "real"; break }
    3 { $mode = "bot"; break }
    4 { $mode = "check"; break }  
    5 { Write-Output "退出中..."; exit 0 }
    default { Write-Output "无效的选择。请重试。" }
  }
  if ($choice -in 1..5) { break }
} while ($true)

function Select-Lottery {
  Write-Host "请选择一个抽选项目:"
  for ($i = 0; $i -lt $lotteryUrls.Count; $i++) {
    $typeDisplay = if ($lotteryUrls[$i].Type -eq "domestic") { "国内" } else { "海外" }
    Write-Host "$($i + 1). [$typeDisplay] $($lotteryUrls[$i].Name) - $($lotteryUrls[$i].Date)"
  }
  $selection = Read-Host "输入你的选择 (1-$($lotteryUrls.Count))"
  if ($selection -match "^\d+$" -and $selection -ge 1 -and $selection -le $lotteryUrls.Count) {
    return $lotteryUrls[$selection - 1]
  }
  else {
    Write-Host "无效的选择，请重试。"
    return $null
  }
}

# skip if checking application or bot test
if ($mode -ne "check" -and $mode -ne "bot") {
  do {
    $selectedLottery = Select-Lottery
  } while (-not $selectedLottery)

  Write-Host "已选择: $($selectedLottery.Name)"

  # Ask if the user wants to use a random proxy
  Write-Host "是否使用随机代理? (y/n)"
  $useProxy = Read-Host "输入你的选择"
  if ($useProxy -match "^[yY]$") {
    Write-Output "已选择使用随机代理。"
    $proxyEnabled = $true
  }
  else {
    Write-Output "未选择使用随机代理。"
    $proxyEnabled = $false
  }

  # Execute index.js using Node.js
  Write-Output "请确保已在 applications.json 中修改并添加所有申请条目。"
  $confirm = Read-Host "确认继续? (y/n)"
  if ($confirm -notmatch "^[yY]$") {
    Write-Output "操作已取消。"
    exit 0
  }
}

Write-Output "正在运行 index.js..."
if ($mode -eq "dryrun") {
  if ($proxyEnabled) {
    node index.js --dry-run --type "$($selectedLottery.Type)" --url "$($selectedLottery.Url)" --use-proxy
  }
  else {
    node index.js --dry-run --type "$($selectedLottery.Type)" --url "$($selectedLottery.Url)"
  }
}
elseif ($mode -eq "bot") {
  if ($proxyEnabled) {
    node index.js --bot-test --type "$($selectedLottery.Type)" --url "$($selectedLottery.Url)" --use-proxy
  }
  else {
    node index.js --bot-test --type "$($selectedLottery.Type)" --url "$($selectedLottery.Url)"
  }
}
elseif ($mode -eq "check") {
  node index.js --check-application
}
else {
  if ($proxyEnabled) {
    node index.js --type "$($selectedLottery.Type)" --url "$($selectedLottery.Url)" --use-proxy
  }
  else {
    node index.js --type "$($selectedLottery.Type)" --url "$($selectedLottery.Url)"
  }
}
