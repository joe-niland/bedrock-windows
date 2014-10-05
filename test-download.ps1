function Download-File {
   param ( [string]$url, [string]$file )

   Write-Host "Downloading $url to $file"
   $downloader = new-object System.Net.WebClient
   $downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
   $downloader.DownloadFile($url, $file)
}

$bedrockAnsiblePath = Join-Path (Get-Location) "bedrock-ansible"

new-item -type directory $bedrockAnsiblePath

# Get the Windows modifications
  Download-File https://gist.githubusercontent.com/starise/e90d981b5f9e1e39f632/raw/d96002240cf82c60538652d8fcbffea46f256303/Vagrantfile ($bedrockAnsiblePath + "\Vagrantfile")
  # Download-File https://gist.githubusercontent.com/starise/e90d981b5f9e1e39f632/raw/778325547427aec53bdc38aed217b311f0cb68f4/windows.sh ($bedrockAnsiblePath + "\windows.sh")