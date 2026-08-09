<#
  Excerpt 04 - Regression tests: manual-review defense gate and
               successful rescue restoring SENDABLE.
  Production source : tests/test-stage2-3-contract.ps1
  Production lines  : 135-173, 188-256
  Label             : adapted (privacy and scope redactions only; control flow unchanged)
  Redactions        : test dates, timestamp, helper script name, subject
                      format, and a source-name reference were replaced with
                      placeholders or generic terms (see code/README.md).
#>
# ================================================================
# Case 4: send-if-ready refuses when manual_review_required=true
#         (defense-in-depth: even if all other gate fields say SENDABLE)
# ================================================================
Write-Output "=== Case 4: send-if-ready refuses manual_review_required=true ==="
$tmpConfig = Join-Path $tempRoot "config.json"
$tmpStatusRoot2 = Join-Path $tempRoot "status2"
New-Item -ItemType Directory -Path $tmpStatusRoot2 -Force | Out-Null
$cfgObj = [PSCustomObject]@{
    validator_timezone_id = "Tokyo Standard Time"
    status = [PSCustomObject]@{ root = $tmpStatusRoot2 }
    validator = [PSCustomObject]@{ path = $validatorPath }
    email = [PSCustomObject]@{
        command = Join-Path $repoRoot "scripts\<notify-helper>.ps1"
        subject_format = "yyyy-MM-dd <subject>"
    }
}
$cfgObj | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $tmpConfig -Encoding UTF8

# Build a fully-SENDABLE-looking state (wrongly approved) plus manual review flag
$reviewDate = "2026-01-01"
$status4 = [PSCustomObject]@{
    date                   = $reviewDate
    brief_written          = $true
    brief_path             = Join-Path $tempRoot "dummy-brief.md"
    validator_status       = "PASS"
    self_check_status      = "PASS"
    reviewer_status        = "SKIPPED"
    gate_status            = "SENDABLE"
    delivery_allowed       = $true
    delivery_reason        = "validator_pass_controller_self_check_pass"
    email_sent             = $false
    manual_review_required = $true
}
$status4 | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $tmpStatusRoot2 "$reviewDate.json") -Encoding UTF8

$output4 = & $sendIfReady -Date $reviewDate -ConfigPath $tmpConfig 2>&1
Assert-True (($output4 -join "`n") -match 'manual_review_required') "Case 4: send-if-ready must refuse with manual_review_required reason"
Assert-True (-not (($output4 -join "`n") -match 'EMAIL_COMMAND|Email sent')) "Case 4: must NOT reach the email command"
# ================================================================
# Case 6: successful Stage 3 rescue clears the manual-review flag
#   initial: manual_review_required=true, gate_status=BLOCKED,
#            delivery_allowed=false, email_sent=false, supervisor_status=FAIL
#   rescue patch -> manual_review_required=false, supervisor_status=PASS,
#            gate_status=SENDABLE, delivery_allowed=true, email_sent=false
#   send-if-ready must NOT refuse on manual-review anymore (later gate only)
# ================================================================
Write-Output "=== Case 6: successful rescue restores SENDABLE and clears manual-review ==="
$rescueDate = "2026-01-03"
$status6 = [PSCustomObject]@{
    date                   = $rescueDate
    brief_written          = $true
    brief_path             = Join-Path $tempRoot "dummy-brief.md"
    validator_status       = "FAIL"
    self_check_status      = "FAIL"
    reviewer_status        = "SKIPPED"
    gate_status            = "BLOCKED"
    delivery_allowed       = $false
    delivery_reason        = "p1_missing_specific_source_links"
    email_sent             = $false
    manual_review_required = $true
    supervisor_status      = "FAIL"
    supervisor_action      = "blocked: P1 missing specific source links"
    blocked_at             = "2026-01-01T08:23:14+09:00"
    blocked_reason         = "p1_missing_specific_source_links"
    error                  = "P1: 3 news URLs point to the outlet homepage"
    updated_at             = "2026-01-01T08:23:14+09:00"
}
$status6 | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $tmpStatusRoot2 "$rescueDate.json") -Encoding UTF8

# Stage 3 successful rescue patch (the §7 SENDABLE patch with status recovery)
$patch6 = Join-Path $tempRoot "patch6.json"
$patch6Json = @'
{
  "writer_status": "PASS",
  "validator_status": "PASS",
  "self_check_status": "PASS",
  "reviewer_status": "SKIPPED",
  "gate_status": "SENDABLE",
  "delivery_allowed": true,
  "delivery_reason": "validator_pass_controller_self_check_pass",
  "email_sent": false,
  "supervisor_status": "PASS",
  "manual_review_required": false,
  "supervisor_action": "rescued: re-verified news items, replaced homepage URLs",
  "blocked_reason": "",
  "error": null
}
'@
Write-PatchFile $patch6 $patch6Json
$out6 = & $updateScript -Date $rescueDate -StatusRoot $tmpStatusRoot2 -PatchJsonFile $patch6 2>&1
Assert-True (($out6 -join "`n") -match '\[OK\]') "Case 6: rescue patch must succeed ([OK])"
$rescueStatus = Get-StatusObject (Join-Path $tmpStatusRoot2 "$rescueDate.json")
Assert-True ($rescueStatus.manual_review_required -eq $false) "Case 6: manual_review_required must be false after successful rescue"
Assert-True ($rescueStatus.supervisor_status -eq "PASS") "Case 6: supervisor_status must be PASS after successful rescue"
Assert-True ($rescueStatus.gate_status -eq "SENDABLE") "Case 6: gate_status must be SENDABLE"
Assert-True ($rescueStatus.delivery_allowed -eq $true) "Case 6: delivery_allowed must be true"
Assert-True ($rescueStatus.email_sent -eq $false) "Case 6: email_sent must stay false"
Assert-True ($rescueStatus.blocked_reason -eq "") "Case 6: blocked_reason must be cleared (BLOCKED resolved)"
Assert-True ($null -eq $rescueStatus.error) "Case 6: error must be cleared (null) after successful rescue"
Assert-True ($rescueStatus.supervisor_action -match 'rescued') "Case 6: supervisor_action must be updated"
Assert-True ($rescueStatus.blocked_at -eq "2026-01-01T08:23:14+09:00") "Case 6: blocked_at must be kept as history"

# send-if-ready must now pass the manual-review check and be stopped only by a later gate
$output6 = & $sendIfReady -Date $rescueDate -ConfigPath $tmpConfig 2>&1
Assert-True (-not (($output6 -join "`n") -match 'manual_review_required')) "Case 6: send-if-ready must not refuse on manual-review flag after rescue"
Assert-True (($output6 -join "`n") -match 'BRIEF_FILE_MISSING|VALIDATOR_REFAILED|BLOCKED') "Case 6: must be blocked by a later gate (no real send)"
Assert-True (-not (($output6 -join "`n") -match 'EMAIL_COMMAND|Email sent')) "Case 6: must NOT reach the email command"