# Stay Awake

A PowerShell script that keeps your Windows PC (and its screen) from going to sleep until you stop it. While it runs, it also checks the weather for seven US cities every minute and logs it.

## What it does

- Tells Windows to keep the computer and display awake
- Every minute, fetches the temperature and conditions for New York, Los Angeles, Chicago, Houston, Phoenix, Philadelphia and San Antonio from wttr.in
- Appends each reading to `weather_log.csv` and shows the last 50 readings in the window
- Press **Ctrl+C** to stop. The PC can sleep normally again

## Run it

Right-click `StayAwake.ps1` and choose **Run with PowerShell**. If Windows blocks it, open PowerShell in this folder and run:

```
powershell -ExecutionPolicy Bypass -File .\StayAwake.ps1
```

The log file path is set near the top of the script (`$logFile`); change it to a folder on your PC.

---
Made by hardwaremack.
