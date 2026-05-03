/**
 * LinkChatAttachmentToClaim
 *
 * Bridges a file the dealer dropped into the Embedded Service Web Chat over
 * to the corresponding Claim record. Embedded Service uploads attachments
 * onto the MessagingSession (not the Claim), so the dealer agent can't act
 * on them directly. This invocable finds the latest unsibmitted attachment
 * on the session, links it to the Claim, and publishes a public URL so
 * the OEM approver's Slack card can surface it.
 *
 * Called from the intake agent when the dealer says they uploaded a photo
 * after creating a claim. Returns success + filename + public URL so the
 * agent can echo "Got the photo, attached to your claim" back to the dealer.
 *
 * Runs `without sharing` so the chat-bot user (which may not own the
 * MessagingSession or the Claim) can still bridge the records.
 */
public without sharing class LinkChatAttachmentToClaim {

    public class Input {
        @InvocableVariable(label='Claim Id' required=true description='Salesforce Id of the Claim to attach the chat upload to.')
        public Id claimId;

        @InvocableVariable(label='Messaging Session Id' description='Id of the live agent / Embedded Service messaging session whose latest upload should be linked to the Claim. When omitted, falls back to Claim.MessagingSessionId__c.')
        public String messagingSessionId;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True when at least one new file was linked to the Claim.')
        public Boolean success;

        @InvocableVariable(label='File Title' description='Filename of the most recent attachment that was linked.')
        public String fileTitle;

        @InvocableVariable(label='File Public URL' description='Public ContentDistribution URL the agent can echo back to the dealer.')
        public String filePublicUrl;

        @InvocableVariable(label='Files Linked' description='Count of new ContentDocumentLinks created by this call.')
        public Integer filesLinked;

        @InvocableVariable(label='Message' description='Human-readable status message the agent can surface to the dealer.')
        public String message;
    }

    @InvocableMethod(label='Link Chat Attachment To Claim' description='Finds the most recent file uploaded by the dealer in the Web Chat session and links it to the Claim record so the OEM approver can review it. Call after the dealer mentions uploading a photo or document.')
    public static List<Result> link(List<Input> inputs) {
        List<Result> outputs = new List<Result>();
        if (inputs == null) return outputs;

        for (Input req : inputs) {
            Result r = new Result();
            r.success = false;
            r.filesLinked = 0;

            if (req == null || req.claimId == null) {
                r.message = 'Missing Claim Id.';
                outputs.add(r);
                continue;
            }

            try {
                // Resolve session Id: explicit input wins; otherwise fall back
                // to whatever was stamped on the Claim at creation time.
                String sessionId = req.messagingSessionId;
                if (String.isBlank(sessionId)) {
                    List<Claim> claimRows = [
                        SELECT Id, MessagingSessionId__c
                        FROM Claim
                        WHERE Id = :req.claimId
                        LIMIT 1
                    ];
                    if (!claimRows.isEmpty() && String.isNotBlank(claimRows[0].MessagingSessionId__c)) {
                        sessionId = claimRows[0].MessagingSessionId__c;
                    }
                }

                if (String.isBlank(sessionId)) {
                    r.message = 'No chat session found for this claim. Please use the Track Your Claim portal page to upload supporting documents.';
                    outputs.add(r);
                    continue;
                }

                // 1. Files already linked to the Claim — skip these so the
                // bridge is idempotent (calling twice doesn't double-link).
                Set<Id> alreadyOnClaim = new Set<Id>();
                for (ContentDocumentLink existing : [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :req.claimId
                ]) {
                    alreadyOnClaim.add(existing.ContentDocumentId);
                }

                // 2. All files attached to the chat session, newest first.
                Id sessionLookupId = (Id) sessionId;
                List<ContentDocumentLink> sessionLinks = [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :sessionLookupId
                ];
                if (sessionLinks.isEmpty()) {
                    r.message = 'No files found on the chat session yet. If you just uploaded, give it a moment and try again.';
                    outputs.add(r);
                    continue;
                }

                Set<Id> sessionDocIds = new Set<Id>();
                for (ContentDocumentLink l : sessionLinks) sessionDocIds.add(l.ContentDocumentId);

                List<ContentVersion> sessionVersions = [
                    SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, CreatedDate
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :sessionDocIds
                      AND IsLatest = true
                    ORDER BY CreatedDate DESC
                ];

                if (sessionVersions.isEmpty()) {
                    r.message = 'Chat upload is still processing. Please try again in a few seconds.';
                    outputs.add(r);
                    continue;
                }

                // 3. Build new links for files that aren't already on the Claim.
                List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
                ContentVersion latestVersion = null;
                for (ContentVersion cv : sessionVersions) {
                    if (alreadyOnClaim.contains(cv.ContentDocumentId)) continue;
                    if (latestVersion == null) latestVersion = cv;

                    newLinks.add(new ContentDocumentLink(
                        ContentDocumentId = cv.ContentDocumentId,
                        LinkedEntityId    = req.claimId,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ));
                }

                if (newLinks.isEmpty()) {
                    r.message = 'All files from this chat are already attached to the claim.';
                    r.success = true; // not an error — same outcome as a fresh link
                    outputs.add(r);
                    continue;
                }

                insert newLinks;
                r.filesLinked = newLinks.size();

                // 4. Publish — creates ContentDistribution + stamps PhotoPublicUrl__c
                //    so the Slack approver card surfaces the attachment.
                try {
                    ClaimStatusController.publishUploadedFiles(req.claimId);
                } catch (Exception pubErr) {
                    System.debug('publishUploadedFiles swallowed: ' + pubErr.getMessage());
                }

                // 5. Build a friendly response that the agent can echo back.
                if (latestVersion != null) {
                    r.fileTitle = (latestVersion.Title != null ? latestVersion.Title : 'Attachment')
                        + (String.isNotBlank(latestVersion.FileExtension)
                            ? '.' + latestVersion.FileExtension
                            : '');

                    // Re-query the freshly-created distribution for its public URL.
                    Id versionId = latestVersion.Id;
                    List<ContentDistribution> dists = [
                        SELECT DistributionPublicUrl
                        FROM ContentDistribution
                        WHERE ContentVersionId = :versionId
                        ORDER BY CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!dists.isEmpty() && String.isNotBlank(dists[0].DistributionPublicUrl)) {
                        r.filePublicUrl = dists[0].DistributionPublicUrl;
                    }
                }

                r.success = true;
                r.message = newLinks.size() == 1
                    ? 'Got it — attached "' + r.fileTitle + '" to your claim. The OEM approver can now see it.'
                    : 'Got it — attached ' + newLinks.size() + ' files to your claim. The OEM approver can now see them.';
                outputs.add(r);
            } catch (Exception e) {
                System.debug('LinkChatAttachmentToClaim error: ' + e.getMessage()
                    + '\n' + e.getStackTraceString());
                r.success = false;
                r.message = 'Could not attach the file: ' + e.getMessage();
                outputs.add(r);
            }
        }
        return outputs;
    }
}