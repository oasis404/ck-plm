Get-CimInstance Win32_Process -Filter "Name='java.exe'" | ForEach-Object {
    $ports = (Get-NetTCPConnection -OwningProcess $_.ProcessId -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Listen' } | Select-Object -ExpandProperty LocalPort -Unique) -join ','
    $cmd = $_.CommandLine
    if ($cmd.Length -gt 150) { $cmd = $cmd.Substring(0, 150) + "..." }
    Write-Output ("PID=" + $_.ProcessId + " ports=" + $ports + " cmd=" + $cmd)
}
