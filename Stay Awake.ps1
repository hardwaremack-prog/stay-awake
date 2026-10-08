# Stay Awake - keeps your Windows PC from going to sleep, with a simple window
# and a tray icon. Start it with "Start Stay Awake.bat".
# Made by hardwaremack.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Power {
    const uint ES_CONTINUOUS       = 0x80000000;
    const uint ES_SYSTEM_REQUIRED  = 0x00000001;
    const uint ES_DISPLAY_REQUIRED = 0x00000002;
    [DllImport("kernel32.dll")] static extern uint SetThreadExecutionState(uint esFlags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    public static bool Awake(bool screenToo) {
        uint f = ES_CONTINUOUS | ES_SYSTEM_REQUIRED;
        if (screenToo) f |= ES_DISPLAY_REQUIRED;
        return SetThreadExecutionState(f) != 0;
    }
    public static void Release() { SetThreadExecutionState(ES_CONTINUOUS); }
}
"@

# Only one copy at a time
$created = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\HardwaremackStayAwake", [ref]$created)
if (-not $created) {
    [System.Windows.Forms.MessageBox]::Show("Stay Awake is already running. Look for its icon by the clock.", "Stay Awake") | Out-Null
    return
}

[void][Power]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------- state
$script:awake    = $false
$script:started  = $null
$script:endsAt   = $null

$durations = [ordered]@{
    "Until I stop it" = 0
    "15 minutes"      = 15
    "30 minutes"      = 30
    "1 hour"          = 60
    "2 hours"         = 120
    "4 hours"         = 240
    "8 hours"         = 480
}

$green = [System.Drawing.Color]::FromArgb(46, 160, 90)
$gray  = [System.Drawing.Color]::FromArgb(120, 128, 136)
$ink   = [System.Drawing.Color]::FromArgb(32, 36, 40)
$soft  = [System.Drawing.Color]::FromArgb(245, 247, 249)

function New-DotIcon([System.Drawing.Color]$color) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $color), 3, 3, 26, 26)
    $g.FillEllipse([System.Drawing.Brushes]::White, 11, 11, 10, 10)
    $g.Dispose()
    [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
$iconOn  = New-DotIcon $green
$iconOff = New-DotIcon $gray

function Format-Span([TimeSpan]$t) {
    if ($t.TotalSeconds -lt 0) { $t = [TimeSpan]::Zero }
    '{0}:{1:mm}:{1:ss}' -f [int][math]::Floor($t.TotalHours), $t
}

# ---------------------------------------------------------------- window
$form = New-Object System.Windows.Forms.Form
$form.Text = "Stay Awake"
$form.ClientSize = New-Object System.Drawing.Size 360, 330
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Icon = $iconOff
$form.AutoScaleMode = 'Dpi'

$panel = New-Object System.Windows.Forms.Panel
$panel.SetBounds(16, 16, 328, 110)
$panel.BackColor = $soft
$form.Controls.Add($panel)

$dot = New-Object System.Windows.Forms.Panel
$dot.SetBounds(18, 33, 44, 44)
$dot.Add_Paint({
    param($s, $e)
    $e.Graphics.SmoothingMode = 'AntiAlias'
    $c = if ($script:awake) { $green } else { $gray }
    $e.Graphics.FillEllipse((New-Object System.Drawing.SolidBrush $c), 0, 0, 43, 43)
})
$panel.Controls.Add($dot)

$status = New-Object System.Windows.Forms.Label
$status.SetBounds(76, 26, 240, 32)
$status.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 15)
$status.ForeColor = $ink
$panel.Controls.Add($status)

$detail = New-Object System.Windows.Forms.Label
$detail.SetBounds(78, 60, 240, 24)
$detail.ForeColor = $gray
$panel.Controls.Add($detail)

$lblFor = New-Object System.Windows.Forms.Label
$lblFor.Text = "Stay awake for"
$lblFor.SetBounds(16, 144, 120, 24)
$lblFor.ForeColor = $ink
$form.Controls.Add($lblFor)

$combo = New-Object System.Windows.Forms.ComboBox
$combo.DropDownStyle = 'DropDownList'
$combo.SetBounds(150, 141, 194, 28)
foreach ($k in $durations.Keys) { [void]$combo.Items.Add($k) }
$combo.SelectedIndex = 0
$form.Controls.Add($combo)

$chkScreen = New-Object System.Windows.Forms.CheckBox
$chkScreen.Text = "Keep the screen on too"
$chkScreen.Checked = $true
$chkScreen.SetBounds(16, 180, 328, 26)
$chkScreen.ForeColor = $ink
$form.Controls.Add($chkScreen)

