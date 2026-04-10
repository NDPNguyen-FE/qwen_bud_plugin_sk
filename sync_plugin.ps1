
# sync_plugin.ps1 — Copy plugin vào SketchUp 2026 Plugins
# Chạy: .\sync_plugin.ps1

$src_loader = "d:\plugin\panel_plugin.rb"
$src_dir    = "d:\plugin\panel_plugin"
$plugins    = "$env:APPDATA\SketchUp\SketchUp 2026\SketchUp\Plugins"

Write-Host "[sync] Copying loader file..." -ForegroundColor Cyan
Copy-Item $src_loader "$plugins\panel_plugin.rb" -Force

Write-Host "[sync] Syncing plugin folder..." -ForegroundColor Cyan
Remove-Item "$plugins\panel_plugin" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path $src_dir -Destination $plugins -Recurse -Force

Write-Host "[sync] Done! Files copied:" -ForegroundColor Green
Get-ChildItem "$plugins" | Where-Object { $_.Name -like "*panel*" } | Select-Object Name, LastWriteTime
Write-Host ""
Write-Host "Restart SketchUp hoac chay trong Ruby Console:" -ForegroundColor Yellow
Write-Host '  load File.join(Sketchup.find_support_file("Plugins"), "panel_plugin.rb")' -ForegroundColor White
