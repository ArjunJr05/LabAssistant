# Find large files in git repository
Write-Host "Finding largest files in repository..." -ForegroundColor Cyan

$largeFiles = git rev-list --objects --all | 
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
    Where-Object { $_ -match '^blob' } |
    ForEach-Object {
        $parts = $_ -split ' ', 4
        [PSCustomObject]@{
            SizeMB = [math]::Round([int]$parts[2] / 1MB, 2)
            SizeBytes = [int]$parts[2]
            File = $parts[3]
        }
    } |
    Sort-Object SizeBytes -Descending |
    Select-Object -First 20

Write-Host "`nTop 20 largest files in repository:" -ForegroundColor Yellow
$largeFiles | Format-Table -AutoSize

$totalSize = ($largeFiles | Measure-Object -Property SizeBytes -Sum).Sum
Write-Host "`nTotal size of top 20 files: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Green
