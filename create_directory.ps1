$randomDir = "C:\\RandomDirectory_" + (Get-Random -Maximum 10000)
New-Item -Path $randomDir -ItemType Directory
Write-Output "Created directory: $randomDir"
