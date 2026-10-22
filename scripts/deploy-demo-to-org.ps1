<#
  Deploys the whole Fidelity demo (phase 1 core + phase 2 reports/dashboard) to another org.

  Usage:
    .\scripts\deploy-demo-to-org.ps1 -OrgAlias fidelityAgent
    .\scripts\deploy-demo-to-org.ps1 -OrgAlias fidelityAgent -DryRun      # validate only, changes nothing
    .\scripts\deploy-demo-to-org.ps1 -OrgAlias myProd -RunTests           # production needs the Apex tests

  Log in first:  sf org login web --alias <alias>
#>
param(
    [Parameter(Mandatory = $true)][string]$OrgAlias,
    [switch]$DryRun,
    [switch]$RunTests
)

# The sf CLI writes update notices to stderr; don't treat those as errors. Failures are checked from the JSON result instead.
$ErrorActionPreference = "Continue"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Deploy($manifest) {
    $args_ = @("project", "deploy", "start", "--manifest", $manifest, "--target-org", $OrgAlias, "--json")
    if ($DryRun) { $args_ += "--dry-run" }
    if ($RunTests -and $manifest -like "*1-core*") { $args_ += @("--test-level", "RunSpecifiedTests", "--tests", "MeetingSchedulerControllerTest") }
    else { $args_ += @("--test-level", "NoTestRun") }
    $r = & sf @args_ 2>$null | ConvertFrom-Json
    Write-Host ("{0}: {1} ({2}/{3} components)" -f (Split-Path $manifest -Leaf), $r.result.status, $r.result.numberComponentsDeployed, $r.result.numberComponentsTotal)
    $r.result.details.componentFailures | ForEach-Object { Write-Host ("  FAIL {0} {1}: {2}" -f $_.componentType, $_.fullName, $_.problem) -ForegroundColor Red }
    $r.result.details.runTestResult.failures | ForEach-Object { Write-Host ("  TEST FAIL {0}: {1}" -f $_.methodName, $_.message) -ForegroundColor Red }
    if (-not $r.result -or $r.result.status -ne "Succeeded") { throw "Deployment of $manifest did not succeed." }
}

Write-Host "Target org: $OrgAlias   dry run: $DryRun" -ForegroundColor Cyan
Deploy "manifest/fidelity-deploy-1-core.xml"      # must finish before phase 2 (reports need the custom report type)
Deploy "manifest/fidelity-deploy-2-reports.xml"

if (-not $DryRun) {
    foreach ($ps in "Fidelity_Sales_User", "Fidelity_Sales_Manager") {
        sf org assign permset --name $ps --target-org $OrgAlias 2>&1 | Select-String "Fidelity|rror" | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
    }
}

Write-Host @"

Deployed. Do these by hand in the target org:
  1. Setup > Deliverability > Access level = All email
  2. Setup > Web-to-Lead > enable (only if you use the web form)
  3. Add users to Calling_Queue and Sales_Queue
  4. Turn on field history for Lead Status
  5. Recreate demo data (leads, the Conference 2026 campaign)
  6. The scheduled flow Lead_No_Response_Follow_Up has a fixed start date (2026-10-22); change it in the flow file before deploying after that date.
"@ -ForegroundColor Yellow
