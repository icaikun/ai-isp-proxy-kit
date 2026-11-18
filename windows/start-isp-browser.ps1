param(
    [int]$PureIspPort = 17899,
    [string]$TargetTz = "Pacific Standard Time",
    [string]$StartUrl = "https://ping0.cc/env"
)

$ErrorActionPreference = "Stop"
$ProfileDir = Join-Path $PSScriptRoot "chrome-ca-profile"

$ChromeCandidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$ChromeExe = $ChromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ChromeExe) {
    throw "未找到 Google Chrome，请先安装官方正版 Google Chrome。"
}

$client = New-Object System.Net.Sockets.TcpClient
try {
    $iar = $client.BeginConnect("127.0.0.1", $PureIspPort, $null, $null)
    if (-not ($iar.AsyncWaitHandle.WaitOne(1000, $false) -and $client.Connected)) {
        throw "专属纯净端口 (127.0.0.1:$PureIspPort) 未监听，请确认 Clash Verge 已运行且启用了全局扩展覆写配置。"
    }
} finally {
    $client.Close()
}

$DefaultDir = Join-Path $ProfileDir "Default"
New-Item -ItemType Directory -Force -Path $DefaultDir | Out-Null

# 直接写入独立档案 Preferences，防止新版 Chrome 忽略 --force-webrtc-ip-handling-policy 参数
$PrefPath = Join-Path $DefaultDir "Preferences"
if (Test-Path $PrefPath) {
    try {
        $prefObj = Get-Content $PrefPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        $prefObj = [PSCustomObject]@{}
    }
} else {
    $prefObj = [PSCustomObject]@{}
}
$prefObj | Add-Member -NotePropertyName "webrtc" -NotePropertyValue ([PSCustomObject]@{
    ip_handling_policy = "disable_non_proxied_udp"
    multiple_routes_enabled = $false
    nonproxied_udp_enabled = $false
}) -Force
$prefObj | ConvertTo-Json -Depth 32 -Compress | Set-Content -Path $PrefPath -Encoding UTF8

# Windows 版 Chrome 读取系统 Win32 时区；启动期间临时对齐为目标州时区，退出后自动恢复
$OriginalTz = (tzutil.exe /g).Trim()
$SwitchedTz = $false

try {
    if ($TargetTz -and $OriginalTz -ne $TargetTz) {
        tzutil.exe /s "$TargetTz"
        $SwitchedTz = $true
        Write-Host "[1/2] 已临时将系统时区对齐为: $TargetTz" -ForegroundColor Cyan
    }

    $ChromeArgs = @(
        "--user-data-dir=`"$ProfileDir`"",
        "--proxy-server=`"socks5://127.0.0.1:$PureIspPort`"",
        "--enforce-webrtc-ip-permission-check",
        "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
        "--lang=en-US",
        "--accept-lang=en-US,en",
        "--no-first-run",
        "--no-default-browser-check",
        $StartUrl
    )

    Write-Host "[2/2] 纯净 Chrome 已启动！请保持本窗口开启；关闭 Chrome 后将自动恢复原时区 ($OriginalTz)..." -ForegroundColor Green
    $proc = Start-Process -FilePath $ChromeExe -ArgumentList $ChromeArgs -PassThru
    $proc.WaitForExit()
} finally {
    if ($SwitchedTz -and $OriginalTz) {
        tzutil.exe /s "$OriginalTz"
        Write-Host "已自动恢复原系统时区: $OriginalTz" -ForegroundColor Green
    }
}
