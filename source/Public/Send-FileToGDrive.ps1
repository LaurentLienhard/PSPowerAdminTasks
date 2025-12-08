function Send-FileToGDrive
{
    <#
    .SYNOPSIS
    Uploads a file to Google Drive using a service account certificate.

    .DESCRIPTION
    This function uploads a file to a specified Google Drive folder using a service account
    with a certificate file for authentication. It requires valid Google Cloud service account
    credentials and the target folder ID.

    .PARAMETER SourceFile
    The path to the file to upload to Google Drive.

    .PARAMETER CertFile
    The path to the service account certificate file (.p12 format).

    .PARAMETER CertPassword
    The password for the service account certificate.

    .PARAMETER Project
    The Google Cloud project ID.

    .PARAMETER ServiceAccount
    The service account email address (e.g., name@project.iam.gserviceaccount.com).

    .PARAMETER GDriveFolderId
    The folder ID on Google Drive where the file will be uploaded.

    .PARAMETER SupportsTeamDrives
    Indicates if the Google Drive supports team drives.

    .EXAMPLE
    $gdriveParams = @{
        CertFile            = "C:\certs\service-account.p12"
        CertPassword        = "notasecret"
        Project             = "my-project-id"
        ServiceAccount      = "sa@my-project.iam.gserviceaccount.com"
        GDriveFolderId      = "1AU-8ddowjYXJ9LF3WNS7pShyreHw0cES"
        SupportsTeamDrives  = $true
        SourceFile          = "C:\temp\report.csv"
    }

    Send-FileToGDrive @gdriveParams

    .NOTES
    Requires:
    - Valid Google Cloud service account certificate file
    - Google Drive API enabled in Google Cloud project
    - Service account with Google Drive access
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]$SourceFile,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]$CertFile,

        [Parameter(Mandatory = $true)]
        [String]$CertPassword,

        [Parameter(Mandatory = $true)]
        [String]$Project,

        [Parameter(Mandatory = $true)]
        [String]$ServiceAccount,

        [Parameter(Mandatory = $true)]
        [String]$GDriveFolderId,

        [Parameter()]
        [Boolean]$SupportsTeamDrives = $true
    )

    process
    {
        try
        {
            Write-Verbose "Preparing to upload file: $SourceFile"
            Write-Verbose "Service Account: $ServiceAccount"

            # Get the access token
            $accessToken = Get-GoogleDriveAccessToken -CertFile $CertFile -CertPassword $CertPassword `
                -Project $Project -ServiceAccount $ServiceAccount

            if (-not $accessToken)
            {
                throw "Failed to obtain access token from Google Cloud"
            }

            # Upload the file
            $uploadResult = Invoke-GoogleDriveUpload -AccessToken $accessToken -SourceFile $SourceFile `
                -FolderId $GDriveFolderId -SupportsTeamDrives $SupportsTeamDrives

            if ($uploadResult)
            {
                Write-Verbose "File successfully uploaded to Google Drive"
                Write-Verbose "File ID: $($uploadResult.id)"
                return $uploadResult
            }
            else
            {
                throw "Failed to upload file to Google Drive"
            }
        }
        catch
        {
            Write-Error "Error uploading file to Google Drive: $_"
            throw
        }
    }
}

