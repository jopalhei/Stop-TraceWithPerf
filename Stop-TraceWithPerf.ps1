<#
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

param(
    $maxlatencyms = 40,    
    $TimeToEnd = 60
    
)
$maxlatency = $maxlatencyms/1000
$paths = (Get-Counter -ListSet Physicaldisk).PathsWithInstances | where {$_ -like "*\Avg. Disk sec/Transfer" -and $_ -notlike "\PhysicalDisk(_Total)\*" }
logman delete PerfLog-Short | Out-Null
Logman.exe create counter PerfLog-Short -o C:\Temp\MSPerfData\PerfLog-Short.blg -f bincirc -v mmddhhmm -max 500 -c "\LogicalDisk(*)\*" "\Memory\*" "\Cache\*" "\Network Interface(*)\*{" "\Netlogon(*)\*" "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\Processor(*)\*" "\Processor Information(*)\*" "\Process(*)\*" "\Thread(*)\*" "\Redirector\*" "\Server\*" "\System\*" "\Server Work Queues(*)\*" "\Terminal Services\*" -si 00:00:01
logman start PerfLog-Short
logman create trace "storport" -ow -o C:\Temp\MSPerfData\storport.etl -p "Microsoft-Windows-StorPort" 0xffffffffffffffff 0xff -nb 16 16 -bs 1024 -mode Circular -f bincirc -max 4096 -ets
$run = $true
Write-Host "Traces are enabled - Waiting the latency of one Physical Disk to be above $maxlatencyms(ms)" -ForegroundColor Green
Write-Host "Please don't Close this Powershell Window!" -ForegroundColor Yellow -BackgroundColor Red
do {
        $values = Get-Counter -Counter $paths

        foreach ($value in $values.CounterSamples)
        {
            if ($value.Cookedvalue -ge $maxlatency)
            {
                $Message = "The Stop was triggered at " + (Get-Date) + " on the following counter "
                $Message | Out-File "C:\Temp\MSPerfData\PerfCounterTrigger.txt"
                $value | Out-File "C:\Temp\MSPerfData\PerfCounterTrigger.txt" -Append
                Write-Host "The Stop was triggered at " (Get-Date) " on the following counter " -ForegroundColor Green
                Write-Host "Physical Disk is " $value.InstanceName " avg. disk sec/transfer = " $value.CookedValue -ForegroundColor Green
                Write-Host "Starting to Sleep for " $TimeToEnd "(s) and then will stop the traces" -ForegroundColor Green
                Start-Sleep -Seconds $TimeToEnd
                logman stop PerfLog-Short
                logman stop "Storport" -ets
                Write-Host "Traces were stopped" -ForegroundColor Green
                $run = $false
                Break
            }
        }
    Start-Sleep -Seconds 1
} while ($run)
logman delete PerfLog-Short
Write-Host "Your Data is on C:\Temp\MSPerfData\" -ForegroundColor Green
