public with sharing class GetWhatsAppMediaUrl {
    public class Input {
        @InvocableVariable(label='Messaging Session Id' description='Optional. If provided, fetches attachment for this session.')
        public String messagingSessionId;

        @InvocableVariable(label='Messaging User Id' description='Optional. If provided, fetches latest attachment for this user.')
        public String messagingUserId;
    }

    public class Result {
        @InvocableVariable(label='Image URL' description='Publicly accessible URL or Salesforce content URL for the latest image.')
        public String imageUrl;
        @InvocableVariable(label='Content Document Id' description='Id of the latest content document.')
        public String contentDocumentId;
        @InvocableVariable(label='Success' description='True if an image was found.')
        public Boolean success;
    }

    @InvocableMethod(label='Get WhatsApp Media URL' description='Retrieves the URL of the latest image attachment sent in the current WhatsApp session.')
    public static List<Result> getMediaUrl(List<Input> inputs) {
        List<Result> outputs = new List<Result>();
        if (inputs == null) return outputs;

        for (Input input : inputs) {
            Result r = new Result();
            r.success = false;

            try {
                Id sessionId;
                if (String.isNotBlank(input.messagingSessionId)) {
                    sessionId = (Id)input.messagingSessionId;
                } else if (String.isNotBlank(input.messagingUserId)) {
                    // Lookup latest active session for this user
                    List<MessagingSession> sessions = [
                        SELECT Id 
                        FROM MessagingSession 
                        WHERE MessagingEndUserId = :input.messagingUserId
                        ORDER BY CreatedDate DESC 
                        LIMIT 1
                    ];
                    if (!sessions.isEmpty()) sessionId = sessions[0].Id;
                }

                if (sessionId != null) {
                    // In Salesforce, attachments in MessagingSessions are linked via ContentDocumentLink or MessagingSession attachment associations
                    // This is a simplified lookup for the latest ContentDocument linked to the session
                    List<ContentDocumentLink> links = [
                        SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId 
                        FROM ContentDocumentLink 
                        WHERE LinkedEntityId = :sessionId
                        ORDER BY ContentDocument.CreatedDate DESC 
                        LIMIT 1
                    ];

                    if (!links.isEmpty()) {
                        ContentVersion cv = [
                            SELECT Id, VersionDataUrl, FileExtension 
                            FROM ContentVersion 
                            WHERE Id = :links[0].ContentDocument.LatestPublishedVersionId
                        ];
                        // Construct a usable URL for the agent (Multimodal models often need a direct or authenticated URL)
                        // In a real environment, this might be a public distribution URL
                        r.imageUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                        r.contentDocumentId = links[0].ContentDocumentId;
                        r.success = true;
                    }
                }
            } catch (Exception e) {
                // Fallback or error logging
            }
            outputs.add(r);
        }
        return outputs;
    }
}