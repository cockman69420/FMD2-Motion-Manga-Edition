param(
    [string]$UpstreamURL = 'https://github.com/dazedcat19/FMD2.git',
    [string]$UpstreamBranch = 'master',
    [string]$BaseBranch = $env:BASE_BRANCH,
    [string]$ResultFile = 'sync-result.json',
    [switch]$NoPublish
)
$ErrorActionPreference = 'Stop'
function Git-Checked([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) {
    $result = & git @Arguments
    if ($LASTEXITCODE) { throw "git failed: $($Arguments[0])" }
    return $result
}
function Save-Result($state, $upstream, $branch, $files) {
    @{state=$state;upstream=$upstream;branch=$branch;conflicts=@($files)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultFile -Encoding utf8
    if ($env:GITHUB_OUTPUT) { @("state=$state","branch=$branch") | Add-Content -LiteralPath $env:GITHUB_OUTPUT }
}
if ((& git status --porcelain)) { throw 'Upstream sync requires a clean, disposable checkout.' }
if (!$BaseBranch) { $BaseBranch = Git-Checked @('branch','--show-current') }
if (!$BaseBranch) { throw 'Specify the base branch for a detached checkout.' }
Git-Checked @('checkout',$BaseBranch) | Out-Null
Git-Checked @('fetch','--no-tags',$UpstreamURL,$UpstreamBranch) | Out-Null
$upstream = Git-Checked @('rev-parse','FETCH_HEAD')
$baseSHA = Git-Checked @('rev-parse','HEAD')
& git merge-base --is-ancestor $upstream HEAD
if ($LASTEXITCODE -eq 0) { Save-Result 'up-to-date' $upstream '' @(); exit 0 }
$branch = 'automation/upstream-'+$baseSHA.Substring(0,8)+'-'+$upstream.Substring(0,12)
Git-Checked @('checkout','-b',$branch) | Out-Null
& git merge --no-commit --no-ff $upstream
if ($LASTEXITCODE) {
    $files = @(& git diff --name-only --diff-filter=U)
    if (!$files.Count) { throw 'Merge failed for a reason other than a content conflict.' }
    Save-Result 'conflict' $upstream $branch $files
    Git-Checked @('merge','--abort') | Out-Null
    $body = "Official FMD2 revision: $upstream`n`nMerge stopped. Motion customizations were not overwritten.`n`nConflicting paths:`n" + (($files | ForEach-Object { '- '+$_ }) -join "`n")
    $body | Set-Content -LiteralPath 'upstream-conflict.md' -Encoding utf8
    if ($env:GITHUB_STEP_SUMMARY) { $body | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY }
    if (!$NoPublish) {
        $title = '[upstream conflict] '+$upstream.Substring(0,12)
        $issues = & gh issue list --state open --search "$title in:title" --json number | ConvertFrom-Json
        if ($LASTEXITCODE) { throw 'Could not check existing conflict issues.' }
        if (!$issues.Count) { & gh issue create --title $title --body-file upstream-conflict.md; if ($LASTEXITCODE) { throw 'Could not register the conflict issue.' } }
    }
    exit 2
}
Git-Checked @('commit','-m',('Merge official FMD2 '+$upstream+' for Motion review')) | Out-Null
if (!$NoPublish) {
    & git ls-remote --exit-code --heads origin $branch *> $null
    if ($LASTEXITCODE -ne 0) { Git-Checked @('push','origin',('HEAD:refs/heads/'+$branch)) | Out-Null }
    $prs = & gh pr list --head $branch --state open --json number | ConvertFrom-Json
    if ($LASTEXITCODE) { throw 'Could not check existing sync pull requests.' }
    if (!$prs.Count) {
        "Integrates official FMD2 $upstream. Motion support must pass native and offline browser tests. Review before merging; no automatic merge or binary replacement." | Set-Content -LiteralPath 'upstream-pr.md' -Encoding utf8
        & gh pr create --base $BaseBranch --head $branch --title ('Sync official FMD2 '+$upstream.Substring(0,12)) --body-file upstream-pr.md
        if ($LASTEXITCODE) { throw 'Could not create the upstream review pull request.' }
    }
}
Save-Result 'merged-for-review' $upstream $branch @()
