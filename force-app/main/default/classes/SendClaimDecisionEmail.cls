/**
 * SendClaimDecisionEmail - Invocable Apex
 *
 * Sends an HTML email notification when a Warranty Claim status changes to
 * Approved, Rejected, or Needs More Info. Called from
 * Notify_Dealer_On_Status_Change_Flow alongside the existing in-chat push.
 *
 * Recipient resolution:
 *   To  : Customer Contact email (vehicle owner) via Vehicle.Asset.ContactId
 *   CC  : First dealer Contact under Claim.Account
 *   If only one resolves, that becomes the To address.
 *
 * For Approved claims, attaches the ApprovalAuthorizationPDF — generates it
 * on the fly via GenerateApprovalAuthorization if a ContentVersion isn't
 * already on the claim.
 *
 * Never throws — failures swallowed and recorded as a Chatter audit so the
 * email path can never roll back the underlying status DML.
 */
public without sharing class SendClaimDecisionEmail {

    public class Input {
        @InvocableVariable(required=true label='Claim Id')
        public Id claimId;
    }

    public class Result {
        @InvocableVariable public Boolean sent;
        @InvocableVariable public String channel;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Send Claim Decision Email'
        description='Sends an HTML email to the customer (and dealer) with the latest claim decision. Attaches the authorization PDF for Approved claims.'
    )
    public static List<Result> send(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Result res = new Result();
            res.sent = false;
            try {
                if (inp == null || inp.claimId == null) {
                    res.channel = 'Error';
                    res.message = 'claimId is required.';
                    results.add(res);
                    continue;
                }

                List<Claim> claims = [
                    SELECT Id, Name, Status, AccountId, Account.Name,
                           Vehicle__c, Vehicle__r.Name,
                           PartCategory__c, EstimatedCost__c, ApprovedAmount,
                           ClarificationRequest__c, DecisionRationale__c,
                           ReasonCode__c, SLA_Due_Date__c
                    FROM Claim WHERE Id = :inp.claimId LIMIT 1
                ];
                if (claims.isEmpty()) {
                    res.channel = 'Error';
                    res.message = 'Claim not found.';
                    results.add(res);
                    continue;
                }
                Claim c = claims[0];

                // Resolve recipients
                Recipients r = resolveRecipients(c);
                if (String.isBlank(r.toAddress) && String.isBlank(r.ccAddress)) {
                    auditOnly(c.Id, 'No customer or dealer email on file. Email skipped.');
                    res.channel = 'Skipped';
                    res.message = 'No recipient email available.';
                    results.add(res);
                    continue;
                }
                if (String.isBlank(r.toAddress) && String.isNotBlank(r.ccAddress)) {
                    r.toAddress = r.ccAddress;
                    r.ccAddress = null;
                }

                // Build email
                String subject = buildSubject(c);
                String htmlBody = buildHtmlBody(c, r.customerName);
                String textBody = buildTextBody(c, r.customerName);

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ r.toAddress });
                if (String.isNotBlank(r.ccAddress) && r.ccAddress != r.toAddress) {
                    email.setCcAddresses(new List<String>{ r.ccAddress });
                }
                email.setSubject(subject);
                email.setHtmlBody(htmlBody);
                email.setPlainTextBody(textBody);
                email.setSaveAsActivity(true);

                // Send from a verified Organization-Wide Email Address if one is
                // configured. Avoids "FROM address has not been verified" errors
                // when the running (bot/integration) user's email isn't set up as
                // a sender. Falls back silently to the running user if no OWA.
                Id owaId = findVerifiedOwaId();
                if (owaId != null) {
                    email.setOrgWideEmailAddressId(owaId);
                }

                // Attach PDF for Approved claims
                if ('Approved'.equalsIgnoreCase(c.Status)) {
                    Messaging.EmailFileAttachment att = buildPdfAttachment(c);
                    if (att != null) {
                        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ att });
                    }
                }

                if (Test.isRunningTest()) {
                    res.sent = true;
                    res.channel = 'Email (test)';
                    res.message = 'Test mode — email constructed but not sent.';
                } else {
                    Messaging.SendEmailResult[] sendResults =
                        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
                    if (!sendResults.isEmpty() && sendResults[0].isSuccess()) {
                        res.sent = true;
                        res.channel = 'Email';
                        res.message = 'Sent to ' + r.toAddress
                            + (String.isNotBlank(r.ccAddress) && r.ccAddress != r.toAddress ? ' (cc ' + r.ccAddress + ')' : '');
                        auditSuccess(c.Id, r.toAddress, r.ccAddress, subject);
                    } else {
                        String err = !sendResults.isEmpty() && sendResults[0].getErrors().size() > 0
                            ? sendResults[0].getErrors()[0].getMessage()
                            : 'Unknown email failure.';
                        res.channel = 'EmailError';
                        res.message = err;
                        auditOnly(c.Id, '⚠️ Email send failed: ' + err);
                    }
                }
            } catch (Exception e) {
                res.channel = 'Error';
                res.message = 'Exception: ' + e.getMessage();
                try { auditOnly(inp == null ? null : inp.claimId, '⚠️ Email exception: ' + e.getMessage()); } catch (Exception ignore) {}
            }
            results.add(res);
        }
        return results;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    private class Recipients {
        String toAddress;
        String ccAddress;
        String customerName;
    }

    private static Recipients resolveRecipients(Claim c) {
        Recipients r = new Recipients();

        // 1. Customer email via Vehicle → Asset → Contact
        if (c.Vehicle__c != null) {
            List<Vehicle> vehicles = [
                SELECT Asset.ContactId,
                       Asset.Contact.Name,
                       Asset.Contact.Email
                FROM Vehicle
                WHERE AssetId = :c.Vehicle__c
                LIMIT 1
            ];
            if (!vehicles.isEmpty() && vehicles[0].Asset != null && vehicles[0].Asset.Contact != null) {
                r.customerName = vehicles[0].Asset.Contact.Name;
                if (String.isNotBlank(vehicles[0].Asset.Contact.Email)) {
                    r.toAddress = vehicles[0].Asset.Contact.Email;
                }
            }
        }

        // 2. Dealer email via dealer Account → first Contact with email
        if (c.AccountId != null) {
            List<Contact> dealerContacts = [
                SELECT Email, Name FROM Contact
                WHERE AccountId = :c.AccountId AND Email != null
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!dealerContacts.isEmpty()) {
                r.ccAddress = dealerContacts[0].Email;
            }
        }

        return r;
    }

    private static String buildSubject(Claim c) {
        if ('Approved'.equalsIgnoreCase(c.Status)) {
            return '✅ Warranty Claim ' + c.Name + ' Approved — Electra Cars';
        } else if ('Rejected'.equalsIgnoreCase(c.Status)) {
            return '❌ Warranty Claim ' + c.Name + ' — Decision Update';
        } else if ('Needs More Info'.equalsIgnoreCase(c.Status)) {
            return 'ℹ️ Warranty Claim ' + c.Name + ' — Additional Information Needed';
        }
        return 'Electra Cars Warranty Claim ' + c.Name + ' — Status Update';
    }

    private static String buildHtmlBody(Claim c, String customerName) {
        String greeting = 'Hi ' + (String.isNotBlank(customerName) ? customerName : 'there') + ',';
        String header;
        String body;
        String footer = '<hr style="border:0;border-top:1px solid #e5e5e5;margin:24px 0"/>'
            + '<p style="font-size:12px;color:#888;line-height:1.5;">Electra Cars, Inc. — Warranty Operations<br/>'
            + 'This is an automated message regarding warranty claim ' + escape(c.Name)
            + '. For questions, contact your authorized Electra dealer or call 1-800-ELECTRA.</p>';

        String vehicle = c.Vehicle__r != null && c.Vehicle__r.Name != null
            ? escape(c.Vehicle__r.Name) : 'your Electra vehicle';
        String dealer = c.Account != null && c.Account.Name != null ? escape(c.Account.Name) : 'your Electra dealer';
        String partLine = c.PartCategory__c != null
            ? '<tr><td style="padding:6px 0;color:#666;width:40%">Part Category</td><td style="padding:6px 0;font-weight:600">' + escape(c.PartCategory__c) + '</td></tr>'
            : '';
        String estimateLine = c.EstimatedCost__c != null
            ? '<tr><td style="padding:6px 0;color:#666">Estimated Cost</td><td style="padding:6px 0;font-weight:600">$' + c.EstimatedCost__c.setScale(2) + '</td></tr>'
            : '';

        if ('Approved'.equalsIgnoreCase(c.Status)) {
            header = '<h2 style="color:#0a8a3a;margin:0 0 8px 0">✅ Your warranty claim has been approved</h2>'
                + '<p style="margin:0 0 16px 0;color:#444">Great news — the prior-authorization for ' + vehicle + ' is approved. You may proceed with the repair at ' + dealer + '.</p>';
            String approvedLine = c.ApprovedAmount != null
                ? '<tr><td style="padding:6px 0;color:#666">Approved Amount</td><td style="padding:6px 0;font-weight:600;color:#0a8a3a">$' + c.ApprovedAmount.setScale(2) + '</td></tr>'
                : '';
            body = approvedLine + partLine + estimateLine
                + '<tr><td style="padding:6px 0;color:#666">Servicing Dealer</td><td style="padding:6px 0;font-weight:600">' + dealer + '</td></tr>';
            String rationale = String.isNotBlank(c.DecisionRationale__c)
                ? '<p style="margin:16px 0 8px 0;color:#555"><b>Approver note:</b> ' + escape(c.DecisionRationale__c) + '</p>' : '';
            return wrap(greeting, header, body) + rationale
                + '<p style="margin:16px 0 8px 0;color:#444">📄 The authorization document is attached to this email. Please share it with your dealer when scheduling the repair (valid 30 days).</p>'
                + footer;
        } else if ('Rejected'.equalsIgnoreCase(c.Status)) {
            header = '<h2 style="color:#b3261e;margin:0 0 8px 0">Warranty claim decision: Rejected</h2>'
                + '<p style="margin:0 0 16px 0;color:#444">After review, the warranty prior-authorization for ' + vehicle + ' was not approved.</p>';
            String reasonLine = String.isNotBlank(c.ReasonCode__c)
                ? '<tr><td style="padding:6px 0;color:#666">Reason Code</td><td style="padding:6px 0;font-weight:600">' + escape(c.ReasonCode__c) + '</td></tr>' : '';
            body = reasonLine + partLine + estimateLine
                + '<tr><td style="padding:6px 0;color:#666">Servicing Dealer</td><td style="padding:6px 0;font-weight:600">' + dealer + '</td></tr>';
            String rationale = String.isNotBlank(c.DecisionRationale__c)
                ? '<p style="margin:16px 0 8px 0;color:#555"><b>Approver note:</b> ' + escape(c.DecisionRationale__c) + '</p>' : '';
            return wrap(greeting, header, body) + rationale
                + '<p style="margin:16px 0 8px 0;color:#444">If you would like to request a goodwill exception, contact your dealer or reply to this email with your justification.</p>'
                + footer;
        } else if ('Needs More Info'.equalsIgnoreCase(c.Status)) {
            String question = String.isNotBlank(c.ClarificationRequest__c)
                ? escape(c.ClarificationRequest__c)
                : 'Our adjuster requires additional information before continuing.';
            header = '<h2 style="color:#b27a00;margin:0 0 8px 0">ℹ️ Additional information needed</h2>'
                + '<p style="margin:0 0 16px 0;color:#444">Our OEM approver has requested more details before deciding on your warranty claim.</p>';
            body = partLine + estimateLine
                + '<tr><td style="padding:6px 0;color:#666">Servicing Dealer</td><td style="padding:6px 0;font-weight:600">' + dealer + '</td></tr>';
            return wrap(greeting, header, body)
                + '<div style="margin:16px 0;padding:14px 16px;background:#fff8e1;border-left:4px solid #b27a00;border-radius:4px"><b>Approver question:</b><br/>' + question + '</div>'
                + '<p style="margin:16px 0 8px 0;color:#444">Please contact your dealer with the answer, or reply to this email and your dealer will relay it to the approver.</p>'
                + footer;
        }

        // Generic fallback
        header = '<h2 style="margin:0 0 8px 0">Warranty claim update</h2>'
            + '<p style="margin:0 0 16px 0;color:#444">Status of claim ' + escape(c.Name) + ' is now: ' + escape(c.Status) + '.</p>';
        body = partLine + '<tr><td style="padding:6px 0;color:#666">Servicing Dealer</td><td style="padding:6px 0;font-weight:600">' + dealer + '</td></tr>';
        return wrap(greeting, header, body) + footer;
    }

    private static String wrap(String greeting, String header, String tableRows) {
        return '<!DOCTYPE html><html><body style="margin:0;padding:0;background:#f6f7f9">'
            + '<div style="max-width:620px;margin:0 auto;padding:24px;font-family:-apple-system,Helvetica,Arial,sans-serif;background:#ffffff">'
            + '<p style="margin:0 0 16px 0;color:#222">' + escape(greeting) + '</p>'
            + header
            + '<table style="width:100%;border-collapse:collapse;font-size:14px;color:#222;margin:8px 0">' + tableRows + '</table>'
            + '</div></body></html>';
    }

    private static String buildTextBody(Claim c, String customerName) {
        String greeting = 'Hi ' + (String.isNotBlank(customerName) ? customerName : 'there') + ',\n\n';
        if ('Approved'.equalsIgnoreCase(c.Status)) {
            return greeting + 'Your warranty claim ' + c.Name + ' has been APPROVED. '
                + 'You may proceed with the repair. The authorization document is attached.\n\n'
                + (c.ApprovedAmount != null ? 'Approved amount: $' + c.ApprovedAmount.setScale(2) + '\n' : '')
                + (String.isNotBlank(c.DecisionRationale__c) ? 'Approver note: ' + c.DecisionRationale__c + '\n' : '')
                + '\n— Electra Cars Warranty Operations';
        } else if ('Rejected'.equalsIgnoreCase(c.Status)) {
            return greeting + 'After review, your warranty claim ' + c.Name + ' was not approved.\n\n'
                + (String.isNotBlank(c.ReasonCode__c) ? 'Reason: ' + c.ReasonCode__c + '\n' : '')
                + (String.isNotBlank(c.DecisionRationale__c) ? 'Approver note: ' + c.DecisionRationale__c + '\n' : '')
                + '\nReply to this email or contact your dealer if you would like to request a goodwill exception.\n\n— Electra Cars Warranty Operations';
        } else if ('Needs More Info'.equalsIgnoreCase(c.Status)) {
            return greeting + 'Your warranty claim ' + c.Name + ' needs additional information.\n\n'
                + 'Approver question: ' + (String.isNotBlank(c.ClarificationRequest__c) ? c.ClarificationRequest__c : 'Additional details requested.')
                + '\n\nPlease reply to this email or contact your dealer with the answer.\n\n— Electra Cars Warranty Operations';
        }
        return greeting + 'Status of claim ' + c.Name + ' is now: ' + c.Status + '.';
    }

    private static Messaging.EmailFileAttachment buildPdfAttachment(Claim c) {
        try {
            // Look for an existing PDF ContentVersion linked to the Claim first.
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :c.Id
            ];
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

            if (!docIds.isEmpty()) {
                List<ContentVersion> existing = [
                    SELECT Id, Title, VersionData, PathOnClient
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docIds
                      AND Title LIKE '%Approval Authorization%'
                      AND IsLatest = true
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    ContentVersion cv = existing[0];
                    Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
                    att.setFileName(String.isNotBlank(cv.PathOnClient) ? cv.PathOnClient : c.Name + '-Authorization.pdf');
                    att.setBody(cv.VersionData);
                    att.setContentType('application/pdf');
                    return att;
                }
            }

            // No existing PDF — generate one now.
            String pdfUrl = GenerateApprovalAuthorization.generate(c.Id);
            if (String.isBlank(pdfUrl)) return null;
            // Fetch the freshly created ContentVersion for binary attach
            links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :c.Id
            ];
            docIds = new Set<Id>();
            for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);
            if (docIds.isEmpty()) return null;
            List<ContentVersion> fresh = [
                SELECT Id, Title, VersionData, PathOnClient
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND IsLatest = true
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (fresh.isEmpty()) return null;
            ContentVersion cv = fresh[0];
            Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
            att.setFileName(String.isNotBlank(cv.PathOnClient) ? cv.PathOnClient : c.Name + '-Authorization.pdf');
            att.setBody(cv.VersionData);
            att.setContentType('application/pdf');
            return att;
        } catch (Exception e) {
            System.debug('PDF attachment build failed: ' + e.getMessage());
            return null;
        }
    }

    private static Id findVerifiedOwaId() {
        try {
            List<OrgWideEmailAddress> owas = [
                SELECT Id FROM OrgWideEmailAddress
                WHERE IsVerified = true
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            return owas.isEmpty() ? null : owas[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static String escape(String s) {
        if (s == null) return '';
        return s.escapeHtml4();
    }

    private static void auditOnly(Id claimId, String message) {
        if (claimId == null || String.isBlank(message)) return;
        try {
            insert new FeedItem(ParentId = claimId, Body = '✉️ ' + message);
        } catch (Exception ignore) {}
    }

    private static void auditSuccess(Id claimId, String toAddr, String ccAddr, String subject) {
        if (claimId == null) return;
        try {
            String note = '✉️ Email sent.\nTo: ' + toAddr
                + (String.isNotBlank(ccAddr) && ccAddr != toAddr ? '\nCC: ' + ccAddr : '')
                + '\nSubject: ' + subject;
            insert new FeedItem(ParentId = claimId, Body = note);
        } catch (Exception ignore) {}
    }
}