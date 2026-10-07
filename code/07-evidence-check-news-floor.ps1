<#
  Excerpt 07 - Deterministic evidence handoff check: config-driven news
               floor, structural URL check, per-item required fields.
  Production source : scripts/lib/stage-context.ps1
  Production lines  : 190-235, 309-338
  Production base   : 1b5c8a8
  Label             : verbatim
  Notes             : Chinese comments and strings are production facts.
#>
function Get-DailyBriefNewsFloor {
    <#
      The fewest verified news items a sendable brief may carry, from config:
      news.count_min when news.allow_fewer_if_unverified is true, otherwise
      news.count_target. Between the floor and news.count_target the brief is
      a legitimate but degraded result; below the floor it is not sendable.
    #>
    param($Config)
    $n = $Config.news
    $target = $n.count_target
    $floor = if ($n.allow_fewer_if_unverified -eq $false) { $target } else { $n.count_min }
    if (-not ($floor -is [ValueType]) -or -not ($target -is [ValueType]) -or [int]$floor -lt 1) {
        throw (New-DailyBriefRuntimeError "config news.count_min / news.count_target / news.allow_fewer_if_unverified do not define a news floor of at least 1; run scripts/validate-config.ps1.")
    }
    return [pscustomobject]@{ Floor = [int]$floor; Target = [int]$target }
}

function Test-DailyBriefArticleUrl {
    <#
      Structural URL check only: absolute http(s), not a bare site root, not a
      search-results page. It never judges whether a domain is trustworthy;
      that judgement belongs to the Collector.
    #>
    param([string]$Url)
    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) { return 'NOT_ABSOLUTE_URL' }
    if ($uri.Scheme -notin @('http', 'https')) { return 'NOT_HTTP_URL' }
    if ([string]::IsNullOrEmpty($uri.AbsolutePath.Trim('/')) -and [string]::IsNullOrEmpty($uri.Query)) { return 'SITE_ROOT_URL' }
    $searchHost = $uri.Host -match '(^|\.)(google|bing|baidu|duckduckgo|yahoo)\.[a-z.]+$' -and $uri.AbsolutePath -match '^/(search|s|web)?/?$'
    if ($searchHost -or $uri.AbsolutePath -match '(^|/)search/?$' -or $uri.Query -match '(^|[?&])(q|query|keyword|wd)=') { return 'SEARCH_PAGE_URL' }
    return $null
}

function Test-DailyBriefEvidence {
    <#
      Deterministic Stage 1 -> Stage 2 handoff check. Replaces the Writer's
      former LLM "health check": evidence that passes is trusted as verified.

      status:
        OK       - write from evidence as is
        ANOMALY  - item-level problems listed in issues[]; bounded repair
        UNUSABLE - a whole section is missing/invalid, or fewer news items
                   than the config floor; escalate (Stage 3)
        MISSING  - evidence not (yet) written; readiness wait / BLOCKED
      notes[] are informational and never trigger repair.
    #>
    # News: enough items (config floor), every item complete, verified, a
    # concrete article URL, no duplicate URL.
    $n = $data['news.json']
    $newsFloor = Get-DailyBriefNewsFloor $Config
    $result.counts.news_floor = $newsFloor.Floor
    $result.counts.news_target = $newsFloor.Target
    if ($null -ne $n) {
        $items = @($n.items | Where-Object { $null -ne $_ })
        $result.counts.news = $items.Count
        if ($items.Count -lt $newsFloor.Floor) {
            Add-Issue 'NEWS_BELOW_MIN' 'news.json' "$($items.Count) verified items, floor $($newsFloor.Floor) (news.count_min / news.allow_fewer_if_unverified)" -Fatal
        }
        $seen = @{}
        for ($i = 0; $i -lt $items.Count; $i++) {
            $it = $items[$i]
            foreach ($k in @('title', 'summary', 'source_name', 'url', 'published_at', 'region', 'supporting_fact')) {
                if ([string]::IsNullOrWhiteSpace([string]$it.$k)) { Add-Issue 'NEWS_FIELD_MISSING' "news.items[$i]" $k }
            }
            if ([string]$it.verified -ne 'YES') { Add-Issue 'NEWS_NOT_VERIFIED' "news.items[$i]" "verified='$($it.verified)'" }
            $u = [string]$it.url
            if ($u) {
                $bad = Test-DailyBriefArticleUrl $u
                if ($bad) { Add-Issue "NEWS_$bad" "news.items[$i]" $u }
                if ($seen.ContainsKey($u)) { Add-Issue 'NEWS_DUPLICATE_URL' "news.items[$i]" "same url as news.items[$($seen[$u])]" } else { $seen[$u] = $i }
            }
        }
        if ($items.Count -ge $newsFloor.Floor -and $items.Count -lt $newsFloor.Target) {
            $notes.Add("news below count_target (degraded, still sendable): $($items.Count) of $($newsFloor.Target)")
        }
    }
