param(
    [string]$Namespace = "progressive-django",
    [string]$RolloutName = "django-rollout",
    [string]$ContainerName = "django",
    [string]$Image = "django-progressive:v1"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================="
Write-Host "  Canary Reset -> v1"
Write-Host "============================================="

Write-Host ""
Write-Host "[1/3] Current rollout image..."
$currentImage = kubectl get rollout $RolloutName -n $Namespace -o jsonpath="{.spec.template.spec.containers[0].image}"
Write-Host "Current image: $currentImage"

Write-Host ""
Write-Host "[2/3] Resetting rollout image to $Image ..."
$patch = "[{`"op`":`"replace`",`"path`":`"/spec/template/spec/containers/0/image`",`"value`":`"$Image`"}]"

$patchFile = [System.IO.Path]::GetTempFileName()
try {
    Set-Content -Path $patchFile -Value $patch -Encoding ascii
    kubectl patch rollout $RolloutName -n $Namespace --type=json --patch-file $patchFile
}
finally {
    Remove-Item -Path $patchFile -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "[3/3] Verifying rollout image..."
$newImage = kubectl get rollout $RolloutName -n $Namespace -o jsonpath="{.spec.template.spec.containers[0].image}"
Write-Host "New image: $newImage"
if ($newImage -ne $Image) {
    Write-Error "Canary reset failed. Expected '$Image' but got '$newImage'."
}

Write-Host ""
Write-Host "Canary reset completed successfully."
Write-Host "Check rollout state with:"
Write-Host "kubectl get rollout $RolloutName -n $Namespace"
Write-Host "kubectl describe rollout $RolloutName -n $Namespace"
