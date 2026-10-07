<#
  Excerpt 01 - Deterministic validator: structure and content hard gates.
  Production source : scripts/validate-daily-brief.ps1
  Production lines  : 210-311, 378-465
  Production base   : 1b5c8a8
  Label             : verbatim
  Notes             : Chinese comments and strings are production facts.
#>
# 9. Required sections
$requiredSections = @(
    "## 📰 今日要闻",
    "## 📖 今日值得读",
    "## 💬 今日寄语"
)

foreach ($section in $requiredSections) {
    if ($contentNormalized -notmatch [regex]::Escape($section)) {
        Add-Error "缺少固定栏目：$section"
    }
}

if ($contentNormalized -notmatch "(?m)^##\s+.*今日天气") {
    Add-Error "缺少固定栏目：## 今日天气（可带天气图标）"
}

# 10. Weather fields and sources, per ### block (multi-location format)
$weatherFields = @(
    "- 天气：",
    "- 气温：",
    "- 降水概率：",
    "- 带伞建议：",
    "- 预警/注意报："
)

$weatherSectionMatch = [regex]::Match(
    $contentNormalized,
    "(?ms)^##\s+.*今日天气[^\n]*\n(?<body>.*?)(?=^##\s|\z)"
)
$weatherContent = if ($weatherSectionMatch.Success) { $weatherSectionMatch.Groups["body"].Value } else { "" }

$weatherBlocks = [regex]::Matches(
    $weatherContent,
    "(?ms)^###\s+(?<area>[^\n]+)\n(?<body>.*?)(?=^###\s|\z)"
)

$weatherSourcePattern = "(?m)^-\s+来源：\s*\[[^\]]+\]\(https?://[^)]+\)(?:\s*·\s*\[[^\]]+\]\(https?://[^)]+\))*\s*$"
$legacyWeatherSourcePattern = "(?ms)^## 🔍 自检.*?天气来源.*?\[[^\]]+\]\(https?://[^)]+\)"
$hasLegacyWeatherSource = $contentNormalized -match $legacyWeatherSourcePattern

# Legacy format is identified independently: the WHOLE brief uses the old
# single-location layout (no ### weather block anywhere). A document that
# contains any ### weather block is new format and is never downgraded by the
# self-check appendix: every block must carry its own named Markdown source.
$isLegacyWeatherFormat = $weatherBlocks.Count -eq 0

if ($isLegacyWeatherFormat) {
    if ($hasLegacyWeatherSource) {
        Add-Warning "已识别为历史旧版单地点天气格式（无 ### 地点 block），靠自检栏目天气来源通过；新简报请使用 ### 地点 block 格式。"
    }
    else {
        Add-Error "今日天气栏目缺少天气来源：新格式要求每个 ### 地点 block 自带命名 Markdown 来源链接（- 来源：[来源名](URL)）；历史旧格式要求自检栏目含天气来源链接。"
    }
}

foreach ($block in $weatherBlocks) {
    $blockName = $block.Groups["area"].Value.Trim()
    $blockContent = $block.Groups["body"].Value

    foreach ($field in $weatherFields) {
        if ($blockContent -notmatch [regex]::Escape($field)) {
            Add-Warning "天气栏目地点 block「$blockName」可能缺少字段：$field"
        }
    }

    if ($blockContent -notmatch $weatherSourcePattern) {
        Add-Error "天气栏目地点 block「$blockName」必须包含命名 Markdown 来源链接：- 来源：[来源名](URL)。"
    }
}

# 11. News Markdown links
$linkMatches = [regex]::Matches($contentNormalized, "\[[^\]]+\]\((https?://[^)]+)\)")
$newsSectionMatch = [regex]::Match(
    $contentNormalized,
    "(?ms)^## 📰 今日要闻[^\n]*\n(?<body>.*?)(?=^##\s|\z)"
)
$newsContent = if ($newsSectionMatch.Success) { $newsSectionMatch.Groups["body"].Value } else { "" }
$newsLinkMatches = [regex]::Matches($newsContent, "\[[^\]]+\]\((https?://[^)]+)\)")
$noNewsMessage = $contentNormalized -match "未能核验到.+可靠.+新闻" -or
                 $contentNormalized -match "没有.+可靠.+新闻"

