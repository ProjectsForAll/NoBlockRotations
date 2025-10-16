# Start up.
Write-Information "Zipping up resource packs..."

# Regular pack
Write-Information "Zipping up regular pack..."
Remove-Item "NoBlockRotations.zip" -ErrorAction SilentlyContinue
Compress-Archive -Path "NoBlockRotations/*" -DestinationPath "NoBlockRotations.zip"

# Extractable pack
Write-Information "Zipping up extractable pack..."
Remove-Item "NoBlockRotations-extractable.zip" -ErrorAction SilentlyContinue
Compress-Archive -Path "NoBlockRotations" -DestinationPath "NoBlockRotations-extractable.zip"

# Done
Write-Information "Done!"