$baseDir = "force-app/main/default/objects/Claim"
$fieldsDir = "$baseDir/fields"
New-Item -Path $fieldsDir -ItemType Directory -Force | Out-Null

function Create-Field($name, $label, $type, $length, $precision, $scale, $visibleLines) {
    if ($type -eq "LongTextArea") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <externalId>false</externalId>
    <label>$label</label>
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
    <label>$label</label>
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
    <label>$label</label>
    <precision>$precision</precision>
    <required>false</required>
    <scale>$scale</scale>
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
    <label>$label</label>
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
    <label>$label</label>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>Checkbox</type>
</CustomField>
"@
    } elseif ($type -eq "DateTime") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <required>false</required>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>DateTime</type>
</CustomField>
"@
    } elseif ($type -eq "Currency") {
        $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <externalId>false</externalId>
    <label>$label</label>
    <precision>$precision</precision>
    <required>false</required>
    <scale>$scale</scale>
    <trackFeedHistory>false</trackFeedHistory>
    <trackHistory>false</trackHistory>
    <type>Currency</type>
</CustomField>
"@
    }

    Set-Content -Path "$fieldsDir/$name.field-meta.xml" -Value $meta
}

# Claim Fields
Create-Field "AI_Summary__c" "AI Summary" "LongTextArea" 32768 0 0 3
Create-Field "AI_Recommendation__c" "AI Recommendation" "LongTextArea" 32768 0 0 3
Create-Field "AI_Confidence__c" "AI Confidence" "Number" 0 3 0 0
Create-Field "SubmissionChannel__c" "Submission Channel" "Text" 255 0 0 0
Create-Field "DealerWhatsAppNumber__c" "Dealer WhatsApp Number" "Phone" 0 0 0 0
Create-Field "ApproverSlackRef__c" "Approver Slack Reference" "Text" 255 0 0 0
Create-Field "DecisionRationale__c" "Decision Rationale" "LongTextArea" 32768 0 0 3
Create-Field "ClarificationRequest__c" "Clarification Request" "LongTextArea" 32768 0 0 3
Create-Field "RequiresFollowUp__c" "Requires Follow Up" "Checkbox" 0 0 0 0
Create-Field "MessagingSessionId__c" "Messaging Session Id" "Text" 255 0 0 0
Create-Field "Odometer__c" "Odometer" "Number" 0 18 0 0
Create-Field "Symptom__c" "Symptom" "LongTextArea" 32768 0 0 3
Create-Field "Diagnosis__c" "Diagnosis" "LongTextArea" 32768 0 0 3
Create-Field "PartCategory__c" "Part Category" "Text" 255 0 0 0
Create-Field "EstimatedCost__c" "Estimated Cost" "Currency" 0 18 2 0
Create-Field "Eligibility__c" "Eligibility" "Text" 255 0 0 0
Create-Field "EligibilityRationale__c" "Eligibility Rationale" "LongTextArea" 32768 0 0 3
Create-Field "MissingInfoFlag__c" "Missing Info Flag" "Checkbox" 0 0 0 0
Create-Field "AttachmentCount__c" "Attachment Count" "Number" 0 3 0 0
Create-Field "ReasonCode__c" "Reason Code" "Text" 255 0 0 0
Create-Field "ApprovalDate__c" "Approval Date" "DateTime" 0 0 0 0
Create-Field "RejectionDate__c" "Rejection Date" "DateTime" 0 0 0 0
Create-Field "DealerResponseSummary__c" "Dealer Response Summary" "LongTextArea" 32768 0 0 3
Create-Field "AI_Image_Analysis__c" "AI Image Analysis" "LongTextArea" 32768 0 0 3

# Account Fields
$accFieldsDir = "force-app/main/default/objects/Account/fields"
New-Item -Path $accFieldsDir -ItemType Directory -Force | Out-Null
$accMeta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>DealerTrustScore__c</fullName>
    <externalId>false</externalId>
    <label>Dealer Trust Score</label>
    <precision>3</precision>
    <required>false</required>
    <scale>0</scale>
    <trackFeedHistory>false</trackFeedHistory>
    <type>Number</type>
    <unique>false</unique>
</CustomField>
"@
Set-Content -Path "$accFieldsDir/DealerTrustScore__c.field-meta.xml" -Value $accMeta

Write-Host "Created standardized metadata fields for Claim and Account."
