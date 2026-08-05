$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
Write-Host "Server running at http://localhost:8080/"

$webRoot = "D:\ai models\Expense-OS-Mobile\build\web"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $response = $context.Response
    $requestPath = $context.Request.Url.LocalPath

    if ($requestPath -eq "/") { $requestPath = "/index.html" }
    $localFilePath = Join-Path $webRoot $requestPath.TrimStart('/')

    if (Test-Path $localFilePath -PathType Leaf) {
        $bytes = [System.IO.File]::ReadAllBytes($localFilePath)
        
        if ($localFilePath.EndsWith(".html")) { $response.ContentType = "text/html" }
        elseif ($localFilePath.EndsWith(".js")) { $response.ContentType = "application/javascript" }
        elseif ($localFilePath.EndsWith(".css")) { $response.ContentType = "text/css" }
        elseif ($localFilePath.EndsWith(".json")) { $response.ContentType = "application/json" }
        elseif ($localFilePath.EndsWith(".png")) { $response.ContentType = "image/png" }

        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $response.StatusCode = 404
    }
    $response.Close()
}
