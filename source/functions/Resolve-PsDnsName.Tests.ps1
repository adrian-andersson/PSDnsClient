BeforeAll{

    #Reference Current Path
    $currentPath = $(get-location).path
    $sourcePath = join-path -path $currentPath -childPath 'source'

    $dependencies = [ordered]@{
        private = @('Import-DnsClientDll.ps1')
    }

    $dependencies.GetEnumerator().ForEach{
        $DirectoryRef = join-path -path $sourcePath -childPath $_.Key
        $_.Value.ForEach{
            $ItemPath = join-path -path $DirectoryRef -childpath $_
            $ItemRef = get-item $ItemPath -ErrorAction SilentlyContinue
            if($ItemRef){
                write-verbose "Dependency identified at: $($ItemRef.fullname)"
                . $ItemRef.Fullname
            }else{
                write-warning "Dependency not found at: $ItemPath"
            }
        }
    }
    
    #Load This File
     $fileName = $PSCommandPath.Replace('.Tests.ps1','.ps1')
     $functionName = 'Resolve-PsDnsName'
    . $fileName
}

Describe 'Check Clean Environment' {
    BeforeAll {
        write-warning "PSCommandPath: $psCommandPath; scriptToLoad: $($PSCommandPath.Replace('.Tests.ps1','.ps1'))"
    }
    It 'Should have loaded the script directly, not from the module' {
        $PSCommandPath.Replace('.Tests.ps1','.ps1')|should -be $fileName
        (get-command $functionName).source |should -BeNullOrEmpty
    }
}

Describe 'Resolve-PsDnsName' {
    Context 'Parameter validation' {
        It "defaults RecordType to CNAME,A,AAAA" {
            $params = (Get-Command Resolve-PsDnsName).Parameters['RecordType'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $params.ValidValues | Should -Contain 'A'
            $params.ValidValues | Should -Contain 'AAAA'
            $params.ValidValues | Should -Contain 'CNAME'
            $params.ValidValues | Should -Contain 'MX'
            $params.ValidValues | Should -Contain 'NS'
            $params.ValidValues | Should -Contain 'PTR'
            $params.ValidValues | Should -Contain 'SOA'
            $params.ValidValues | Should -Contain 'SRV'
            $params.ValidValues | Should -Contain 'TXT'
        }
    }
}


Context 'Default behaviour' {
        It 'returns correct object items when -RawResult is used' {
            # Mock DNS client result
            $result = Resolve-PsDnsName -Name 'google.com'
            $result | Should -Not -BeNullOrEmpty
            $result[0].DomainName | Should -Not -BeNullOrEmpty
            $result[0].RecordType | Should -Not -BeNullOrEmpty
            $result[0].Data | Should -Not -BeNullOrEmpty
    }
}

Context 'Switch behaviour' {
        It 'returns correct object items when -RawResult is used' {
            # Mock DNS client result
            $result = Resolve-PsDnsName -Name 'google.com' -RawResult
            $result | Should -Not -BeNullOrEmpty
            $result[0].TimeToLive | Should -BeGreaterOrEqual 1
            $result[0].Address | Should -Not -BeNullOrEmpty
            $result[0].RecordType | Should -Not -BeNullOrEmpty
            $result[0].RecordClass | Should -Not -BeNullOrEmpty
    }

    Context 'Error handling' {
        It 'writes error when DNS query fails' {
            { Resolve-PsDnsName -Name 'bad.domain' } | Should -Throw
        }
    }
}