$chkTray = New-Object System.Windows.Forms.CheckBox
$chkTray.Text = "Hide to the tray when minimized"
$chkTray.Checked = $true
$chkTray.SetBounds(16, 208, 328, 26)
$chkTray.ForeColor = $ink
$form.Controls.Add($chkTray)

$button = New-Object System.Windows.Forms.Button
$button.SetBounds(16, 254, 328, 52)
$button.FlatStyle = 'Flat'
$button.FlatAppearance.BorderSize = 0
$button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$button.ForeColor = [System.Drawing.Color]::White
$button.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($button)
$form.AcceptButton = $button

# ---------------------------------------------------------------- tray
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miToggle = $menu.Items.Add("Turn on")
$miShow   = $menu.Items.Add("Show window")
[void]$menu.Items.Add("-")
$miExit   = $menu.Items.Add("Exit")

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $iconOff
$tray.Text = "Stay Awake: off"
$tray.ContextMenuStrip = $menu
$tray.Visible = $true

# ---------------------------------------------------------------- behavior
function Update-View {
    if ($script:awake) {
        $status.Text = "Staying awake"
        if ($script:endsAt) {
            $detail.Text = "Time left: " + (Format-Span ($script:endsAt - (Get-Date)))
        } else {
            $detail.Text = "On for " + (Format-Span ((Get-Date) - $script:started))
        }
        $button.Text = "Let it sleep"
        $button.BackColor = [System.Drawing.Color]::FromArgb(70, 78, 86)
        $miToggle.Text = "Turn off"
        $form.Icon = $iconOn; $tray.Icon = $iconOn
        $t = "Stay Awake: on - " + $detail.Text
        $tray.Text = $t.Substring(0, [math]::Min(63, $t.Length))
    } else {
        $status.Text = "Sleep as usual"
        $detail.Text = "Your PC can sleep normally."
        $button.Text = "Keep me awake"
        $button.BackColor = $green
        $miToggle.Text = "Turn on"
        $form.Icon = $iconOff; $tray.Icon = $iconOff
        $tray.Text = "Stay Awake: off"
    }
    $combo.Enabled = -not $script:awake
    $chkScreen.Enabled = -not $script:awake
    $dot.Invalidate()
}

function Start-Awake {
    if (-not [Power]::Awake($chkScreen.Checked)) {
        [System.Windows.Forms.MessageBox]::Show("Windows didn't accept the request to stay awake.", "Stay Awake") | Out-Null
        return
    }
    $script:awake = $true
    $script:started = Get-Date
    $mins = $durations[$combo.SelectedItem]
    $script:endsAt = if ($mins -gt 0) { (Get-Date).AddMinutes($mins) } else { $null }
    Update-View
}

function Stop-Awake([string]$why) {
    [Power]::Release()
    $script:awake = $false
    $script:endsAt = $null
    Update-View
    if ($why) { $tray.ShowBalloonTip(4000, "Stay Awake", $why, 'Info') }
}

function Switch-Awake { if ($script:awake) { Stop-Awake } else { Start-Awake } }

function Show-Window {
    $form.Show()
    $form.WindowState = 'Normal'
    $form.ShowInTaskbar = $true
    $form.Activate()
}

$button.Add_Click({ Switch-Awake })
$miToggle.Add_Click({ Switch-Awake })
$miShow.Add_Click({ Show-Window })
$miExit.Add_Click({ $form.Close() })
$tray.Add_MouseDoubleClick({ Show-Window })
$tray.Add_MouseClick({ param($s, $e) if ($e.Button -eq 'Left') { Show-Window } })

$form.Add_Resize({
    if ($form.WindowState -eq 'Minimized' -and $chkTray.Checked) {
        $form.Hide()
        $form.ShowInTaskbar = $false
        $tray.ShowBalloonTip(2500, "Stay Awake", "Still here, by the clock. Click the icon to open it.", 'Info')
    }
})

# Ticks every second: updates the clock and re-asserts the request every 30 s
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$script:tick = 0
$timer.Add_Tick({
    if (-not $script:awake) { return }
    if ($script:endsAt -and (Get-Date) -ge $script:endsAt) {
        Stop-Awake "Time's up. Your PC can sleep normally again."
        return
    }
    $script:tick++
    if ($script:tick % 30 -eq 0) { [void][Power]::Awake($chkScreen.Checked) }
    Update-View
})
$timer.Start()

$form.Add_FormClosing({
    [Power]::Release()
    $timer.Stop()
    $tray.Visible = $false
    $tray.Dispose()
})

Update-View
[System.Windows.Forms.Application]::Run($form)
$mutex.ReleaseMutex()
