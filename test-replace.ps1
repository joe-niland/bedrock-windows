  $installDir = "originalmind_v3"

  $bedrockAnsiblePath = Join-Path (Get-Location) "bedrock-ansible"

  $vagrantFilepath = ($bedrockAnsiblePath + "\Vagrantfile")
  
  $hostName = "$installDir.dev" # [System.Web.HttpUtility]::UrlEncode($installDir)
  Write-Host "Host name: $hostName"
  $projectDir = $installDir

  # Replace values
  (gc $vagrantFilepath) | ForEach-Object {
    Write-Host $_
    if ($_.ToString() -like "*config.vm.hostname*") {
        $_.replace('example.dev', $hostName)
    } elseif ($_.ToString() -like "*config.vm.synced_folder*") {
        $_.replace('example.dev', $projectDir)
    } else {
        $_
    }
    Write-Host $_
  } | sc $vagrantFilepath