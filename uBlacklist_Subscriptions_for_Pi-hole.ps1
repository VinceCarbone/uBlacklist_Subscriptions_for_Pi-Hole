Start-Transcript -Path "$PSScriptRoot\transcript.txt" -Force

# Imports the CSV file with the list of domain lists to process
if (test-path "$PSScriptRoot\DomainLists.csv") {    
    $DomainLists = Import-Csv -Path "$PSScriptRoot\SubscriptionLists.csv"
} else {
    Write-Host "[ERROR] DomainLists.csv not found in '$PSScriptRoot'" -ForegroundColor Red
    exit
}

ForEach($DomainList in $DomainLists){        
    Write-Host "`nProcessing list: $($DomainList.name)" -ForegroundColor Cyan
    # imports the module and checks for existing file    
    import-module "$PSScriptRoot\extract-domains.psm1" -Force

    $ExistingFile = @(CheckExistingFile -filepath "$PSScriptRoot\$($DomainList.name).txt")
    $response = ReadRemoteList -uri $DomainList.uri

    # If it was able to read the remote file, it parses the response
    if ($response.StatusCode -eq '200'){        
        $ExtractedDomains =@(ExtractDomains -response $response.content -pattern $($DomainList.pattern) -replacefront $($DomainList.replacefront) -replaceback $($DomainList.replaceback))
        if ($ExtractedDomains){
            if ($ExistingFile){
                $continue = CompareDomains -ExtractedDomains $ExtractedDomains -ExistingFile $ExistingFile -FilePath "$PSScriptRoot\$($DomainList.name).txt"
            } else {
                $continue = $true
            }

            if ($continue){
                SaveDomains -ExtractedDomains $ExtractedDomains -FilePath "$PSScriptRoot\$($DomainList.name).txt"
                $GitHubPush = $true
            } else {
                $GitHubPush = $false
            }
        }
    }    
}

GithubPush

Stop-Transcript