function Get-GoogleDriveAccessToken
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$CertFile,

        [Parameter(Mandatory = $true)]
        [String]$CertPassword,

        [Parameter(Mandatory = $true)]
        [String]$Project,

        [Parameter(Mandatory = $true)]
        [String]$ServiceAccount
    )

    try
    {
        # Import the certificate
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            $CertFile,
            $CertPassword,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
        )

        # Create the assertion header
        $header = @{
            alg = "RS256"
            typ = "JWT"
        }

        # Create the claims
        $now = [int][double]::Parse((Get-Date -UFormat %s))
        $expiry = $now + 3600

        $claims = @{
            iss   = $ServiceAccount
            scope = "https://www.googleapis.com/auth/drive"
            aud   = "https://oauth2.googleapis.com/token"
            exp   = $expiry
            iat   = $now
        }

        # Create the JWT
        $headerJson = $header | ConvertTo-Json -Compress
        $claimsJson = $claims | ConvertTo-Json -Compress

        $headerBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($headerJson)) -replace '\+', '-' -replace '/', '_' -replace '='
        $claimsBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($claimsJson)) -replace '\+', '-' -replace '/', '_' -replace '='

        $signatureInput = "$headerBase64.$claimsBase64"

        # Sign the JWT
        $rsa = $cert.PrivateKey
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($signatureInput)
        $signature = $rsa.SignData($bytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $signatureBase64 = [Convert]::ToBase64String($signature) -replace '\+', '-' -replace '/', '_' -replace '='

        $jwt = "$signatureInput.$signatureBase64"

        # Request the access token
        $tokenParams = @{
            Uri             = "https://oauth2.googleapis.com/token"
            Method          = "POST"
            ContentType     = "application/x-www-form-urlencoded"
            Body            = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$jwt"
            UseBasicParsing = $true
        }

        Write-Verbose "Requesting access token from Google OAuth2 endpoint"
        $response = Invoke-WebRequest @tokenParams
        $tokenContent = $response.Content | ConvertFrom-Json

        if ($tokenContent.access_token)
        {
            Write-Verbose "Successfully obtained access token"
            return $tokenContent.access_token
        }
        else
        {
            Write-Error "Failed to obtain access token: $($tokenContent.error_description)"
            return $null
        }
    }
    catch
    {
        Write-Error "Error getting Google Drive access token: $_"
        return $null
    }
}

function Invoke-GoogleDriveUpload
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$AccessToken,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]$SourceFile,

        [Parameter(Mandatory = $true)]
        [String]$FolderId,

        [Parameter()]
        [Boolean]$SupportsTeamDrives = $true
    )

    try
    {
        $fileInfo = Get-Item -Path $SourceFile
        $fileName = $fileInfo.Name

        Write-Verbose "Uploading file: $fileName"

        # Create the metadata for the file
        $metadata = @{
            name   = $fileName
            parents = @($FolderId)
        } | ConvertTo-Json

        # Prepare the upload
        $fileBytes = [System.IO.File]::ReadAllBytes($SourceFile)

        # Create multipart body
        $boundary = [Guid]::NewGuid().ToString()
        $uploadUri = "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"

        if ($SupportsTeamDrives)
        {
            $uploadUri += "&supportsTeamDrives=true"
        }

        # Build the multipart body
        $metadataSection = @"
--$boundary
Content-Type: application/json; charset=UTF-8

$metadata
"@

        $fileSection = @"
--$boundary
Content-Type: application/octet-stream

"@

        $footer = @"
--$boundary--
"@

        # Prepare the body as bytes
        $bodyBuilder = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.StreamWriter($bodyBuilder)

        $writer.Write($metadataSection)
        $writer.Flush()
        $bodyBuilder.Write([System.Text.Encoding]::UTF8.GetBytes($fileSection), 0, [System.Text.Encoding]::UTF8.GetByteCount($fileSection))
        $bodyBuilder.Write($fileBytes, 0, $fileBytes.Length)
        $bodyBuilder.Write([System.Text.Encoding]::UTF8.GetBytes("`n$footer"), 0, [System.Text.Encoding]::UTF8.GetByteCount("`n$footer"))

        $bodyBytes = $bodyBuilder.ToArray()
        $writer.Dispose()
        $bodyBuilder.Dispose()

        # Upload the file
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
        }

        $uploadParams = @{
            Uri             = $uploadUri
            Method          = "POST"
            Headers         = $headers
            ContentType     = "multipart/related; boundary=$boundary"
            Body            = $bodyBytes
            UseBasicParsing = $true
        }

        Write-Verbose "Sending upload request to Google Drive API"
        $response = Invoke-WebRequest @uploadParams
        $uploadedFile = $response.Content | ConvertFrom-Json

        if ($uploadedFile.id)
        {
            Write-Verbose "File uploaded successfully with ID: $($uploadedFile.id)"
            return $uploadedFile
        }
        else
        {
            Write-Error "Upload completed but no file ID returned"
            return $null
        }
    }
    catch
    {
        Write-Error "Error uploading file to Google Drive: $_"
        return $null
    }
}
