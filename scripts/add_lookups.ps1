$baseDir = "force-app/main/default/objects/Claim"
$fieldsDir = "$baseDir/fields"

function Create-Lookup($obj, $name, $label, $referenceTo) {
    if ($obj -eq "Claim") { $targetDir = "force-app/main/default/objects/Claim/fields" }
    elseif ($obj -eq "AssetWarranty") { $targetDir = "force-app/main/default/objects/AssetWarranty/fields" }
    
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    
    $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <deleteConstraint>SetNull</deleteConstraint>
    <externalId>false</externalId>
    <label>$label</label>
    <referenceTo>$referenceTo</referenceTo>
    <relationshipLabel>$obj</relationshipLabel>
    <relationshipName>$obj</relationshipName>
    <required>false</required>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>Lookup</type>
</CustomField>
"@
    Set-Content -Path "$targetDir/$name.field-meta.xml" -Value $meta
}

# Add missed lookups
Create-Lookup "Claim" "Vehicle__c" "Vehicle" "Asset"
Create-Lookup "Claim" "Part__c" "Part" "Product2" # Mapping Part__c lookup to Product2 (standard)
Create-Lookup "AssetWarranty" "Vehicle__c" "Vehicle" "Asset"

Write-Host "Added missing lookup fields."
