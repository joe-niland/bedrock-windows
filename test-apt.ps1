$installDir = "originalmind_v3"

  $bedrockAnsiblePath = Join-Path (Get-Location) "bedrock-ansible"

  $vagrantFilepath = ($bedrockAnsiblePath + "\Vagrantfile")
  
  $regex = [regex] '(?s)config.vm.provider.+?end'

  Write-Host $vagrantFilepath

  $vagrantSetAptMirror = "config.vm.provision ""shell"", inline: ""sudo sed -i.backup 's/archive.ubuntu.com/$aptMirror/g;s/security.ubuntu.com/$aptMirror/g' /etc/apt/sources.list"""

  $a = gc $vagrantFilepath
  $m = $regex.Match($a)
  $m[0].Value

  # (gc $vagrantFilepath -raw).Replace($m[0].Value, $m[0].Value + $vagrantSetAptMirror)

  # (gc $vagrantFilepath) -match $regex

  (gc $vagrantFilepath -raw) | % { $_ -replace '(?s)(?<provider>config.vm.provider.+?end)', ('${provider}' + "`n`n$vagrantSetAptMirror") }
  # -match $regex