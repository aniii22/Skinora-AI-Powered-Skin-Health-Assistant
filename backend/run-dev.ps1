Set-Location $PSScriptRoot
Get-Content .env | ForEach-Object { if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] } }
go run .
