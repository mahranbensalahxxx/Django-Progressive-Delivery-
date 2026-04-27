param(
    [string]$Namespace = "progressive-django",
    [string]$ServiceName = "django-service"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================="
Write-Host "  Blue-Green Switch -> GREEN (v2)"
Write-Host "============================================="

Write-Host ""
Write-Host "[1/3] Checking current active version..."
$current = kubectl get service $ServiceName -n $Namespace -o jsonpath="{.spec.selector.version}"
Write-Host "Current active version: $current"

Write-Host ""
Write-Host "[2/3] Ensuring green deployment is ready..."
kubectl rollout status deployment/django-green -n $Namespace --timeout=120s

Write-Host ""
Write-Host "[3/3] Switching service selector to green..."
$patch = @{ spec = @{ selector = @{ version = "green" } } } | ConvertTo-Json -Compress
$patchFile = [System.IO.Path]::GetTempFileName()
try {
    Set-Content -Path $patchFile -Value $patch -Encoding ascii
    kubectl patch service $ServiceName -n $Namespace --type=merge --patch-file $patchFile
}
finally {
    Remove-Item -Path $patchFile -ErrorAction SilentlyContinue
}

$newVersion = kubectl get service $ServiceName -n $Namespace -o jsonpath="{.spec.selector.version}"
Write-Host ""
Write-Host "Done. Active version is now: $newVersion"
if ($newVersion -ne "green") {
    Write-Error "Switch failed. Expected active version 'green' but got '$newVersion'."
}
Write-Host "Verify endpoint with:"
Write-Host "kubectl port-forward service/$ServiceName 8000:80 -n $Namespace"
