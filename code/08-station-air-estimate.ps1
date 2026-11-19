<#
  Excerpt 08 - Computed, not generated: the morning air-quality estimate from
               a local monitoring station's hourly PM2.5 measurements, with
               the main method, the fallback, and honest "no data" states.
  Production source : scripts/lib/air-dust-sources.ps1
  Production lines  : 27-35, 66-96
  Production base   : 7daa53e
  Label             : verbatim
  Notes             : Comments are in English; the Chinese strings are
                      production facts.
                      The backtest behind these constants is described in
                      docs/validation.md (Offline backtests).
#>
$StationRecentHours = 6                # station estimate: mean of the last 6 hourly values ...
$StationRecentMinHours = 4             # ... at least 4 of them ...
$StationRecentMaxAgeHours = 3          # ... newest at most 3 h old (the site runs about 2 h behind) ...
$StationOffset = 0.9                   # ... plus 0.9 (2025-11..2026-11: the mean gap to the 07-21 h mean; scored on the whole day's 24-hour mean it does as well as the best fit, 0.6)
$StationMinHours = 18                  # fallback: mean of the last 24 hourly values, at least 18 (75%) ...
$StationMaxAgeHours = 6                # ... newest at most 6 h old
$StationBand = @(8.0, 10.0)            # estimate in this range (µg/m³, truncated to 0.1): grade 良好～中等
$StationCutoffHour = 9                 # station values up to 09:00 of the brief day at the latest
$Unavailable = '暂不可用'; $NoData = '今日暂无数据'
function Get-StationEstimate {
    # The morning estimate of today's daytime PM2.5 from hourly station values
    # ($Values: hour-end datetime -> µg/m³) up to $Cutoff. Main method: mean of
    # the 6 hours ending at the newest value (at least 4, newest at most 3 h
    # old) plus the morning-to-daytime offset. Fallback: mean of the 24 hours
    # ending at the newest value (at least 18, newest at most 6 h old), no
    # offset. Year backtest 2025-11..2026-11 at 07:00 against the 07–21 h mean:
    # MAE 2.42 vs 2.90 for the plain 24-hour mean, missed moderate days 43 vs 55.
    # Returns @{ Estimate } or @{ Missing; Status }.
    param([hashtable]$Values, [datetime]$Cutoff)
    if ($Values.Count -eq 0) { return @{ Missing = 'no PM2.5 values'; Status = $NoData } }
    $latest = ($Values.Keys | Measure-Object -Maximum).Maximum
    $age = ($Cutoff - $latest).TotalHours
    $pick = { param([int]$n) @(0..($n - 1) | ForEach-Object { $latest.AddHours(-$_) } | Where-Object { $Values.ContainsKey($_) } | ForEach-Object { $Values[$_] }) }
    $recent = & $pick $StationRecentHours
    $day = & $pick 24
    if ($age -le $StationRecentMaxAgeHours -and $recent.Count -ge $StationRecentMinHours) {
        $method = 'recent'; $used = $recent; $of = $StationRecentHours; $offset = $StationOffset
    }
    elseif ($age -le $StationMaxAgeHours -and $day.Count -ge $StationMinHours) {
        $method = 'mean24'; $used = $day; $of = 24; $offset = 0.0
    }
    elseif ($age -gt $StationMaxAgeHours) {
        return @{ Missing = "newest value $($latest.ToString('yyyy-MM-dd HH:00', $Inv)) is too old"; Status = $NoData }
    }
    else {
        return @{ Missing = "$($day.Count)/24 hours"; Status = "数据不足（近 24 小时仅 $($day.Count) 小时有实测）" }
    }
    $mean = ($used | Measure-Object -Average).Average
    return @{ Estimate = [ordered]@{ method = $method; hours = $used.Count; of = $of; latest = $latest; mean = $mean; offset = $offset; estimate = $mean + $offset } }
}
