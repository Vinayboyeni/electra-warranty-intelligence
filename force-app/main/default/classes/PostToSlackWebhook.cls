/**
 * PostToSlackWebhook
 *
 * Invocable Apex action that posts a formatted message to a Slack channel
 * via an Incoming Webhook (configured as a Named Credential).
 *
 * Called from Slack_Notify_Approver_Flow after the FeedItem is created.
 * The FeedItem remains as an in-Salesforce audit trail; this class is
 * what actually makes the message appear in Slack.
 *
 * Named Credential expected: `callout:Slack_Webhook_Approver`
 */
public with sharing class PostToSlackWebhook {

    public class Input {
        @InvocableVariable(required=true label='Message Body' description='Slack-markdown body to post.')
        public String body;

        @InvocableVariable(label='Claim Id' description='Optional — for log correlation.')
        public Id claimId;
    }

    public class Result {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Status Code') public Integer statusCode;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='Post To Slack Webhook'
        description='Posts a message to the approver Slack channel via Incoming Webhook (Named Credential: Slack_Webhook_Approver).'
    )
    public static List<Result> post(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Result res = new Result();
            if (inp == null || String.isBlank(inp.body)) {
                res.success = false;
                res.message = 'Body is required.';
                results.add(res);
                continue;
            }

            try {
                Map<String, Object> payload = new Map<String, Object>{
                    'text' => inp.body,
                    'mrkdwn' => true
                };
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:Slack_Webhook_Approver');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(payload));
                req.setTimeout(20000);

                HttpResponse resp = new Http().send(req);
                res.statusCode = resp.getStatusCode();
                res.success = (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300);
                res.message = res.success
                    ? 'Posted to Slack.'
                    : 'Slack returned ' + resp.getStatusCode() + ': ' + resp.getBody();
            } catch (Exception e) {
                res.success = false;
                res.message = 'Callout exception: ' + e.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}