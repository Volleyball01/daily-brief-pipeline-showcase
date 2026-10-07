<#
  Excerpt 05 - Normal-path context guard: read-chain assertions and fixed
               instruction byte budgets per stage.
  Production source : tests/test-prompts-contract.ps1
  Production lines  : 70-85, 94-103
  Production base   : 1b5c8a8
  Label             : verbatim
  Notes             : Chinese comments and strings are production facts.
#>
# Repository authority is not runtime context. Collector and Writer start from
# the deterministic stage context; engineering contracts are on demand only.
$collectorContent = Get-Content -LiteralPath (Join-Path $repoRoot "prompt\collector-runtime.md") -Raw -Encoding UTF8
foreach ($prompt in @(@{ Name = 'collector'; Text = $collectorContent }, @{ Name = 'writer'; Text = $writerContent })) {
    Assert-True ($prompt.Text -match "resolve-stage-context\.ps1`" -Stage $($prompt.Name)") "$($prompt.Name) must start from resolve-stage-context.ps1 -Stage $($prompt.Name)"
    Assert-True (-not ($prompt.Text -match '完整读取 `docs/daily-run-contract\.md`|daily-status-schema\.md')) "$($prompt.Name) normal path must not read the run contract or status schema"
    Assert-True (-not ($prompt.Text -match '读取 `config/daily-brief\.config\.json`')) "$($prompt.Name) must use the stage config projection, not the full config"
    Assert-True (($prompt.Text.IndexOf('## 1. 你的任务') -ge 0) -and ($prompt.Text.IndexOf('## 1. 你的任务') -lt $prompt.Text.IndexOf('## 2. 开始'))) "$($prompt.Name) must put the mission before the interface"
}
Assert-True (-not ($collectorContent -match 'daily-content-policy\.md|templates/daily-brief\.md')) "Collector must not load writing gates or the template"
Assert-True ($collectorContent -match 'why_it_matters') "Collector must hand its editorial reason to the Writer"
Assert-True (-not ($writerContent -match '写作前先做一次|健康检查')) "Writer must not run a proactive LLM evidence health check"
Assert-True ($writerContent -match '`ANOMALY`[^\n]*docs/evidence-repair\.md') "Writer must load the repair guide only on ANOMALY"
Assert-True ($writerContent -match '## 5\. 失败路径（按需）[\s\S]*docs/daily-content-policy\.md') "Writer must read the content policy only on the failure path"
Assert-True (-not ($writerContent -match 'writer-patch\.json"\s*\r?\n\s*\$patch = \[ordered\]@\{')) "Writer must not hand-assemble the SENDABLE patch (finalize does)"
Assert-True ($writerContent -match 'finalize>.*-Mode Approve') "Writer must approve and send through finalize-daily-brief.ps1"
$budgets = @(
    @{ Stage = 'Collector'; Limit = 26000; Files = @('prompt/collector-runtime.md', 'docs/daily-research-policy.md', 'docs/daily-artifact-schema.md') },
    @{ Stage = 'Writer'; Limit = 18000; Files = @('prompt/writer-sender-runtime.md', 'docs/brief-style-policy.md', 'templates/daily-brief.md') }
)
foreach ($b in $budgets) {
    $bytes = 0
    foreach ($f in $b.Files) { $bytes += (Get-Item -LiteralPath (Join-Path $repoRoot $f)).Length }
    Write-Output "  $($b.Stage) normal-path fixed instructions: $bytes bytes (budget $($b.Limit))"
    Assert-True ($bytes -le $b.Limit) "$($b.Stage) normal-path instructions $bytes bytes exceed the budget $($b.Limit); move content to a script, the stage context or an on-demand document"
}
