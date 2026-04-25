# Prompt Template: Claim_Risk_Verdict

Paste the `TEMPLATE BODY` section below into Prompt Builder UI after deploying the
metadata scaffold. Path in org: **Setup → Prompt Builder → Claim Risk Verdict → Edit**.

---

## Template Inputs

Add these as custom inputs in Prompt Builder:

| Input Name | Type | Source |
|---|---|---|
| `Claim` | Record | `Claim` object (bound automatically when invoked from a flow) |
| `DealerTrustScore` | Number | From `Claim.Account.DealerTrustScore__c` |
| `WarrantyEndDate` | Text | From related `AssetWarranty.EndDate` |
| `CoveredCategories` | Text | From related `AssetWarranty.CoveredCategories__c` |
| `PriorClaimCount30d` | Number | Count of claims by the same dealer in last 30 days |
| `SrtBaseline` | Currency | SRT baseline for the part category |
| `SrtVariancePercent` | Number | Variance % vs. SRT baseline |

---

## Template Body

```
You are an Electra Cars warranty adjudication advisor. Given the claim
context below, return a concise structured verdict as VALID JSON ONLY
(no prose, no markdown fences, no preamble).

CLAIM CONTEXT
=============
Claim Number: {!$Input:Claim.Name}
Vehicle: {!$Input:Claim.Vehicle__r.Name}
Part Category: {!$Input:Claim.PartCategory__c}
Symptom: {!$Input:Claim.Symptom__c}
Odometer: {!$Input:Claim.Odometer__c} mi
Dealer Estimate: ${!$Input:Claim.EstimatedCost__c}
Eligibility (rule-based): {!$Input:Claim.Eligibility__c}

DEALER SIGNALS
==============
Dealer: {!$Input:Claim.Account.Name}
Trust Score: {!$Input:DealerTrustScore}/100
Prior claims in last 30 days (same dealer): {!$Input:PriorClaimCount30d}

WARRANTY
========
Warranty End Date: {!$Input:WarrantyEndDate}
Covered Categories: {!$Input:CoveredCategories}

COST ANALYSIS
=============
SRT Baseline: ${!$Input:SrtBaseline}
Variance vs. Baseline: {!$Input:SrtVariancePercent}%

TASK
====
Evaluate for:
1. Fraud risk signals (high dealer velocity, low trust, cost outliers)
2. Symptom-part consistency (does the stated symptom plausibly affect
   the claimed part?)
3. Coverage alignment (is the claim date, mileage, and part within
   the warranty terms?)
4. Cost reasonableness vs. SRT baseline

Return EXACTLY this JSON shape — do not add keys, do not omit keys:
{
  "recommendation": "Approve" | "Reject" | "Needs Clarification",
  "confidence": <integer 0-100>,
  "summary": "<one to two sentence reasoning, specific to this claim>",
  "risk_factors": ["factor 1", "factor 2", "factor 3"]
}

RULES
=====
- If eligibility is "Not Covered" AND no strong goodwill signal, recommend "Reject" with confidence 90+.
- If eligibility is "Likely" AND all signals benign, recommend "Approve" with confidence 85+.
- If eligibility is "Borderline", OR risk factors present, prefer "Needs Clarification".
- Confidence below 70 means the adjuster should look closely.
- risk_factors: return 0-3 short phrases; empty array if clean.
- Never return additional commentary outside the JSON.
```

---

## Model Selection

In Prompt Builder → Model settings, pick one of:

- **OpenAI GPT-4o** (recommended — balance of quality + speed)
- **Anthropic Claude 3.5 Sonnet** (strong at structured JSON adherence)
- **Einstein GPT default** (org-bundled, no external call)

Temperature: **0.2** (we want consistent structured output, not creativity)
Max tokens: **500** (JSON stays small)

---

## Test Flow

In Prompt Builder → Test → select any Claim record → verify the output:
1. Is valid JSON (use `JSON.deserialize()` in Apex to confirm)
2. Has all 4 required keys
3. `recommendation` is one of the 3 allowed values
4. `confidence` is an integer 0-100

If the model occasionally wraps the response in ```json ... ``` fences, the
`InvokeClaimVerdictPrompt.cls` strips those before parsing.
