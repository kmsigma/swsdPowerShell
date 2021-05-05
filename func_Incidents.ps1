<#
.Synopsis
    Convert a hashtable to a query string
.DESCRIPTION
    Converts a passed hashtable to a query string based on the key:value pairs.
.EXAMPLE
    $UriParameters = @{}
    PS > $UriParameters.Add("PageSize", 20)
    PS > $UriParameters.Add("PageIndex", 1)

    PS > $UriParameters

Name                           Value
----                           -----
PageSize                       20
PageIndex                      1

    PS > $UriParameters | ConvertTo-QueryString

    PageSize=20&PageIndex=1
.OUTPUTS
    string object in the form of "key1=value1&key2=value2..."  Does not include the preceeding '?' required for many URI calls
.NOTES
    This is bascially the reverse of [System.Web.HttpUtility]::ParseQueryString

    This is included here just to have a reference for it.  It'll typically be defined 'internally' within the `begin` blocks of functions
#>
function ConvertTo-QueryString {
    param (
        # Hashtable containing segmented query details
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]$Parameters
    )
    $ParameterStrings = @()
    $Parameters.GetEnumerator() | ForEach-Object {
        $ParameterStrings += "$( $_.Key )=$( $_.Value )"
    }
    $ParameterStrings -join "&"
}


function Get-SwsdIncident {
    [CmdletBinding(
        SupportsShouldProcess = $true, 
        PositionalBinding = $false,
        HelpUri = 'https://documentation.solarwinds.com/en/success_center/swsd/content/apidocumentation/incidents.htm',
        ConfirmImpact = 'Medium')
    ]
    Param
    (
        # Optional page size grab for the call to the API. (Script defaults to 1000 per batch)
        # Larger page sizes generally complete faster, but consume more memory
        [Parameter(
            Mandatory = $false
        )]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(1, 100)]
        [int]$BatchSize = 10,

        # JSON Web Token
        [Parameter(
            Mandatory = $false
        )]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$JsonWebToken = $Global:JsonWebToken

    )
    begin { 
        # Uri Base - set to 'apieu.samanage.com' if you are in the European Union
        # Be sure to include the trailing slash (/)
        $UriBase = "https://api.samanage.com/"
        
        # the API's URI that we'll be connecting to
        # Be sure to OMIT the initial slash (/)
        $Uri = 'incidents.json'
        $Headers = @{}
        $Headers["Accept"] = 'application/vnd.samanage.v2.1+json'
        $Headers["X-Samanage-Authorization"] = "Bearer $JsonWebToken"
        
        $UriParameters = @{}
        $UriParameters["page"] = 1

        if ( $BatchSize ) {
            $UriParameters["per_page"] = $BatchSize
        }
    }
    process {
        # Just used for the counter
        $TotalReturned = 0
        Write-Progress -Activity "Querying $( $UriBase + $Uri )" -CurrentOperation "Initial Request"
        do {
            $Response = Invoke-RestMethod -Uri ( $UriBase + $Uri + '?' + ( $UriParameters | ConvertTo-QueryString ) ) -Headers $Headers -Method Get -ResponseHeadersVariable ResponseHeaders
            $TotalReturned += $Response.Count # this is just for the counter
            # For some reason I don't know each of the response headers are returned as an array - even if they only have a single element - hence the [0]
            # Since we only need the total results once, I can see if the variable exists and then set it that one time only.
            # I don't think this saves anything computationally, but it's still my habit to not update unchanged variables
            if ( -not ( $TotalResults ) ) {
                $TotalResults = [int]( $ResponseHeaders.'X-Total-Count'[0] )
            }
            Write-Progress -Activity "Querying $( $UriBase + $Uri )" -CurrentOperation "Found $TotalReturned of $TotalResults" -PercentComplete ( ( $TotalReturned / $TotalResults ) * 100 )
            if ( $Response ) {
                $Response
                $UriParameters["page"]++
            }
        } until ( $ResponseHeaders.'X-Current-Page' -eq $ResponseHeaders.'X-Total-Pages' )
        Write-Progress -Activity "Querying $( $UriBase + $Uri )" -Completed
    }
    end {
        # Nothing to see here
    }
}