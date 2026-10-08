# Keep computer awake until stopped
Write-Host "=== Computer Awake Mode ===" -ForegroundColor Green
Write-Host "This will prevent your computer from sleeping."
Write-Host "Press Ctrl+C to stop and allow sleep again.`n"

# Prevent display from turning off
Add-Type @"
using System;
using Microsoft.Win32;
public class PowerSettings {
    public static void SetKeepAway() {
        // ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
        SetThreadExecutionState(0x80000000 | 0x00000001 | 0x00000002);
    }
    public static void Release() {
        SetThreadExecutionState(0x80000000);
    }
    
    [System.Runtime.InteropServices.DllImport("kernel32.dll")]
    private static extern uint SetThreadExecutionState(uint esFlags);
}
"@

try {
    [PowerSettings]::SetKeepAway()
    Write-Host "Computer will now stay awake!" -ForegroundColor Cyan
    Write-Host "Running weather monitor every minute...`n"
    
    $locations = @{
        "NYC" = "New York, NY";
        "LA" = "Los Angeles, CA";
        "Chicago" = "Chicago, IL";
        "Houston" = "Houston, TX";
        "Phoenix" = "Phoenix, AZ";
        "Philadelphia" = "Philadelphia, PA";
        "San Antonio" = "San Antonio, TX";
    }

    $logFile = Join-Path ([Environment]::GetFolderPath("Desktop")) "weather_log.csv"

    while ($true) {
        try {
            # Prevent sleep during each iteration
            [PowerSettings]::SetKeepAway()
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $outputLines = @()

            foreach ($key in $locations.Keys) {
                try {
                    $weatherUrl = "https://wttr.in/`"$($locations[$key])`"?format=%l+%c+%t"
                    $response = Invoke-RestMethod -Uri $weatherUrl -TimeoutSec 5
                    
                    # Parse: 'new york, ny ??   +5C' -> location, condition, temp
                    $trimmed = $response.Trim()
                    $parts = $trimmed -split '\s+'
                    
                    if ($parts.Count -ge 1) {
                        # Last part is temperature like "+5C" or "+41F"
                        $tempPart = $parts[-1]
                        $condition = "Unknown"
                        
                        if ($tempPart -match '^\+?(\d+)') {
                            $tempVal = [int]$matches[1]
                            if ($tempPart -like "*C") {
                                # Convert C to F: (C * 9/5) + 32
                                $tempF = [math]::Round(($tempVal * 9/5) + 32, 0)
                                $condition = $parts[1] -replace '[^\w\s]', ''
                            } elseif ($tempPart -like "*F") {
                                $tempF = $tempVal
                                $condition = $parts[1] -replace '[^\w\s]', ''
                            } else {
                                # Assume F if no unit specified
                                $tempF = $tempVal
                                $condition = $parts[1] -replace '[^\w\s]', ''
                            }
                            
                            # Only log temperatures above freezing to avoid noise
                            if ($tempF -gt 32) {
                                $outputLines += "$timestamp,$key,${tempF}°F,$condition"
                            }
                        }
                    }
                } catch {
                    $outputLines += "$timestamp,$key,ERROR,-"
                }
            }

            # Append to log file (keep last 1000 entries)
            if ($outputLines.Count -gt 0) {
                $outputLines | Add-Content -Path $logFile -Encoding UTF8
                Write-Host "Logged: $($outputLines.Count) readings" -ForegroundColor Gray
                
                # Show recent readings periodically (every 10th reading)
                if ((Get-Content $logFile).Count % 10 -eq 0) {
                    $recentReadings = Get-Content $logFile | Select-Object -Last 50
                    Write-Host "`n=== Weather Log (Last 50 Readings) ===" -ForegroundColor Cyan
                    $recentReadings | Format-Table -AutoSize
                }
            } else {
                Write-Host "No readings logged this cycle" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
        
        # Sleep for 60 seconds (but keep awake)
        Start-Sleep -Seconds 60
    }
} finally {
    # Restore sleep settings when stopped
    [PowerSettings]::Release()
    Write-Host "`n=== Awake mode disabled. Computer can now sleep. ===" -ForegroundColor Green
}
