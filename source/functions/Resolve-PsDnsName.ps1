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
            resolve-psDnsName -Name 'google.com'

            #### DESCRIPTION
            Use defaults and do a simple Domain Resolution

            #### OUTPUT
            DomainName      RecordType Data
            ----------      ---------- ----
            www.google.com.          A 142.250.195.228
            www.google.com.       AAAA 2404:6800:4006:812::2004

        .EXAMPLE 
            resolve-psDnsName -Name 'www.google.com' -RawResult

            #### DESCRIPTION
            Same as above, but give the raw DNS results, useful if you want more comprehensive debugging, but note you may get duplicates

            #### OUTPUT

            Address           : 142.250.195.132
            DomainName        : www.google.com.
            RecordType        : A
            RecordClass       : IN
            TimeToLive        : 178
            InitialTimeToLive : 178
            RawDataLength     : 4

            Address           : 2404:6800:4006:801::2004
            DomainName        : www.google.com.
            RecordType        : AAAA
            RecordClass       : IN
            TimeToLive        : 299
            InitialTimeToLive : 299
            RawDataLength     : 16

        .EXAMPLE
            resolve-PsDnsName -Name 'google.com' -Server 8.8.8.8 -recordType 'A','AAAA','CNAME','TXT','MX','SOA' -NoCache

            #### DESCRIPTION
            Queries the default DNS server (1.1.1.1) for 'A','AAAA','CNAME','TXT','MX', and 'SOA' records of google.com.
            Returns a clean table of results similar to Resolve-DnsName.

            #### OUTPUT
            DomainName  RecordType Data
            ----------  ---------- ----
            google.com.          A 142.250.195.142
            google.com.       AAAA 2404:6800:4006:812::200e
            google.com.        TXT onetrust-domain-verification=de01ed21f2fa4d8781cbc3ffb89cf4ef
            google.com.        TXT globalsign-smime-dv=CDYX+XFHUw2wml6/Gb8+59BsH31KzUr6c1l2BPvqKX8=
            google.com.        TXT google-site-verification=4ibFUgB-wXLQ_S7vsXVomSTVamuOXBiVAzpR5IZ87D0
            google.com.        TXT docusign=1b0a6754-49b1-4db5-8540-d2c12664b289
            google.com.        TXT google-site-verification=TV9-DBe4R80X4v0M4U_bd_J9cpOJM0nikft0jAgjmsQ
            google.com.        TXT MS=E4A68B9AB2BB9670BCE15412F62916164C0B20BB
            google.com.        TXT facebook-domain-verification=22rm551cu4k0ab0bxsw536tlds4h95
            google.com.        TXT apple-domain-verification=30afIBcvSuDV2PLX
            google.com.        TXT docusign=05958488-4752-4ef2-95eb-aa7ba8a3bd0e
            google.com.        TXT v=spf1 include:_spf.google.com ~all
            google.com.        TXT google-site-verification=wD8N7i1JTNTkezJ49swvWW48f8_9xveREV4oB-0Hf5o
            google.com.        TXT cisco-ci-domain-verification=47c38bc8c4b74b7233e9053220c1bbe76bcc1cd33c7acf7acd36cd6a5332004b
            google.com.         MX smtp.google.com.
            google.com.        SOA ns1.google.com.
            
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
        [String]$DnsServer,
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
            $result.Answers.foreach{
                $Answers.Add($_)
        
            }
            }catch{
                Write-Error "DNS Query failed: $_"
            }
        }

        if(!$Answers)
        {
            Throw 'PsDnsClient.Resolve-PsDnsName: No Answers from query. Check query name and try again'
        }

        if(!$RawResult)
        {
            $Answers.ToArray()|Select-Object $CustomSelect -Unique
        }else{
            $Answers.ToArray()|Select-Object -Unique
        }
        
    }
}