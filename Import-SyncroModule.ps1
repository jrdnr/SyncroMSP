function Import-SyncroModule {
    param (
        #Defaults to the UUID of local system but you can provide the UUID of Any other Syncro Asset instead.
        $UUID
    )

    # Ensure TLS -ge 1.2
    if ([Net.ServicePointManager]::SecurityProtocol -lt [Net.SecurityProtocolType]::Tls12){
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    # Set up $env: vars for Syncro Module
    if($env:SyncroModule -match '^\s*$'){
        $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
        $env:RepairTechFilePusherPath  = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
        $env:RepairTechKabutoApiUrl    = 'https://rmm.syncromsp.com'
        $env:RepairTechSyncroApiUrl    = 'https://{subdomain}.syncromsp.com'
        $env:RepairTechSyncroSubDomain = $SyncroRegKey.shop_subdomain
        $env:RepairTechUUID            = if($UUID -match '^\s*$'){ $SyncroRegKey.uuid } else {$UUID}
        $env:SyncroModule              = "$env:ProgramData\Syncro\bin\module.psm1"
    }
    if ((Test-Path -Path $env:SyncroModule) -and ($PSVersionTable.PSVersion -ge [system.version]'4.0')) {
        Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
    } elseif ($PSVersionTable.PSVersion.Major -lt 4) {
        Write-Warning "$($PSVersionTable.PSVersion) is not compatible with SyncroModule"
        [Environment]::SetEnvironmentVariable('SyncroModule',$null)
        $false
    }
}

# use "Get-Command -Module module" to list imported Cmdlets

<# non Function version
# Ensure TLS -ge 1.2
if ([Net.ServicePointManager]::SecurityProtocol -lt [Net.SecurityProtocolType]::Tls12){
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
# Set up $env: vars for Syncro Module
if($env:SyncroModule -match '^\s*$'){
    $SyncroRegKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\RepairTech\Syncro' -Name uuid, shop_subdomain
    $env:RepairTechFilePusherPath   = 'C:\ProgramData\Syncro\bin\FilePusher.exe'
    $env:RepairTechKabutoApiUrl     = 'https://rmm.syncromsp.com'
    $env:RepairTechSyncroApiUrl     = 'https://{subdomain}.syncromsp.com'
    $env:RepairTechSyncroSubDomain  = $SyncroRegKey.shop_subdomain
    $env:RepairTechUUID             = $SyncroRegKey.uuid
    $env:SyncroModule               = "$env:ProgramData\Syncro\bin\module.psm1"
}
if ((Test-Path -Path $env:SyncroModule) -and ($PSVersionTable.PSVersion -ge [system.version]'4.0')) {
    Import-Module -Name $env:SyncroModule -WarningAction SilentlyContinue
} elseif ($PSVersionTable.PSVersion.Major -lt 4) {
    Write-Warning "$($PSVersionTable.PSVersion) is not compatible with SyncroModule"
    [Environment]::SetEnvironmentVariable('SyncroModule',$null)
    $false
}
#>

$ModuleHelp = {
    # Syncro's full set of examples for our built in Powershell Module
    # Date: 2023/06/13

    # This creates an alert in Syncro and triggers the "New RMM Alert" in the Notification Center - automatically de-duping per asset.
    Rmm-Alert -Category 'sample_category' -Body 'Message Here'

    # This displays a popup alert on the desktop.
    Display-Alert -Message "Super important message here"

    # This logs an activity feed item on an Assets's Activity feed
    Log-Activity -Message "Activity description" -EventName "Event name"

    # This saves a screenshot of the desktop to whatever file you specify.
    Get-ScreenCapture -FullFileName "C:\temp\screenshot.jpg"

    # This will send you an email, no SMTP server required.
    Send-Email -To "jordanritz@eberlysystems.com" -Subject "Test Subject" -Body "This is the body"

    # This will upload the file to Syncro and attach it to the Asset.
    Upload-File -FilePath "C:\temp\screenshot.jpg"

    # This can write to your Asset Custom Fields. Use it to store adhoc information that isn't currently surfaced.
    Set-Asset-Field -Name "Field Name" -Value $someVariable

    # This can create a Ticket attached to the Asset & Asset Customer.
    # You can capture the value of this command to save the ticket_id or ticket.number like:
    # $value = Create-Syncro-Ticket
    # Write-Host $value.ticket.id
    Create-Syncro-Ticket -Subject "New Ticket for $problem" -IssueType "Other" -Status "New"

    # This just needs the ticketid or ticket number and you can add a comment. You can have it be "public" or "private", and email or not, and combine those.
    # For example you can make a Public comment (shows on PDF/etc) and have it NOT email the customer.
    Create-Syncro-Ticket-Comment -TicketIdOrNumber 123 -Subject "Contacted" -Body "This is the comment body here" -Hidden "true/false" -DoNotEmail "true/false"

    # This can add a timer entry to a ticket.
    # $StartTime needs to be formatted for a computer to read, the best format is "2018-02-14 15:30"
    # You can use powershell with 'Get-Date -Format o' and that will work nicely.
    # If you wanted to get "30 minutes ago and formatted" it works like this (Get-Date).AddMinutes(-30).toString("o")
    $startAt = (Get-Date).AddMinutes(-30).toString("o")
    Create-Syncro-Ticket-TimerEntry -TicketIdOrNumber 123 -StartTime $startAt -DurationMinutes 30 -Notes "Automated system cleaned up the disk space." -UserIdOrEmail "your.user.email@here.com" -ChargeTime "true/false"

    # Simply updates a ticket, only currently supports status and custom fields.
    Update-Syncro-Ticket -TicketIdOrNumber 123 -Status "In Progress" -CustomFieldName "Automation Results" -CustomFieldValue "Results here for example"

    #This closes an RMM alert in Syncro, there can only be one of each alert category per asset, so it will find the correct one.
    #If no alert exists it will exit gracefully. You can also choose to close a ticket generated from the alert
    Close-Rmm-Alert -Category "sample_category" -CloseAlertTicket "true/false"

    #Add the flag below to suppress and silently continue past any warnings that would normally be displayed.
    -WarningAction SilentlyContinue

    #This sends a Broadcast Message to the asset and optionally logs the activity to the asset's Recent Activity section
    Broadcast-Message -Title "Title Text" -Message "Super important message" -LogActivity "true/false"
}
