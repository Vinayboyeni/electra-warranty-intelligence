# Prompt Template: Compose_Dealer_Rejection_Message

This template composes a personalized, empathetic WhatsApp rejection message
for the dealer when a claim is rejected. The invoker Apex class
`ComposeDealerRejectionMessage.cls` calls this template by developer name.

Until you configure this template in Prompt Builder UI, the invoker falls back
to a rule-based template. Once configured and activated, the LLM output
automatically replaces the rule-based message. Zero code changes needed.

---

## Where to Configure

**Setup → Prompt Builder → New Prompt Template**

| Field | Value |
|---|---|
| Type | **Flex** *(if unavailable, use "Field Generation" targeting `Claim.AI_Summary__c`)* |
| API Name | `Compose_Dealer_Rejection_Message` *(exact match — Apex looks it up by this)* |
| Label | `Compose Dealer Rejection Message` |
| Object | `Claim` |

---

## Inputs

Add these custom inputs in Prompt Builder:

| Input Name | Type | Source |
|---|---|---|
| `inputRecord` | Record (Claim) | Passed by the Apex invoker |
| `reasonCode` | Text | Passed separately (e.g., "Coverage Expired") |
| `adjusterRationale` | Text | Passed separately (free-text adjuster note) |

---

## Template Body

Paste this into the **Prompt Template Body** field in the Prompt Builder UI.

```
You are an Electra Cars OEM service communication specialist. Your job is to
compose a 4-to-6 sentence WhatsApp rejection message to the dealer.

The message must be empathetic, specific to this claim, respectful of the
dealer's time, and actionable. Write like a senior human who genuinely
cares — not like a form letter. Use plain English, no jargon.

─── CONTEXT ───
Claim Number:   {!$Input:inputRecord.Name}
Dealer:         {!$Input:inputRecord.Account.Name}
Vehicle:        {!$Input:inputRecord.Vehicle__r.Name}
Part:           {!$Input:inputRecord.PartCategory__c}
Symptom:        {!$Input:inputRecord.Symptom__c}
Odometer:       {!$Input:inputRecord.Odometer__c} miles
Cost Submitted: ${!$Input:inputRecord.EstimatedCost__c}
Eligibility:    {!$Input:inputRecord.Eligibility__c}

─── DECISION ───
Reason Code:        {!$Input:reasonCode}
Adjuster Rationale: {!$Input:adjusterRationale}

─── WRITE THE MESSAGE ───
Structure (follow strictly):
1. Start with an emoji header: ❌ *Claim {claim number} — REJECTED*
2. Greet the dealer by name warmly
3. State the decision clearly WITHOUT hedging. No "unfortunately" or "we regret"
4. Explain the SPECIFIC reason in plain terms the dealer will understand
   (translate the reason code — e.g., "Coverage Expired" becomes "your
   customer's warranty ended on X before the fault occurred")
5. Reference the adjuster's rationale if it adds useful detail
6. Offer ONE specific next step based on the reason code:
   - "Coverage Expired" or "Mileage Exceeded" → offer GOODWILL path
   - "Wear & Tear" → suggest customer-pay quote
   - "Duplicate Claim" → reference the prior claim
   - "Exclusions" or "Insufficient Evidence" → offer AGENT escalation
7. End respectfully, thanking them for the submission

Constraints:
- Maximum 6 sentences total
- No more than 90 words
- WhatsApp-friendly: use *bold* for key values, no markdown headers,
  no bullet points or tables
- NEVER say "unfortunately", "regret", "system", "policy violation",
  or "per guidelines"
- Write like a human, not a bot

Return ONLY the final message body. No JSON, no preamble, no code fences.
```

---

## Model Settings

| Setting | Value | Why |
|---|---|---|
| Model | **GPT-4o** or **Claude 3.5 Sonnet** | Either handles structured-by-prompt generation well |
| Temperature | **0.6** | Warm + variation (a touch higher than the verdict template which was 0.2) |
| Max Tokens | **400** | Plenty of headroom for 90-word response |

---

## Example Outputs (for QA review)

### Case A — Coverage Expired
**Input:**
- Reason: `Coverage Expired`
- Rationale: `Vehicle warranty ended March 15, fault occurred April 2`

**Expected output:**
```
❌ *Claim WC-K7F3M — REJECTED*

Hi Metro Electra Motors team — thanks for submitting this claim. After review,
the warranty on this vehicle ended on March 15, and the reported battery fault
occurred on April 2, so it falls just outside our coverage period.

If you'd like, reply *GOODWILL* and we'll route this to our warranty policy
manager for a manual exception review. Thanks again for your partnership.
```

### Case B — Duplicate Claim
**Input:**
- Reason: `Duplicate Claim`
- Rationale: `WC-PREV22 filed 14 days ago for same VIN and part, still pending review`

**Expected output:**
```
❌ *Claim WC-K7F3M — REJECTED*

Hi Elite Electra Motors — we spotted an existing claim *WC-PREV22* filed two
weeks ago on this VIN for the same Battery issue. Since that one is still
under review, we're closing this duplicate to keep the thread clean.

If *WC-PREV22* needs an update or you have new evidence, reply to that
original claim or ping *AGENT*.
```

---

## Test Plan After Configuring

1. Pick a claim where you know Eligibility = "Not Covered"
2. In Dev Console → Execute Anonymous:
   ```apex
   Claim c = [SELECT Id, Name FROM Claim WHERE Eligibility__c = 'Not Covered' LIMIT 1];
   String msg = ComposeDealerRejectionMessage.compose(c.Id, 'Coverage Expired',
       'Vehicle warranty ended last month, fault occurred after expiry');
   System.debug('--- REJECTION MESSAGE ---');
   System.debug(msg);
   ```
3. Output should be a warm, specific rejection paragraph — NOT the rule-based
   template
4. Check the Claim's Chatter feed next time you reject via Slack — the
   FeedItem body should show `(PromptTemplate-or-Fallback)` prefix and the
   personalized text

---

## Rollback / Disable

If the template produces bad output, deactivate in Prompt Builder UI. The
Apex invoker detects the unavailable state and falls back to the rule-based
template automatically. Zero code deploy needed to switch paths.
