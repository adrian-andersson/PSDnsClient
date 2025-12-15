function Import-DnsClientDll
{

    <#
        .SYNOPSIS
            Private Helper Function to help check and load the DnsClient DLL file
            
        .DESCRIPTION
            Checks if the DnsClient library is already loaded.
            If it isn't loaded. Try to locate where the DLL is located and add it as a type.
            This function expects to be called either privately at the top of a function file, or with dot sourcing for development and testing.

            
        .NOTES
            Author: Adrian Andersson
            
    #>

    [CmdletBinding()]
    PARAM(

    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        #Return the sent variables when running debug
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
    }
    
    process{
        $Check = [AppDomain]::CurrentDomain.GetAssemblies().where{$_.ManifestModule.name -eq 'dnslookup.dll'}
        if (!$Check)
        {
            Write-Warning 'PsDnsClient.Import-DnsClientDll: Not Loaded. Need to import'
            if ($MyInvocation.MyCommand.Path -like "*.psm1") {
                Write-Verbose 'PsDnsClient.Import-DnsClientDll: Running Inside Module'
                #In this scenario, we need to load from the module directory
                $ModulePath = $MyInvocation.MyCommand.Module.ModuleBase
                
                $dllFolderPath = Join-Path -Path (Join-Path $ModulePath -ChildPath 'resource') -ChildPath 'dnsClient'
                
            } else {
                Write-Verbose 'PsDnsClient.Import-DnsClientDll: Running in Stand-Alone Script'
                #In this scenario, we need to try and load it from the source directory
                #This is useful, as it allows us to maintain this function for pester testing or development
                $ScriptPath = $MyInvocation.MyCommand.Path
                if($ScriptPath)
                {
                    $Parent = Split-Path $ScriptPath -Parent
                    $dllFolderPath = Join-Path -Path (Join-Path $Parent -ChildPath 'resource') -ChildPath 'dnsClient'
                }else{
                    $ThisPath = $(Get-Item .).Fullname
                    Write-Verbose "PsDnsClient.Import-DnsClientDll: Current Path: $ThisPath"
                    $ChildItems = Get-ChildItem .
                    if($ChildItems.Name -contains 'source')
                    {
                        Write-Verbose 'PsDnsClient.Import-DnsClientDll: Found Source Folder'
                        $dllFolderPath = Join-Path -Path (Join-Path -Path (Join-Path $ThisPath -ChildPath 'source') -ChildPath 'resource')-ChildPath 'dnsClient'
                    }elseIf($ChildItems.Name -contains 'resource'){
                        Write-Verbose 'PsDnsClient.Import-DnsClientDll: Found resource Folder'
                        $dllFolderPath = Join-Path -Path (Join-Path -Path $ThisPath -ChildPath 'resource')-ChildPath 'dnsClient'
                    }else{
                        throw "PsDnsClient.Import-DnsClientDll: No reference point to find files"
                    }
                }
                

            }
            $dllPath = join-path -Path $dllFolderPath -ChildPath 'DnsClient.dll'
            Write-Verbose "PsDnsClient.Import-DnsClientDll: Attempt to Load DLL from: $dllPath"
            if(!(Test-Path $dllPath))
            {
                throw "PsDnsClient.Import-DnsClientDll: Unable to locate DnsClient.dll dependency. Looked here: $dllPath"
            }else{
                Add-Type -Path $dllPath
            }
        }else{
            Write-Verbose 'PsDnsClient.Import-DnsClientDll: Library already available. DLL Already loaded '
        }
    }
}