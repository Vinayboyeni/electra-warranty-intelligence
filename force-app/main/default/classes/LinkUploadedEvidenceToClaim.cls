public with sharing class LinkUploadedEvidenceToClaim {
    public class Input {
        @InvocableVariable(label='Claim Id' description='Claim record to link evidence to.')
        public Id claimId;

        @InvocableVariable(label='Attachment Ids' description='Comma-separated ContentDocument Ids to link to the claim.')
        public String attachmentIds;

        @InvocableVariable(label='Attachment Id Collection' description='Collection of ContentDocument Ids to link to the claim.')
        public List<String> attachmentIdCollection;
    }

    public class Result {
        @InvocableVariable(label='Claim Id' description='Id of the processed claim.') public Id claimId;
        @InvocableVariable(label='Linked Count' description='Number of attachments successfully linked.') public Integer linkedCount;
        @InvocableVariable(label='Message' description='Detailed message regarding the linking operation.') public String message;
    }

    @InvocableMethod(label='Link Uploaded Evidence to Claim' description='Associates newly uploaded diagnostic photos or repair order documents with a specific Warranty Claim record in Salesforce.')
    public static List<Result> linkEvidence(List<Input> inputs) {
        List<Result> output = new List<Result>();
        if (inputs == null) {
            return output;
        }

        for (Input input : inputs) {
            Result result = new Result();
            result.claimId = input == null ? null : input.claimId;
            result.linkedCount = 0;
            
            if (input == null || input.claimId == null || (String.isBlank(input.attachmentIds) && (input.attachmentIdCollection == null || input.attachmentIdCollection.isEmpty()))) {
                result.message = 'No claim or content document IDs provided.';
                output.add(result);
                continue;
            }

            try {
                Set<String> docIds = new Set<String>();
                if (String.isNotBlank(input.attachmentIds)) {
                    for (String s : input.attachmentIds.split(',')) {
                        if (String.isNotBlank(s)) docIds.add(s.trim());
                    }
                }
                if (input.attachmentIdCollection != null) {
                    for (String s : input.attachmentIdCollection) {
                        if (String.isNotBlank(s)) docIds.add(s.trim());
                    }
                }
                List<ContentDocumentLink> linksToCreate = new List<ContentDocumentLink>();
                Set<Id> existingDocIds = new Set<Id>();
                
                // Check for existing links
                for (ContentDocumentLink existingLink : [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :input.claimId
                ]) {
                    existingDocIds.add(existingLink.ContentDocumentId);
                }
                
                // Create new links for documents not already linked
                for (String docId : docIds) {
                    String trimmedId = docId.trim();
                    if (String.isNotBlank(trimmedId) && !existingDocIds.contains(trimmedId)) {
                        ContentDocumentLink cdl = new ContentDocumentLink();
                        cdl.ContentDocumentId = trimmedId;
                        cdl.LinkedEntityId = input.claimId;
                        cdl.ShareType = 'V';
                        cdl.Visibility = 'AllUsers';
                        linksToCreate.add(cdl);
                    }
                }

                if (!linksToCreate.isEmpty()) {
                    insert linksToCreate;
                    result.linkedCount = linksToCreate.size();
                }
                
                // Update attachment count on claim
                Integer totalLinks = [
                    SELECT COUNT()
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :input.claimId
                ];
                Claim updateClaim = new Claim(
                    Id = input.claimId,
                    AttachmentCount__c = totalLinks
                );
                update updateClaim;
                
                result.message = result.linkedCount + ' file(s) linked to claim. Total attachments: ' + totalLinks;
            } catch (Exception e) {
                result.message = 'Error linking evidence: ' + e.getMessage();
            }

            output.add(result);
        }
        return output;
    }
}