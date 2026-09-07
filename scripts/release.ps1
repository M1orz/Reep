# Reep Release Script
# 用法: .\scripts\release.ps1 [版本号]
# 示例: .\scripts\release.ps1 v1.1.0
# 说明: 国内网络走本地代理（默认 socks5://127.0.0.1:10808），可用 -Proxy 覆盖

param(
    [string]$Version = "v1.1.0",
    [string]$Proxy = "socks5://127.0.0.1:10808"
)

$ErrorActionPreference = "Stop"

# GitHub Token（从环境变量读取，或手动输入）
$GH_TOKEN = $env:GH_TOKEN
if (-not $GH_TOKEN) {
    Write-Host "请输入 GitHub Personal Access Token:" -ForegroundColor Yellow
    $secure = Read-Host -AsSecureString
    $GH_TOKEN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    )
}

$REPO = "M1orz/Reep"
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$API_URL = "https://api.github.com/repos/$REPO/releases"

# 代理参数：socks5:// 用 --socks5-hostname，http:// 用 -x
$proxyArgs = @()
if ($Proxy.StartsWith("socks5://")) {
    $proxyArgs = @("--socks5-hostname", $Proxy.Substring("socks5://".Length))
} elseif ($Proxy) {
    $proxyArgs = @("-x", $Proxy)
}

Write-Host "`n=== Reep Release $Version ===`n" -ForegroundColor Cyan

# 1. 编译发布版 APK
Write-Host "[1/3] Building release APK..." -ForegroundColor Yellow

$env:APPDATA = "D:\dev\fluttercfg"
$env:PUB_CACHE = "D:\dev\pub-cache"
$env:GRADLE_USER_HOME = "D:\dev\gradle-home"
# Gradle/JVM 走代理拉取依赖；Kotlin 编译器进程内运行，避免守护进程写 AppData 被权限拒绝
$env:JAVA_TOOL_OPTIONS = "-DsocksProxyHost=127.0.0.1 -DsocksProxyPort=10808"

flutter build apk --release 2>&1 | Out-Null

if (-not (Test-Path $APK_PATH)) {
    Write-Host "Error: APK not found at $APK_PATH" -ForegroundColor Red
    exit 1
}

$apkSize = "{0:N1}" -f ((Get-Item $APK_PATH).Length / 1MB)
Write-Host "  APK built: $apkSize MB" -ForegroundColor Green

# 2. 创建 Release（用 curl 走代理，PowerShell 5.1 原生不支持 SOCKS）
Write-Host "[2/3] Creating GitHub release..." -ForegroundColor Yellow

$body = @{
    tag_name   = $Version
    name       = "Reep $Version"
    body       = @"
## 更新内容

- 跑步前可选择「自由跑」或「自定义训练」
- 模块化定制热身 / 跑 / 休息 / 放松，支持按时间或距离
- 模块可编辑数值、删除、拖拽调整顺序
- 训练计划本地保存，可重复使用
- 跑步过程中显示当前模块与进度
"@
    draft      = $false
    prerelease = $false
} | ConvertTo-Json -Compress

# JSON 写入临时文件，避免命令行转义问题
$jsonFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($jsonFile, $body, [System.Text.Encoding]::UTF8)

$respRaw = & curl.exe -s -X POST `
    -H "Authorization: token $GH_TOKEN" `
    -H "Content-Type: application/json" `
    -H "Accept: application/vnd.github+json" `
    @proxyArgs `
    --data-binary "@$jsonFile" `
    $API_URL

Remove-Item $jsonFile -Force

$resp = $respRaw | ConvertFrom-Json
if (-not $resp.upload_url) {
    Write-Host "Error: 创建 Release 失败：" -ForegroundColor Red
    Write-Host $respRaw
    exit 1
}

$uploadUrl = $resp.upload_url -replace '\{.*', ""
Write-Host "  Release created: $($resp.html_url)" -ForegroundColor Green

# 3. 上传 APK
Write-Host "[3/3] Uploading APK..." -ForegroundColor Yellow

$upRaw = & curl.exe -s -X POST `
    -H "Authorization: token $GH_TOKEN" `
    -H "Content-Type: application/vnd.android.package-archive" `
    @proxyArgs `
    --data-binary "@$APK_PATH" `
    "$uploadUrl`?name=app-release.apk"

$up = $upRaw | ConvertFrom-Json
if (-not $up.browser_download_url) {
    Write-Host "Error: 上传 APK 失败：" -ForegroundColor Red
    Write-Host $upRaw
    exit 1
}

Write-Host "`n=== Done! ===" -ForegroundColor Green
Write-Host "Release:  $($resp.html_url)" -ForegroundColor Cyan
Write-Host "Download: $($up.browser_download_url)" -ForegroundColor Cyan
