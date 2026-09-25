$sshKey  = "C:\Users\danil\Downloads\ssh-key-2026-08-20.key"
$sshUser = "ubuntu@groovydescarga.duckdns.org"
$distPath = "$PSScriptRoot\dist.tar.gz"
$b64File  = "$PSScriptRoot\dist_b64.txt"

# Encode to base64 text file
[Convert]::ToBase64String([IO.File]::ReadAllBytes($distPath)) | Set-Content -NoNewline $b64File
Write-Host "Base64 file: $([Math]::Round((Get-Item $b64File).Length / 1KB)) KB"

# SCP the base64 text file — use -T to suppress shell output and -o BatchMode=yes
Write-Host "Uploading via scp..."
& scp -i $sshKey -o StrictHostKeyChecking=no -o LogLevel=ERROR -o BatchMode=yes -T $b64File "${sshUser}:/tmp/dist_b64.txt"
if ($LASTEXITCODE -ne 0) {
    Write-Host "SCP failed (exit $LASTEXITCODE)"
    exit 1
}
Write-Host "Upload OK. Decoding + extracting on server..."

# Decode and extract
& ssh -i $sshKey -o StrictHostKeyChecking=no -o LogLevel=ERROR -o BatchMode=yes -T $sshUser `
  "base64 -d /tmp/dist_b64.txt > /tmp/dist.tar.gz && tar -xzf /tmp/dist.tar.gz -C /var/www/groovydescarga && rm /tmp/dist_b64.txt /tmp/dist.tar.gz && echo DONE"
Write-Host "Exit code: $LASTEXITCODE"
