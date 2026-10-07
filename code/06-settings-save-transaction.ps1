<#
  Excerpt 06 - Settings save transaction: allow-list, run-window lock,
               external-change guard, stage + validate, backup, write + read-back,
               post-write validation, rollback.
  Production source : scripts/settings/settings-server.ps1
  Production lines  : 316-410
  Production base   : 1b5c8a8
  Label             : verbatim
  Notes             : Chinese comments and strings are production facts.
#>
function Invoke-Save {
    param($Req)
    $writes = $Req.writes
    if ($null -eq $writes -or $writes -isnot [System.Collections.IDictionary] -or $writes.Count -eq 0) {
        return (New-Result 400 ([ordered]@{ ok = $false; code = "bad_request"; message = "没有要保存的内容。" }))
    }
    $allowed = @(Get-ConfigFileList)
    foreach ($rel in $writes.Keys) {
        if ($allowed -notcontains [string]$rel -or $writes[$rel] -isnot [string]) {
            return (New-Result 400 ([ordered]@{ ok = $false; code = "bad_request"; message = "不允许写入：$rel" }))
        }
    }
    $blocked = Test-RunWindowBlocked; if ($blocked) { return $blocked }
    $changed = Test-Base $Req.base
    if ($changed.Count) {
        return (New-Result 409 ([ordered]@{ ok = $false; code = "changed"; message = "配置文件在别处被修改过（$($changed -join '、')）。已停止保存，请重新载入后再改。"; files = $changed }))
    }

    # Encode exactly what will land on disk (keep a BOM only if the file had one).
    $newBytes = @{}
    foreach ($rel in $writes.Keys) {
        $old = [IO.File]::ReadAllBytes((Get-FullPath $ConfigRoot $rel))
        $body = $Utf8NoBom.GetBytes([string]$writes[$rel])
        if (Test-HasBom $old) { $body = [byte[]](@(0xEF, 0xBB, 0xBF) + $body) }
        $newBytes[$rel] = $body
    }

    # 1. Stage + validate (nothing in config/ is touched yet).
    $stage = Join-Path ([IO.Path]::GetTempPath()) ("daily-brief-settings-" + [guid]::NewGuid().ToString("N"))
    try {
        foreach ($rel in $allowed) {
            $dst = Get-FullPath $stage $rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
            if ($newBytes.ContainsKey($rel)) { [IO.File]::WriteAllBytes($dst, $newBytes[$rel]) }
            else { Copy-Item -LiteralPath (Get-FullPath $ConfigRoot $rel) -Destination $dst }
        }
        $pre = Invoke-Validator $stage
    }
    finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not $pre.ok) {
        return (New-Result 422 ([ordered]@{ ok = $false; code = "invalid"; message = "修改后的配置没有通过校验，已停止保存，磁盘上的文件没有任何变化。"; issues = $pre.issues }))
    }

    # 2. Backup.
    $stamp = (Get-Date).ToString("yyyy-MM-dd-HHmmss")
    $backupDir = Join-Path $BackupRoot $stamp
    $n = 2
    while (Test-Path -LiteralPath $backupDir) { $backupDir = Join-Path $BackupRoot "$stamp-$n"; $n++ }
    $backupRel = ".backup/" + (Split-Path -Leaf $backupDir)
    $backups = @{}
    foreach ($rel in $writes.Keys) {
        $src = Get-FullPath $ConfigRoot $rel
        $dst = Get-FullPath $backupDir "$rel.$stamp.bak"
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst
        if ((Get-Sha256 ([IO.File]::ReadAllBytes($dst))) -ne (Get-Sha256 ([IO.File]::ReadAllBytes($src)))) {
            return (New-Result 500 ([ordered]@{ ok = $false; code = "backup_failed"; message = "备份校验失败，已停止保存，配置没有任何变化。" }))
        }
        $backups[$rel] = $dst
    }

    # 3. Write, read back, validate; restore everything on any failure.
    $written = [System.Collections.Generic.List[string]]::new()
    try {
        $i = 0
        foreach ($rel in $writes.Keys) {
            $target = Get-FullPath $ConfigRoot $rel
            $tmp = Join-Path $backupDir (".write-" + $i + ".tmp"); $i++
            [IO.File]::WriteAllBytes($tmp, $newBytes[$rel])
            Move-Item -LiteralPath $tmp -Destination $target -Force
            $written.Add($rel)
            if ((Get-Sha256 ([IO.File]::ReadAllBytes($target))) -ne (Get-Sha256 $newBytes[$rel])) { throw "回读 $rel 与预期不一致。" }
        }
        $post = Invoke-Validator $ConfigRoot
        if (-not $post.ok) { throw "写入后校验未通过：$($post.issues -join ' | ')" }
    }
    catch {
        $reason = $_.Exception.Message
        $restored = $true
        foreach ($rel in $written) {
            try {
                Copy-Item -LiteralPath $backups[$rel] -Destination (Get-FullPath $ConfigRoot $rel) -Force
                if ((Get-Sha256 ([IO.File]::ReadAllBytes((Get-FullPath $ConfigRoot $rel)))) -ne (Get-Sha256 ([IO.File]::ReadAllBytes($backups[$rel])))) { $restored = $false }
            }
            catch { $restored = $false }
        }
        Get-ChildItem -LiteralPath $backupDir -Filter ".write-*.tmp" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        $msg = if ($restored) { "保存失败，已自动恢复到保存前的状态。原因：$reason" } else { "保存失败，且自动恢复不完整。请从 config/$backupRel 手动恢复，或让 Agent 协助。原因：$reason" }
        return (New-Result 500 ([ordered]@{ ok = $false; code = $(if ($restored) { "rolled_back" } else { "rollback_failed" }); message = $msg; backup = $backupRel }))
    }

    return (New-Result 200 ([ordered]@{ ok = $true; backup = $backupRel; files = @($writes.Keys) }))
}
