#Requires -Version 7.4

param(
  [Parameter(Mandatory)]
  [string]$SqliteSdk
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$nl2sqlRevision = 'af0c79c7f516dfb9da2e8c08d0a7cc67254c8b2d'

$sdk = (Resolve-Path -LiteralPath $SqliteSdk).ProviderPath
foreach ($file in @('include/sqlite3.h', 'lib/sqlite3.lib', 'bin/sqlite3.dll')) {
  if (!(Test-Path -LiteralPath (Join-Path $sdk $file) -PathType Leaf)) {
    throw "The SQLite SDK is missing $file."
  }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('sqlc-nl2sql-audit-' + [guid]::NewGuid().ToString('N'))
$example = Join-Path $work 'example'
$localDependencies = Join-Path $example '.audit-local'
$nl2sql = Join-Path $localDependencies 'nl2sql'
$binding = Join-Path $localDependencies 'sqlite'
New-Item -ItemType Directory -Path $localDependencies | Out-Null
foreach ($part in @('app', 'db', 'moon.mod')) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $part) -Destination $example -Recurse
}

git clone --quiet https://github.com/young9682/nl2sql.mbt.git $nl2sql
git -C $nl2sql checkout --quiet --detach $nl2sqlRevision
$checkedOutRevision = git -C $nl2sql rev-parse HEAD

$archive = Join-Path $localDependencies 'sqlite-0.2.1.zip'
Invoke-WebRequest 'https://download.mooncakes.io/user/mizchi/sqlite/0.2.1.zip' -OutFile $archive
$bindingHash = '2A5EA87339DDEFC5055BD64C8F2F34D2CB9E3B8B0D393BC4207AA459B4AEEAAD'
if ((Get-FileHash -LiteralPath $archive).Hash -ne $bindingHash) {
  throw 'The mizchi/sqlite package checksum does not match the tested release.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $binding
moon -C $binding fmt
$bindingPackage = Join-Path $binding 'moon.pkg'
$legacyTargets = [IO.File]::ReadAllText($bindingPackage)
[IO.File]::WriteAllText(
  $bindingPackage,
  $legacyTargets.Replace('supported_targets = [ "native", "js" ]', 'supported_targets = "+native+js"')
)
'members = [".", ".audit-local/nl2sql", ".audit-local/sqlite"]' |
  Set-Content -Encoding utf8NoBOM -LiteralPath (Join-Path $example 'moon.work')

$include = $env:INCLUDE
$lib = $env:LIB
$path = $env:PATH
try {
  $env:INCLUDE = (Join-Path $sdk 'include') + ';' + $include
  $env:LIB = (Join-Path $sdk 'lib') + ';' + $lib
  $env:PATH = (Join-Path $sdk 'bin') + ';' + $path
  moon -C $example update
  moon -C $example check --target native app
  moon -C $example build --quiet --target native app

  $app = Join-Path $example '_build/native/debug/build/example_sqlite_native/app/app.exe'
  Push-Location $work
  try {
    & $app --write-db
    $before = (Get-FileHash -LiteralPath 'accounts.db' -Algorithm SHA256).Hash.ToLowerInvariant()
    & $app --audit-db accounts.db > audit-result.json
    $after = (Get-FileHash -LiteralPath 'accounts.db' -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($before -ne $after) {
      throw 'The audit changed the database.'
    }

    $result = Get-Content -LiteralPath 'audit-result.json' -Raw | ConvertFrom-Json
    $rows = ConvertTo-Json -InputObject $result.result.rows -Depth 5 -Compress
    $params = ConvertTo-Json -InputObject $result.params -Depth 5 -Compress
    if ($rows -cne '[[["Integer","1"],["Text","Alice Smith"],["Text","alice.smith@example.com"]]]' -or
        $params -cne '[["Integer","1"]]' -or $result.result.truncated -ne $false) {
      throw 'The audit output differs from the expected surviving account.'
    }

    [ordered]@{
      nl2sql_revision = $checkedOutRevision
      moonbit_compiler = (moonc -v)
      database_sha256_before_audit = $before
      database_sha256_after_audit = $after
    } | ConvertTo-Json | Set-Content -Encoding utf8NoBOM -LiteralPath 'audit-verification.json'

    Get-Content -LiteralPath 'audit-result.json'
    "PASS: audited the surviving account and verified an unchanged SQLite SHA-256."
    "Audit JSON: $(Join-Path $work 'audit-result.json')"
    "Verification JSON: $(Join-Path $work 'audit-verification.json')"
  } finally {
    Pop-Location
  }
} finally {
  $env:INCLUDE = $include
  $env:LIB = $lib
  $env:PATH = $path
}
