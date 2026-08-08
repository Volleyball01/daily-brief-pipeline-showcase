<#
  Excerpt 03 - File-based status patching: monotonic email_sent protection
               and atomic persistence.
  Production source : scripts/update-daily-brief-status.ps1
  Production lines  : 165-208
  Label             : verbatim
#>
# email_sent guard: once true, a normal status patch must not reset it to false.
# send-if-ready.ps1 writes email_sent=true directly to the status file (not through
# this updater), so this guard does not affect the normal send path.
if ($patch.PSObject.Properties['email_sent'] -and $status.email_sent -eq $true -and $patch.email_sent -ne $true) {
    Write-Error "email_sent is true and cannot be reset to false via status patch (current=true, patch=$($patch.email_sent))"
    exit 1
}

# Merge patch into status
foreach ($prop in $patch.PSObject.Properties) {
    if ($status.PSObject.Properties[$prop.Name]) {
        $status.$($prop.Name) = $prop.Value
    }
    else {
        $status | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
    }
}

# Always update timestamp (safe for state files missing the property)
if ($status.PSObject.Properties['updated_at']) {
    $status.updated_at = (Get-Date -Format "o")
}
else {
    $status | Add-Member -NotePropertyName "updated_at" -NotePropertyValue (Get-Date -Format "o")
}

# Serialize
$json = $status | ConvertTo-Json -Depth 3

if ($DryRun) {
    Write-Output $json
}
else {
    # Write atomically via temp file
    $tempFile = "$statusFile.tmp"
    try {
        [System.IO.File]::WriteAllText($tempFile, $json, $Utf8NoBom)
        Move-Item -LiteralPath $tempFile -Destination $statusFile -Force
        Write-Output "[OK] Status updated: $statusFile"
    }
    catch {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force
        }