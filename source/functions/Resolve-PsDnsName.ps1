function Resolve-PsDnsName
{

    <#
        .SYNOPSIS
            Performs DNS lookups for one or more record types with clean, deduplicated output.
            
        .DESCRIPTION
            Resolve-PsDnsName is a PowerShell wrapper around the DnsClient.NET library that queries
            DNS servers for common record types such as A, AAAA, CNAME, MX, TXT, NS, PTR, SRV, and SOA.
            By default, it mimics the behaviour of Resolve-DnsName, returning CNAME, A, and AAAA records.
            
            The function supports specifying one or more record types, choosing a DNS server, disabling
            caching, and toggling between clean output (DomainName, RecordType, Data) and raw results
            for diagnostic purposes.

            This makes it useful both for quick checks (e.g. "what IPs does this host resolve to?")
            and deeper troubleshooting (e.g. "show me all MX and TXT records for a domain").

            Note that output is different to Resolve-DnsName

        .EXAMPLE
            Resolve-PsDnsName -Name "google.com"

            #### DESCRIPTION
            Queries the default DNS server (1.1.1.1) for CNAME, A, and AAAA records of google.com.
            Returns a clean table of results similar to Resolve-DnsName.

            #### OUTPUT
            DomainName   RecordType Data
            ----------   ---------- ----
            google.com.  A          142.251.221.78
            google.com.  AAAA       2404:6800:4006:809::200e
            
        .NOTES
            Author: Adrian Andersson
            
    #>

    [CmdletBinding()]
    PARAM(
        #DNS name or entry we are querying
        [Parameter(Mandatory)]
        [Alias('DnsName')]
        [string]$Name,
        #Record Type(s) we want to look up
        [Parameter()]
        [ValidateSet('ANY','A','AAAA','CNAME','MX','NS','PTR','SOA','SRV','TXT')]
        [Alias('Type')]
        [string[]]$RecordType = @('CNAME','A','AAAA'),
        #DNS Resolver to use.
        [Parameter()]
        [Alias('Server')]
        [String]$DnsServer = '1.1.1.1',
        #Switch to bypass any local cache
        [switch]$NoCache,
        #Switch to return the raw records and not the clean looking summary version
        [switch]$RawResult
    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        #Return the sent variables when running debug
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        
        Import-DnsClientDll

        $Answers = [System.Collections.Generic.List[object]]::new()

        $CustomSelect = @(
            'DomainName'
            'RecordType'
            @{
                Name = 'Data'
                Expression = {
                    $recordType = $_.RecordType
                    $data = $_
                    switch ($recordType) {
                        'CNAME' {$data.CanonicalName}
                        'MX' {$data.Exchange}
                        'TXT' {$data.Text}
                        'SOA' {$data.MName}
                        Default {$data.Address}
                    }
                }
            }
        )
    }
    
    process{
        <#
        if($DnsServer)
        {
            $client = [DnsClient.LookupClient]::new([System.Net.IPAddress]::Parse($DnsServer))
        }else{
            $client = [DnsClient.LookupClient]::new()
        }
        #>
        if ($DnsServer) {
            $options = [DnsClient.LookupClientOptions]::new([System.Net.IPAddress]::Parse($DnsServer))
        }else{
            $options = [DnsClient.LookupClientOptions]::new()
        }

        if ($NoCache) {
            Write-Verbose 'PsDnsClient.Resolve-PsDnsName: Setting noCache option'
            $options.UseCache = $false
        }

        $client = [DnsClient.LookupClient]::new($options)

        Write-Verbose "PsDnsClient.Resolve-PsDnsName: DNS Server $($client.NameServers[0].ToString())" 
        ForEach($Rtype in $RecordType)
        {
            Write-Verbose "PsDnsClient.Resolve-PsDnsName: Checking DNS Type: $RType"
            $queryType = [DnsClient.QueryType]::$Rtype
            try{
            $result = $client.Query($Name,$queryType)
            $global:dbgClient = $client
            $global:dbgResult = $result
            $result.Answers.foreach{
                $global:debugDNS = $_
                $Answers.Add($_)
                <#
                [PSCustomObject]@{
                    Name = $_.DomainName
                    RecordType = $_.RecordType
                    Data = $_.ToString()
                }#>
            }
            }catch{
                Write-Error "DNS Query failed: $_"
            }
        }
        #$Answers.ToArray()|Select-Object -Unique

        if(!$RawResult)
        {
            $Answers.ToArray()|Select-Object $CustomSelect -Unique
            <#
            $Answers.ToArray().ForEach{
                if ($_.RecordType -eq 'CNAME') {
                    [PSCustomObject]@{
                        DomainName = $_.DomainName.ToString()
                        RecordType = $_.RecordType.ToString()
                        CanonicalName = $_.CanonicalName.ToString()
                    }
                } elseif ($_.RecordType -eq 'A' -or $_.RecordType -eq 'AAAA') {
                    [PSCustomObject]@{
                        DomainName = $_.DomainName.ToString()
                        RecordType = $_.RecordType.ToString()
                        Address = $_.Address.ToString()
                    }
                } else {
                    [PSCustomObject]@{
                        DomainName = $_.DomainName.ToString()
                        RecordType = $_.RecordType.ToString()
                        Data = $_.ToString()
                    }
                }
            }| Sort-Object * -Unique
            #>
        }else{
            $Answers.ToArray()|Select-Object -Unique
        }
        
    }
}