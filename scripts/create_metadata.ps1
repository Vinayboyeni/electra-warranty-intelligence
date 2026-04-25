$baseDir = "force-app/main/default/objects/Claim"
$fieldsDir = "$baseDir/fields"

New-Item -Path $fieldsDir -ItemType Directory -Force | Out-Null

$objectMeta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <enableFeeds>true</enableFeeds>
    <sharingModel>Private</sharingModel>
</CustomObject>
"@
Set-Content -Path "$baseDir/Claim.object-meta.xml" -Value $objectMeta

function Create-Field($name, $type, $length, $visibleLines) {
    if ($type -eq "LongTextArea") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <externalId>false</externalId>
    <label>$($name.Replace('__c','').Replace('_',' '))</label>
    <length>$length</length>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>LongTextArea</type>
    <visibleLines>$visibleLines</visibleLines>
</CustomField>
"@
    } elseif ($type -eq "Text") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <externalId>false</externalId>
    <label>$($name.Replace('__c','').Replace('_',' '))</label>
    <length>$length</length>
    <required>false</required>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>Text</type>
    <unique>false</unique>
</CustomField>
"@
    } elseif ($type -eq "Number") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <externalId>false</externalId>
    <label>$($name.Replace('__c','').Replace('_',' '))</label>
    <precision>$length</precision>
    <required>false</required>
    <scale>0</scale>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>Number</type>
    <unique>false</unique>
</CustomField>
"@
    } elseif ($type -eq "Phone") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <externalId>false</externalId>
    <label>$($name.Replace('__c','').Replace('_',' '))</label>
    <required>false</required>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>Phone</type>
</CustomField>
"@
    } elseif ($type -eq "Checkbox") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <defaultValue>false</defaultValue>
    <externalId>false</externalId>
    <label>$($name.Replace('__c','').Replace('_',' '))</label>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>Checkbox</type>
</CustomField>
"@
    }

    Set-Content -Path "$fieldsDir/$name.field-meta.xml" -Value $meta
}

Create-Field "AI_Summary__c" "LongTextArea" 32768 3
Create-Field "AI_Recommendation__c" "LongTextArea" 32768 3
Create-Field "AI_Confidence__c" "Number" 3 0
Create-Field "Submission_Channel__c" "Text" 255 0
Create-Field "Dealer_WhatsApp_Number__c" "Phone" 40 0
Create-Field "Approver_Slack_Ref__c" "Text" 255 0
Create-Field "Messaging_Session_Id__c" "Text" 255 0
Create-Field "Decision_Rationale__c" "LongTextArea" 32768 3
Create-Field "Clarification_Request__c" "LongTextArea" 32768 3
Create-Field "Requires_Follow_Up__c" "Checkbox" 0 0
Create-Field "AI_Image_Analysis__c" "LongTextArea" 32768 3
Create-Field "Dealer_Response_Summary__c" "LongTextArea" 32768 3

Write-Host "Created Claim standard object metadata extensions."
