# Valy Premium library - shared by valy-helper.ps1 and Install-Core.ps1.
# This is a SIGNED critical file: ValyLauncher.exe refuses to start if it was changed.
#
# premium.valylic (v2) = JSON { v, lic, sig, pack }
#   lic  = base64 of the license JSON that the seller signed with the RSA private key
#          { id (Machine ID), name, edition, issued, salt, iv, ph (sha256 of the plain pack), ch (sha256 of the encrypted pack), wm, pv }
#   sig  = RSA-SHA256 signature of lic
#   pack = AES-256-CBC encrypted pack  { js: <premium code>, files: { name: base64 } }
# The AES key is derived from THIS PC's Machine ID, so the pack opens only on the PC the license was made for.
# The premium code is decrypted in memory only and is never written to disk.

function Get-MachineId{
  $g=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid).MachineGuid
  $h=[Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes('valy|'+$g))
  $x=(($h|ForEach-Object{$_.ToString('X2')}) -join '').Substring(0,16)
  return ($x.Substring(0,4)+'-'+$x.Substring(4,4)+'-'+$x.Substring(8,4)+'-'+$x.Substring(12,4))
}
function Get-Sha256Hex([byte[]]$b){
  $h=[Security.Cryptography.SHA256]::Create().ComputeHash($b)
  return (($h|ForEach-Object{$_.ToString('x2')}) -join '')
}
# Returns $null when anything is wrong, otherwise an object with .lic (license info), .js (premium code) and .files (name -> base64)
function Open-Premium([string]$file,[string]$pubFile){
  try{
    if(-not (Test-Path -LiteralPath $file)){ return $null }
    $f=(Get-Content -LiteralPath $file -Raw -Encoding UTF8)|ConvertFrom-Json
    if($f.v -ne 2){ return $null }
    $licBytes=[Convert]::FromBase64String([string]$f.lic); $sig=[Convert]::FromBase64String([string]$f.sig)
    $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
    $rsa.FromXmlString((Get-Content -LiteralPath $pubFile -Raw))
    if(-not $rsa.VerifyData($licBytes,'SHA256',$sig)){ return $null }
    $j=[Text.Encoding]::UTF8.GetString($licBytes)|ConvertFrom-Json
    $mid=Get-MachineId
    if($j.id -ne $mid -or $j.edition -ne 'premium'){ return $null }
    $enc=[Convert]::FromBase64String([string]$f.pack)
    if((Get-Sha256Hex $enc) -ne [string]$j.ch){ return $null }
    $key=(New-Object Security.Cryptography.Rfc2898DeriveBytes(($mid+'|valy-pack-v2'),[Convert]::FromBase64String([string]$j.salt),50000)).GetBytes(32)
    $aes=[Security.Cryptography.Aes]::Create(); $aes.Mode='CBC'; $aes.Padding='PKCS7'; $aes.Key=$key; $aes.IV=[Convert]::FromBase64String([string]$j.iv)
    $plain=$aes.CreateDecryptor().TransformFinalBlock($enc,0,$enc.Length)
    if((Get-Sha256Hex $plain) -ne [string]$j.ph){ return $null }
    $pk=[Text.Encoding]::UTF8.GetString($plain)|ConvertFrom-Json
    return [pscustomobject]@{ lic=$j; js=[string]$pk.js; files=$pk.files }
  }catch{ return $null }
}
# Writes the pack's extra files (premium icons...) into the install folder. Only plain names, only .ico/.png.
function Install-PremiumFiles($pk,[string]$dir){
  if(-not $pk -or -not $pk.files){ return }
  $null=New-Item -ItemType Directory -Force -Path $dir
  foreach($p in $pk.files.PSObject.Properties){
    if($p.Name -notmatch '^[A-Za-z0-9_\-\.]+\.(ico|png)$'){ continue }
    [IO.File]::WriteAllBytes((Join-Path $dir $p.Name),[Convert]::FromBase64String([string]$p.Value))
  }
}
