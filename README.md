# Windows Hardware Report

Prints a Windows hardware and system report.

## Run

```powershell
irm "https://raw.githubusercontent.com/polakv93/scripts/refs/heads/main/device_hardware_report.ps1" | iex | Tee-Object -Variable report | Set-Clipboard; $report
```

This runs the latest version from GitHub, copies the report to the clipboard, and prints it in the terminal.
