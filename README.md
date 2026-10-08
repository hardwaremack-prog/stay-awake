# Stay Awake

Keeps your Windows PC (and, if you like, its screen) from going to sleep, with a simple window and a tray icon.

![Stay Awake screenshot](<Stay Awake - screenshot.png>)

## The window (`Stay Awake.ps1`)

- One big button: **Keep me awake** / **Let it sleep**
- Stay awake **until you stop it**, or for 15 minutes up to 8 hours, with a countdown
- **Keep the screen on too**, or just keep the PC running and let the screen turn off
- Minimize it and it hides by the clock. The tray icon turns green while it's keeping the PC awake; click it to open the window, or right-click to turn it on or off
- Closing it always lets the PC sleep normally again
- Nothing is changed in your power settings. It uses the same Windows request that video players use while a movie is playing

### Run it

Double-click `Start Stay Awake.bat`.

## The original script (`StayAwake.ps1`)

The first version, with no window. It keeps the PC and screen awake until you press **Ctrl+C**, and while it runs it logs the weather for seven US cities every minute to `weather_log.csv` on your Desktop.

Right-click `StayAwake.ps1` and choose **Run with PowerShell**. If Windows blocks it, open PowerShell in this folder and run:

```
powershell -ExecutionPolicy Bypass -File .\StayAwake.ps1
```

---
Made by hardwaremack.
