<#
  Excerpt 02 - Single guarded delivery entry.
  Production source : scripts/send-if-ready.ps1
  Production lines  : 104-150, 179-200, 229-268
  Label             : verbatim
#>
# --- Gate condition checks ---
if ($status.email_sent -eq $true -and -not $Force.IsPresent) {
    Write-Output "EMAIL_ALREADY_SENT: email_sent=true for $Date."
    exit 0
}

# Defense-in-depth: manual review flag blocks sending even if other gate
# fields were wrongly set to SENDABLE (e.g. by a bug). Do not modify status
# here; the contradictory state is left for human inspection.
if ($status.manual_review_required -eq $true) {
    Write-Output "BLOCKED: manual_review_required=true, refusing to send"
    exit 1
}

if ($status.brief_written -ne $true) {
    Write-Output "BLOCKED: brief_written != true"
    exit 1
}

if ($status.validator_status -ne "PASS") {
    Write-Output "BLOCKED: validator_status=$($status.validator_status)"
    exit 1
}

if ($status.delivery_allowed -ne $true) {
    Write-Output "BLOCKED: delivery_allowed != true"
    exit 1
}

if ($status.gate_status -ne "SENDABLE") {
    Write-Output "BLOCKED: gate_status=$($status.gate_status), expected SENDABLE"
    exit 1
}

# Check brief file exists and non-empty
$briefPath = $status.brief_path
if ([string]::IsNullOrWhiteSpace($briefPath) -or -not (Test-Path -LiteralPath $briefPath)) {
    Write-Output "BRIEF_FILE_MISSING: $briefPath"
    exit 1
}

$briefItem = Get-Item -LiteralPath $briefPath
if ($briefItem.Length -eq 0) {
    Write-Output "BRIEF_FILE_EMPTY: $briefPath"
    exit 1
}

# --- Self-check status and delivery_reason whitelist ---
$approvedMain = (
    $status.self_check_status -eq "PASS" -and
    $status.delivery_reason -eq "validator_pass_controller_self_check_pass"
)

$approvedRecovery = (
    $status.delivery_reason -eq "validator_pass_after_recovery_fix_with_prior_content_approval"
)

if (-not ($approvedMain -or $approvedRecovery)) {
    Write-Output "BLOCKED: self_check_status=$($status.self_check_status) delivery_reason=$($status.delivery_reason) not in approved whitelist"
    $status.gate_status = "BLOCKED"
    $status.delivery_allowed = $false
    $status.delivery_reason = "blocked_self_check_or_delivery_reason_not_approved"
    $status.error = "send-if-ready: self_check_status/delivery_reason not in approved whitelist"
    $status.updated_at = (Get-Date -Format "o")
    $json = $status | ConvertTo-Json -Depth 3
    [System.IO.File]::WriteAllText($statusFile, $json, [System.Text.UTF8Encoding]::new($false))
    exit 1
}

        # Transport failure: persist status BEFORE reporting the failure.
        # $ErrorActionPreference=Stop would turn Write-Error into a terminating
        # error and skip the status write; keep delivery_allowed=true,
        # gate_status=SENDABLE. delivery_allowed only expresses content
        # approval; it must not be reset on send-layer failure so a later
        # stage (Recovery) can resend.
        $status.email_sent = $false
        $status.error = "Email send failed with exit code $LASTEXITCODE"
        $status.updated_at = (Get-Date -Format "o")
        $json = $status | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($statusFile, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Output "EMAIL_COMMAND_FAILED: exit code $LASTEXITCODE"
        exit 1
    }
}
catch {
    # Same as above: persist status before reporting, keep content gate intact.
    $status.email_sent = $false
    $status.error = "Email send exception: $($_.Exception.Message)"
    $status.updated_at = (Get-Date -Format "o")
    $json = $status | ConvertTo-Json -Depth 3
    [System.IO.File]::WriteAllText($statusFile, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Output "EMAIL_SEND_EXCEPTION: $($_.Exception.Message)"
    exit 1
}