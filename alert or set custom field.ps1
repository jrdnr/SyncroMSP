# this script expects 2 runtime variables
#
# $PolicyName is required and will be used in the alert massage or as the value
#   of the the asset custom field
#
# $AssetCustomField is optional if specified the script will set the field 
#   inserted of raising an alert

Import-Module $env:SyncroModule -DisableNameChecking

if ([string]::IsNullOrEmpty($PolicyName)){
    Rmm-Alert -Category 'Policy_Assigned' -Body 'Error: $PolicyName is missing or blank'
} elseif ([string]::IsNullOrEmpty($AssetCustomField)){
    Rmm-Alert -Category 'Policy_Assigned' -Body "$env:computername is assigned $PolicyName"
} else {
    Set-Asset-Field -Name $AssetCustomField -Value $PolicyName
}
