# Reep Release Script
# 用法: .\scripts\release.ps1 [版本号]
# 示例: .\scripts\release.ps1 v1.0.0

param(
    [string]$Version = "v1.0.0"
)

$ErrorActionPreference = "Stop"

# GitHub Token（从环境变量读取，或手动输入）
$GH_TOKEN = $env:GH_TOKEN
if (-not $GH_TOKEN) {
    Write-Host "请输入 GitHub Personal Access Token:" -ForegroundColor Yellow
    $GH_TOKEN = Read-Host -AsSecureString
    $GH_TOKEN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($GH_TOKEN)
    )
}

$REPO = "M1orz/Reep"
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$API_URL = "https://api.github.com/repos/$REPO/releases"

Write-Host "`n=== Reep Release $Version ===`n" -ForegroundColor Cyan

# 1. 编译发布版 APK
Write-Host "[1/3] Building release APK..." -ForegroundColor Yellow

$env:APPDATA = "D:\dev\fluttercfg"
$env:PUB_CACHE = "D:\dev\pub-cache"
$env:GRADLE_USER_HOME = "D:\dev\gradle-home"

flutter build apk --release 2>&1 | Out-Null

if (-not (Test-Path $APK_PATH)) {
    Write-Host "Error: APK not found at $APK_PATH" -ForegroundColor Red
    exit 1
}

$apkSize = (Get-Item $APK_PATH).Length / 1MB
Write-Host "  APK built: $apkSize MB" -ForegroundColor Green

# 2. 创建 Release
Write-Host "[2/3] Creating GitHub release..." -ForegroundColor Yellow

$body = @{
    tag_name         = $Version
    name             = "Reep $Version"
    body             = "## Changelog`n`n- Initial release"
    draft            = $false
    prerelease       = $false
} | ConvertTo-Json -Compress

$headers = @{
    "Authorization" = "token $GH_TOKEN"
    "Content-Type"  = "application/json"
}

$response = Invoke-RestMethod -Uri $API_URL -Method Post -Headers $headers -Body $body

$uploadUrl = $response.upload_url -replace `\{.*`, ""
Write-Host "  Release created: $($response.html_url)" -ForegroundColor Green

# 3. 上传 APK
Write-Host "[3/3] Uploading APK..." -ForegroundColor Yellow

$uploadHeaders = @{
    "Authorization" = "token $GH_TOKEN"
    "Content-Type"  = "application/vnd.android.package-archive"
}

Invoke-RestMethod -Uri "$uploadUrl?name=app-release.apk" `
    -Method Post -Headers $uploadHeaders `
    -InFile $APK_PATH | Out-Null

Write-Host "`n=== Done! ===" -ForegroundColor Green
Write-Host "Download: $($response.html_url)" -ForegroundColor Cyan
