$response = Invoke-WebRequest -Uri "http://localhost:3000/api/exercises/subject/1" -Headers @{"Authorization"="Bearer test"} -UseBasicParsing
Write-Host "Status Code: $($response.StatusCode)"
Write-Host "Content:"
$response.Content