if ($newsLinkMatches.Count -lt 1 -and -not $noNewsMessage) {
    Add-Error "未检测到任何 Markdown 新闻来源链接。"
}

# Check numbered news items roughly
$newsItemMatches = [regex]::Matches($newsContent, "(?m)^\d+\.\s+\*\*.+?\*\*.+?\[.+?\]\(https?://.+?\)")

if ($newsItemMatches.Count -lt 1) {
    if (-not $noNewsMessage) {
        Add-Error "未检测到规范的新闻条目，也未说明本次没有可核验的可靠新闻。"
    }
}

# Detect duplicate source URLs, which usually indicate accidental link reuse.
$sourceUrls = @($linkMatches | ForEach-Object { $_.Groups[1].Value })
$duplicateUrls = @($sourceUrls | Group-Object | Where-Object { $_.Count -gt 1 })

foreach ($duplicate in $duplicateUrls) {
    Add-Warning "检测到重复来源链接，请确认是否为同一事件或误用链接：$($duplicate.Name)"
}
# 14. Forbidden process / AI chatter
$forbiddenPatterns = @(
    "作为AI",
    "作为 AI",
    "我是一个AI",
    "我是一个 AI",
    "工具调用",
    "搜索过程",
    "思考过程",
    "以下是我",
    "我将",
    "我会先",
    "审稿助理返回",
    "subagent",
    "PASS",
    "FIX"
)

foreach ($pattern in $forbiddenPatterns) {
    if ($contentNormalized -match [regex]::Escape($pattern)) {
        Add-Warning "正文可能混入过程性或 AI 自我说明文字：$pattern"
    }
}

# 15. Template HTML comment residue
if ($contentNormalized -match "<!--" -or $contentNormalized -match "-->") {
    Add-Error "正文中残留模板 HTML 注释，正式简报或邮件发送前必须删除。"
}

# 16. Suspicious empty placeholders
$placeholderPatterns = @(
    "**标题**",
    "[来源](链接)",
    "最高 X℃",
    "最低 X℃",
    "星期X",
    "YYYY年MM月DD日",
    "YYYY-MM-DD",
    "MM月DD日",
    "{{weather_icon}}",
    "**推荐标题**",
    "来源名称",
    "文章类型",
    "为什么值得读",
    "可用于哪个方向",
    "https://example.com/article",
    "来源：[来源名称](链接)",
    "一句中文的、温暖、具体、实用的话",
    "display_area"
)

foreach ($pattern in $placeholderPatterns) {
    if ($contentNormalized -match [regex]::Escape($pattern)) {
        Add-Error "检测到未替换的模板占位符：$pattern"
    }
}

if ($contentNormalized -match "\{\{deep_reading_[^}]+\}\}") {
    Add-Error "检测到未替换的 deep_reading 模板占位符。"
}

# 17. Public body: no internal collection / process noise (HARD FAIL)
#    Scan all content before "## 🔍 自检" for internal process words.
$publicBodyNoiseKeywords = @(
    'JS渲染',
    'JS 渲染',
    '交叉核验',
    '采集过程',
    '采集受限',
    '页面受限',
    '页面加载受限',
    '抓取失败',
    'fetch失败',
    '无法访问',
    '访问受限',
    '工具调用',
    '调试',
    'debug'
)

$publicBody = ($contentNormalized -split "(?m)^## 🔍 自检", 2)[0]

foreach ($keyword in $publicBodyNoiseKeywords) {
    if ($publicBody -match [regex]::Escape($keyword)) {
        Add-Error "公开正文包含内部采集/调试信息：$keyword。请移除过程说明，只保留用户可用结论。"
        break
    }
}
