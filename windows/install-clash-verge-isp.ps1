param(
    [Parameter(Mandatory=$true)][ValidateSet("socks5","http")][string]$IspType,
    [Parameter(Mandatory=$true)][string]$IspServer,
    [Parameter(Mandatory=$true)][int]$IspPort,
    [string]$IspUser = "",
    [string]$IspPass = "",
    [int]$PurePort = 17899
)

$ErrorActionPreference = "Stop"

$CvDir = Join-Path $env:APPDATA "io.github.clash-verge-rev.clash-verge-rev"
$MergePath = Join-Path $CvDir "profiles\Merge.yaml"
if (-not (Test-Path (Split-Path $MergePath))) {
    throw "未找到 Clash Verge 配置目录 ($CvDir)，请确认已安装并至少打开过一次 Clash Verge Rev。"
}

$TemplatePath = Join-Path (Split-Path $PSScriptRoot) "clash-verge\ai-isp-global-merge.yaml"
$Template = Get-Content $TemplatePath -Raw -Encoding UTF8

# Backup existing Merge.yaml if present
if (Test-Path $MergePath) {
    $BakDir = Join-Path $CvDir "backups"
    New-Item -ItemType Directory -Force -Path $BakDir | Out-Null
    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item $MergePath (Join-Path $BakDir "Merge.yaml.$Stamp.bak") -Force
}

$Updated = $Template `
    -replace 'type: socks5                  # 若商家提供 HTTP 代理则改为 http', "type: $IspType" `
    -replace 'server: "<YOUR_ISP_IP>"', "server: `"$IspServer`"" `
    -replace 'port: 1080                    # 改为你的 ISP 端口', "port: $IspPort" `
    -replace 'username: "<YOUR_ISP_USER>"', "username: `"$IspUser`"" `
    -replace 'password: "<YOUR_ISP_PASS>"', "password: `"$IspPass`"" `
    -replace 'port: 17899', "port: $PurePort"

if ($IspType -ne "socks5") {
    $Updated = $Updated -replace '    udp: true\r?\n    dialer-proxy:', '    dialer-proxy:'
}
if (-not $IspUser) {
    $Updated = $Updated -replace '    username: ""\r?\n', ''
}
if (-not $IspPass) {
    $Updated = $Updated -replace '    password: ""\r?\n', ''
}

$Updated | Set-Content -Path $MergePath -Encoding UTF8
Write-Host "[OK] 已写入 Clash Verge 全局扩展覆写配置: $MergePath" -ForegroundColor Green
Write-Host "请在 Clash Verge Rev 的「订阅」页面刷新一次当前激活订阅，然后在「代理」页将 AI-ISP 选为「🇺🇸 独享静态ISP」。" -ForegroundColor Cyan
Write-Host "之后双击 windows\启动纯净AI浏览器.cmd 即可使用干净无泄漏浏览器窗口。" -ForegroundColor Cyan
