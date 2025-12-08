function CheckExistingFile {
    param (
        [string]$filepath
    )

    # checks to see if there's a local list already created
    try {
        $ExistingFile = Get-Content $FilePath -ErrorAction Stop
        Write-Host "[OK] Imported existing local list with $($ExistingFile.count) Domains" -ForegroundColor Green
    } catch {
        $ExistingFile = $null
        Write-Host "[WARN] Did not find existing list locally, will create new file" -ForegroundColor Yellow
    }

    return ,$ExistingFile
}

function ReadRemoteList {
    param (
        [string]$uri
    ) 
    # Reads the existing list from popcar2's repo
    try {
        $response = Invoke-WebRequest -Uri $uri -ErrorAction Stop
        if ($response.statuscode -eq '200') {
            write-host "[OK] Invoke-WebRequest was successful" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Status code is '$($response.statuscode)' with message '$($response.StatusDescription)'"
        }
    } catch {
        Write-Host "[ERROR] failed to download blacklist" -ForegroundColor Red
    }

    return $response
}

function ExtractDomains {
    param (
        [string]$response,
        [string]$pattern,
        [string]$replacefront,
        [string]$replaceback
    )
 
    $lines = $response -split "`n"
    if($pattern -eq '^\*\:\/\/(?:\*\.)?(.*?)\/.*$' -or $pattern -eq '^\*\:\/\/(.*?)\/.*$'){
        $Domains = $lines | Where-Object { $_ -match "$pattern" } | ForEach-Object {$_ -replace "$pattern",'$1'}
    }else{
        $Domains = $lines | Where-Object { $_ -match "$pattern" } | ForEach-Object { $_ -replace "$replacefront",'' -replace "$replaceback",''}
    }
    $ExtractedDomains = @()
    
    ForEach($Domain in $Domains){
        $ExtractedDomains += ($Domain -split "/")[0]
    }
    
    $ExtractedDomains = $ExtractedDomains | Sort-Object | Get-Unique
    
    if ($ExtractedDomains){
        Write-Host "[OK] Extracted $($ExtractedDomains.count) unique Domains" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] No domains were extracted using the pattern '$pattern'" -ForegroundColor Red
    }

    return ,$ExtractedDomains
}

function CompareDomains {
    param (
        [array]$ExtractedDomains,
        [array]$ExistingFile,
        [string]$FilePath
    )
    $continue = $false

    if($ExtractedDomains.count -gt $ExistingFile.count){
        $continue = $true
    } elseif ($ExtractedDomains.count -eq $ExistingFile.count){
        if(Compare-Object -ReferenceObject $ExistingFile -DifferenceObject $ExtractedDomains){
            $continue = $true
        } else {
            Write-Host "[OK] No new sites detected" -ForegroundColor Green
            $continue = $false
        }
    } else {
        $continue = $false
        Write-Host "[ERROR] Extracted URL count is less than the local list '$FilePath'" -ForegroundColor Red
    }

    return $continue
}

function SaveDomains {
    param (
        [array]$ExtractedDomains,
        [string]$FilePath
    )

    try {
        $ExtractedDomains | Set-Content "$FilePath" -Force -ErrorAction Stop
        Write-Host "[OK] Exported Domain list to '$FilePath'" -ForegroundColor Green
        try {
            & git add "$filepath"            
        } catch {
            Write-Host "[ERROR] Failed to push to Github" -ForegroundColor Red
        }
    } catch {
        Write-Host "[ERROR] Failed to export URL list to '$FilePath'" -ForegroundColor Red
    }
}

function GithubPush {
    try {
        & git commit -m "Site list update $(get-date -format MM/dd/yyyy)"
        & git push
        Write-Host "[OK] Pushed changes to Github" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to push to Github" -ForegroundColor Red
    }
}