# 可靠重启：先按端口强杀 8082 占用进程，再构建并启动，最后健康检查。
$ErrorActionPreference = "Stop"
$port = 8082

# 1) 停止占用 8082 的进程（按端口查找，不依赖启动命令行）
$holders = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
if ($holders) {
    foreach ($pid_ in $holders) {
        try {
            Stop-Process -Id $pid_ -Force -ErrorAction Stop
            Write-Output "killed port holder PID=$pid_"
        } catch {
            Write-Output "failed to kill PID=$pid_ : $_"
        }
    }
    Start-Sleep -Seconds 2
} else {
    Write-Output "no process on port $port"
}

# 2) 兜底：清理任何 ck-plm jar 的 java 进程（避免多实例）
$javaProcs = Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
    Where-Object { $_.CommandLine -like '*ck-plm*jar*' }
foreach ($p in $javaProcs) {
    try { Stop-Process -Id $p.ProcessId -Force; Write-Output "killed java pid $($p.ProcessId)" }
    catch { Write-Output "failed to kill java pid $($p.ProcessId): $_" }
}

# 3) 构建
Write-Output "building..."
mvn -q -DskipTests package
if ($LASTEXITCODE -ne 0) { Write-Output "BUILD FAILED"; exit 1 }

# 4) 启动
$jar = Get-ChildItem target\ck-plm-*.jar | Sort-Object LastWriteTime | Select-Object -Last 1
Start-Process -FilePath "java" -ArgumentList "-jar", $jar.FullName, "--spring.profiles.active=local" `
    -RedirectStandardOutput app.log -RedirectStandardError app.err -NoNewWindow
Write-Output "started $($jar.Name)"

# 5) 等待端口监听（Tomcat 在 Spring 上下文刷新完成后才监听 8082，等价于应用就绪）
$up = $false
for ($i = 1; $i -le 40; $i++) {
    $listening = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($listening) { Write-Output "port $port LISTENING after $($i*2)s"; $up = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $up) { Write-Output "WARN: port $port not listening, see app.log" }
Write-Output "--- tail app.log ---"
Get-Content app.log -Tail 8
