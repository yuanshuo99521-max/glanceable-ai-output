[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Join-CodePoints {
    param([int[]]$CodePoints)

    $parts = foreach ($codePoint in $CodePoints) {
        [char]::ConvertFromUtf32($codePoint)
    }
    return ($parts -join '')
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Code,
        [int]$Line,
        [string]$Message
    )

    $List.Add([pscustomobject]@{
        Code = $Code
        Line = $Line
        Message = $Message
    }) | Out-Null
}

function Test-EmojiLikeStart {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $value = [int][char]$Text[0]
    return (($value -ge 0xD800 -and $value -le 0xDBFF) -or
            ($value -ge 0x2600 -and $value -le 0x27BF))
}

$ordered = @(
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x1F4CD)); Rank = 0; Name = 'overview' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x1F3AF)); Rank = 1; Name = 'goal' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x2705)); Rank = 2; Name = 'complete' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x1F504)); Rank = 3; Name = 'active' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x23F3)); Rank = 4; Name = 'queued' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x26A0, 0xFE0F)); Rank = 5; Name = 'risk' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x26D4)); Rank = 6; Name = 'blocker' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x2753)); Rank = 7; Name = 'unknown' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x1F4A1)); Rank = 8; Name = 'insight' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x27A1, 0xFE0F)); Rank = 9; Name = 'next' },
    [pscustomobject]@{ Glyph = (Join-CodePoints @(0x1F50E)); Rank = 10; Name = 'evidence' }
)

$forbidden = @(
    (Join-CodePoints @(0x1F7E2)),
    (Join-CodePoints @(0x1F534)),
    (Join-CodePoints @(0x274C)),
    (Join-CodePoints @(0x1F6A7)),
    (Join-CodePoints @(0x1F7E1)),
    (Join-CodePoints @(0x2611, 0xFE0F))
)

$emptyFillers = @(
    (Join-CodePoints @(0x65E0, 0x95EE, 0x9898)),
    (Join-CodePoints @(0x65E0, 0x963B, 0x585E)),
    (Join-CodePoints @(0x65E0, 0x5F85, 0x5224, 0x65AD))
)

