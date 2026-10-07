<#
  Excerpt 03 - File-based status patching: monotonic email_sent, brief_path
               guard for SENDABLE, and atomic persistence.
  Production source : scripts/update-daily-brief-status.ps1
  Production lines  : 170-229
  Production base   : 1b5c8a8
  Label             : verbatim
  Notes             : Chinese comments and strings are production facts.
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

# brief_path guard: entering SENDABLE requires the brief file send-if-ready
# will send. Checked on the merged status, before anything is written.
if ($patch.PSObject.Properties['gate_status'] -and $patch.gate_status -eq "SENDABLE") {
    $sendablePath = [string]$status.brief_path
    if ([string]::IsNullOrWhiteSpace($sendablePath) -or
        -not (Test-Path -LiteralPath $sendablePath -PathType Leaf) -or
        (Get-Item -LiteralPath $sendablePath).Length -eq 0) {
        Write-Error "gate_status=SENDABLE requires brief_path to name the existing non-empty brief file (brief_path='$sendablePath'). Include brief_path in the patch."
        exit 1
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
        Write-Error "Failed to write status file: $($_.Exception.Message)"
        exit 1
    }
}
