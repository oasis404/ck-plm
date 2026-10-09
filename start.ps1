# 不构建，仅按端口强杀旧实例后启动最新 jar 并健康检查。
$ErrorActionPreference = "Stop"
$port = 8082

$holders = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
if ($holders) {
    foreach ($pid_ in $holders) {
        try { Stop-Process -Id $pid_ -Force; Write-Output "killed port holder PID=$pid_" }
        catch { Write-Output "failed to kill PID=$pid_ : $_" }
    }
    Start-Sleep -Seconds 2
} else { Write-Output "no process on port $port" }

$jar = Get-ChildItem target\ck-plm-*.jar | Sort-Object LastWriteTime | Select-Object -Last 1
Start-Process -FilePath "java" -ArgumentList "-jar", $jar.FullName, "--spring.profiles.active=local" `
    -RedirectStandardOutput app.log -RedirectStandardError app.err -NoNewWindow
Write-Output "started $($jar.Name)"

$url = "http://localhost:$port/api/health"
$up = $false
for ($i = 1; $i -le 40; $i++) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($r.StatusCode -eq 200) { Write-Output "UP after $($i*2)s"; $up = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $up) { Write-Output "WARN: health check not passing, see app.log" }
Write-Output "--- tail app.log ---"
Get-Content app.log -Tail 10