$errors = [System.Collections.Generic.List[object]]::new()
$warnings = [System.Collections.Generic.List[object]]::new()

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Add-Issue -List $errors -Code 'FILE_NOT_FOUND' -Line 0 -Message "Report file does not exist: $Path"
}
else {
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $text = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
    $lines = @($text -split "`r?`n")

    foreach ($glyph in $forbidden) {
        if ($text.Contains($glyph)) {
            Add-Issue -List $errors -Code 'FORBIDDEN_SYMBOL' -Line 0 -Message 'A forbidden near-synonym status symbol is present.'
        }
    }

    if ($text -match '(?:[\u3400-\u9FFF]\s){2,}[\u3400-\u9FFF]') {
        Add-Issue -List $errors -Code 'SPACED_CHINESE' -Line 0 -Message 'Chinese characters appear to be separated one by one with spaces.'
    }

    foreach ($filler in $emptyFillers) {
        if ($text.Contains($filler)) {
            Add-Issue -List $errors -Code 'EMPTY_FILLER' -Line 0 -Message 'Empty status categories must be omitted instead of filled.'
            break
        }
    }

    $sections = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $content = $null
        $isHeading = $false

        if ($line -match '^\s{0,3}#{1,6}\s+(?<content>.+?)\s*$') {
            $content = $Matches.content.Trim()
            $isHeading = $true
        }
        elseif ($line -match '^\s*(?<content>\S.*?)\s*$' -and $line -notmatch '^\s*[-*+]\s+') {
            $content = $Matches.content.Trim()
        }

        if ($null -eq $content) {
            continue
        }

        $matched = $null
        foreach ($item in $ordered) {
            if ($content.StartsWith($item.Glyph, [System.StringComparison]::Ordinal)) {
                $matched = $item
                break
            }
        }

        if ($null -ne $matched) {
            $label = $content.Substring($matched.Glyph.Length).Trim()
            if ([string]::IsNullOrWhiteSpace($label)) {
                Add-Issue -List $errors -Code 'MISSING_LABEL' -Line ($index + 1) -Message 'A semantic symbol must have a textual section label.'
            }

            $sections.Add([pscustomobject]@{
                Glyph = $matched.Glyph
                Rank = $matched.Rank
                Name = $matched.Name
                LineIndex = $index
                Line = $index + 1
                IsHeading = $isHeading
            }) | Out-Null
            continue
        }

        if ($isHeading -and (Test-EmojiLikeStart -Text $content)) {
            Add-Issue -List $errors -Code 'UNRECOGNIZED_SECTION_SYMBOL' -Line ($index + 1) -Message 'A section begins with a symbol outside the closed dictionary.'
        }
    }

    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch '^\s*[-*+]\s+(?<item>.+)$') {
            continue
        }
        $itemText = $Matches.item.Trim()
        foreach ($item in $ordered) {
            if ($itemText.StartsWith($item.Glyph, [System.StringComparison]::Ordinal)) {
                Add-Issue -List $errors -Code 'SYMBOL_ON_LIST_ITEM' -Line ($index + 1) -Message 'Semantic status symbols belong in section headings, not repeated list items.'
                break
            }
        }
    }

    if ($sections.Count -eq 0) {
        Add-Issue -List $errors -Code 'NO_SECTIONS' -Line 0 -Message 'No semantic status sections were found.'
    }
    else {
        if ($sections[0].Rank -ne 0) {
            Add-Issue -List $errors -Code 'OVERVIEW_NOT_FIRST' -Line $sections[0].Line -Message 'The first semantic section must be the overview.'
        }

        $overviewCount = @($sections | Where-Object { $_.Rank -eq 0 }).Count
        if ($overviewCount -ne 1) {
            Add-Issue -List $errors -Code 'OVERVIEW_COUNT' -Line 0 -Message 'The report must contain exactly one overview section.'
        }

        $seenRanks = @{}
        $lastRank = -1
        foreach ($section in $sections) {
            if ($section.Rank -lt $lastRank) {
                Add-Issue -List $errors -Code 'SECTION_ORDER' -Line $section.Line -Message 'Semantic sections are not in the required order.'
            }
            $lastRank = [Math]::Max($lastRank, $section.Rank)

            if ($seenRanks.ContainsKey($section.Rank)) {
                Add-Issue -List $errors -Code 'DUPLICATE_SECTION' -Line $section.Line -Message 'Each semantic symbol may define at most one section.'
            }
            else {
                $seenRanks[$section.Rank] = $true
            }
        }

        for ($sectionIndex = 0; $sectionIndex -lt $sections.Count; $sectionIndex++) {
            $start = $sections[$sectionIndex].LineIndex + 1
            $end = $lines.Count - 1
            if ($sectionIndex + 1 -lt $sections.Count) {
                $end = $sections[$sectionIndex + 1].LineIndex - 1
            }

            $hasBody = $false
            if ($start -le $end) {
                for ($lineIndex = $start; $lineIndex -le $end; $lineIndex++) {
                    if (-not [string]::IsNullOrWhiteSpace($lines[$lineIndex])) {
                        $hasBody = $true
                        break
                    }
                }
            }

            if (-not $hasBody) {
                Add-Issue -List $errors -Code 'EMPTY_SECTION' -Line $sections[$sectionIndex].Line -Message 'A semantic section has no body content.'
            }
        }
    }

    $pipeCount = ([regex]::Matches($text, '\|')).Count
    if ($pipeCount -gt 9) {
        Add-Issue -List $warnings -Code 'WIDE_TABLE' -Line 0 -Message 'The report may contain a wide table; verify that a short list would not scan better.'
    }
}

$result = [pscustomobject]@{
    Path = $Path
    Passed = ($errors.Count -eq 0)
    Errors = @($errors)
    Warnings = @($warnings)
}

if ($PassThru) {
    return $result
}

if ($result.Passed) {
    Write-Output "PASS: $Path"
}
else {
    Write-Output "FAIL: $Path"
    foreach ($issue in $result.Errors) {
        Write-Output ("  [{0}] line {1}: {2}" -f $issue.Code, $issue.Line, $issue.Message)
    }
}

foreach ($issue in $result.Warnings) {
    Write-Output ("  WARN [{0}] line {1}: {2}" -f $issue.Code, $issue.Line, $issue.Message)
}

if (-not $result.Passed) {
    exit 1
}
