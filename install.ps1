# 「清单整理」技能 · 安装器（明文版）
# 用法： irm <地址>/install.ps1 -OutFile "$env:TEMP\tb.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\tb.ps1"

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$SkillName = '清单整理'
$Ver = '2.4'
$ZipName = 'bundle.zip'

# 包地址按版本 tag 取，避免 CDN 把 @main 缓存成旧包
$BaseUrls = @(
    "https://cdn.jsdelivr.net/gh/rainlv00/tools-bootstrap@v$Ver",
    "https://raw.githubusercontent.com/rainlv00/tools-bootstrap/main",
    "https://gcore.jsdelivr.net/gh/rainlv00/tools-bootstrap@v$Ver"
)

$NoReport = ($env:CBQ_NOREPORT -eq '1')

# ---------- 回执 ----------
$Rc = [ordered]@{
    t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    skill = $SkillName
    ver = $Ver
    host = $env:COMPUTERNAME
    user = $env:USERNAME
    os = ''
    mid = ''
    ip = ''
    files = 0
    result = ''
    note = ''
}

if (-not $NoReport) {
    $g = ''
    try { $g = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid } catch { }
    $vol = ''
    try { $vol = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop).VolumeSerialNumber } catch { }
    if ($g) {
        $sha = [Security.Cryptography.SHA256]::Create()
        $hex = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$g|$vol"))[0..7] | ForEach-Object { $_.ToString('x2') })
        $hex = $hex.ToUpper()
        $Rc.mid = $hex.Substring(0, 4) + '-' + $hex.Substring(4, 4) + '-' + $hex.Substring(8, 4) + '-' + $hex.Substring(12, 4)
    }
    try { $Rc.os = [Environment]::OSVersion.Version.ToString() } catch { }
    foreach ($u in @('https://api.ipify.org', 'https://ip.3322.net', 'https://myip.ipip.net')) {
        try {
            $x = (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 4).Content
            if ($x -match '(\d{1,3}\.){3}\d{1,3}') { $Rc.ip = $matches[0]; break }
        } catch { }
    }
}

function Save-Receipt($code) {
    if ($NoReport) { return }
    $Rc.result = $code
    $dir = Join-Path $env:LOCALAPPDATA 'cbq-receipt'
    try {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $path = Join-Path $dir ('receipt-' + ($Rc.mid -replace '-', '') + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $code + '.json')
        [IO.File]::WriteAllText($path, ($Rc | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
        Write-Host "  回执文件：$path" -ForegroundColor DarkGray
        $midShow = '未知'; if ($Rc.mid) { $midShow = $Rc.mid }
        $ipShow = '未知'; if ($Rc.ip) { $ipShow = $Rc.ip }
        Write-Host "  回执摘要：$($Rc.t) | 机器码 $midShow | IP $ipShow | $($Rc.host)/$($Rc.user) | $code" -ForegroundColor DarkGray
    } catch { }
}

function Fail($msg, $code) { Write-Host ""; Write-Host "  $msg" -ForegroundColor Red; Save-Receipt $code; Write-Host ""; exit 1 }
function Step($msg) { Write-Host "  $msg" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  清单整理 · 技能安装" -ForegroundColor Cyan
Write-Host "  --------------------" -ForegroundColor DarkGray
if (-not $NoReport) {
    Step '安装会留一份回执（主机名 / 机器码 / IP），仅供授权管理；不想留可设 CBQ_NOREPORT=1 重跑'
}

$dest = $env:CBQ_DEST
if (-not $dest) { $dest = Join-Path $env:USERPROFILE '.workbuddy\skills' }

# ---------- 1. 取包 ----------
$tmp = Join-Path $env:TEMP ('cbq_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$zipPath = Join-Path $tmp 'bundle.zip'
$urls = @()

if ($env:CBQ_DATA) {
    if (Test-Path $env:CBQ_DATA) { Copy-Item $env:CBQ_DATA $zipPath; Step "使用本地包 $($env:CBQ_DATA)" }
    else { $urls = @($env:CBQ_DATA) }
}

if (-not (Test-Path $zipPath)) {
    if (-not $urls) { $urls = $BaseUrls | ForEach-Object { "$($_)/$ZipName" } }
    $ok = $false
    foreach ($pass in 1..2) {
        if ($pass -eq 2) {
            Step '代理不可用，改用直连重试'
            try { [System.Net.WebRequest]::DefaultWebProxy = $null } catch { }
        }
        foreach ($u in $urls) {
            try {
                Step "下载 $u"
                Invoke-WebRequest -Uri $u -OutFile $zipPath -UseBasicParsing -TimeoutSec 30
                if ((Get-Item $zipPath).Length -gt 1000) { $ok = $true; break }
            } catch { Step "  失败：$($_.Exception.Message)" }
        }
        if ($ok) { break }
    }
    if (-not $ok) { Fail 'E10 下载失败。检查网络（公司网络常拦 GitHub），或让对方直接把 bundle.zip 发你。' 'E10' }
}

# ---------- 2. 解包 ----------
Add-Type -AssemblyName System.IO.Compression.FileSystem
$outDir = Join-Path $tmp 'out'
try { [IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $outDir, [Text.Encoding]::UTF8) }
catch { Fail 'E11 压缩包损坏，重下一遍。' 'E11' }

$src = Join-Path $outDir $SkillName
if (-not (Test-Path $src)) { Fail "E14 包里没找到 $SkillName 目录。" 'E14' }
if (-not (Test-Path (Join-Path $src 'SKILL.md'))) { Fail 'E14 包里缺少 SKILL.md，不是有效技能包。' 'E14' }

# ---------- 3. 落位 ----------
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$target = Join-Path $dest $SkillName
if (Test-Path $target) {
    $bak = "$target.bak-" + (Get-Date -Format 'yyyyMMddHHmmss')
    Move-Item $target $bak
    Step "旧版本已备份到 $bak"
}
Move-Item $src $target

$n = (Get-ChildItem $target -Recurse -File).Count
$Rc.files = $n

Write-Host ""
Write-Host "  安装完成" -ForegroundColor Green
Write-Host "    版本 $Ver ｜ $n 个文件" -ForegroundColor DarkGray
Write-Host "    位置 $target" -ForegroundColor DarkGray
Save-Receipt 'OK'
Write-Host ""
Write-Host "  下一步：重启 WorkBuddy" -ForegroundColor Cyan
Write-Host "  然后在对话里说：清单整理 D:\你的项目路径，英文模板" -ForegroundColor White
Write-Host ""

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
