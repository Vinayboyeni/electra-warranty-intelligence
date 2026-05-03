# 📦 Project Handover — Electra Warranty Intelligence

**Status:** Hackathon-submission-ready · Demo recording pending
**Org:** `vscodeOrg` (https://orgfarm-d6e94e6165.my.salesforce.com)
**Repo:** https://github.com/Vinayboyeni/electra-warranty-intelligence
**Last commit at handover:** `ee9840d`

This document is everything a new contributor needs to understand the project, modify it safely, deploy changes, and demo it. **Read it once front to back, then use the Quick Reference section as your daily working guide.**

---

## 📑 Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [What this system does](#2-what-this-system-does)
3. [Architecture overview](#3-architecture-overview)
4. [End-to-end data flow](#4-end-to-end-data-flow)
5. [Apex class inventory](#5-apex-class-inventory)
6. [Triggers + Platform Events](#6-triggers--platform-events)
7. [Flows](#7-flows)
8. [Custom objects + fields](#8-custom-objects--fields)
9. [Agentforce agents](#9-agentforce-agents)
10. [Prompt Builder templates](#10-prompt-builder-templates)
11. [Permission sets + profiles](#11-permission-sets--profiles)
12. [Data Cloud setup](#12-data-cloud-setup)
13. [Slack integration](#13-slack-integration)
14. [Experience Cloud site (in progress)](#14-experience-cloud-site-in-progress)
15. [Lightning Web Components](#15-lightning-web-components)
16. [How to deploy from scratch](#16-how-to-deploy-from-scratch)
17. [How to run tests + verify](#17-how-to-run-tests--verify)
18. [How to demo](#18-how-to-demo)
19. [Outstanding tasks](#19-outstanding-tasks)
20. [Known issues + workarounds](#20-known-issues--workarounds)
21. [Quick reference](#21-quick-reference)
22. [Glossary](#22-glossary)

---

## 1. Executive Summary

### What we built

A complete AI-driven warranty claim system for Electra Cars (an EV OEM) that replaces their manual email-based prior-authorization process with:

- **Two Agentforce agents** — ARIA (dealer-facing on the dealer-portal Web Chat) and Warranty Approver (OEM-side on Slack)
- **One structured Claim record** in Salesforce Automotive Cloud as the source of truth
- **Auto-routing logic** that handles ~40% of claims with zero human touch
- **Data Cloud telemetry enrichment** that surfaces vehicle fault codes on the approver's review card
- **Live Prompt Builder LLMs** for AI verdicts, empathetic rejection messages, and post-approval repair guidance
- **Branded PDF authorization certificates** generated on every approval
- **Three-tier WhatsApp delivery** (live push → Chatter audit → guaranteed)
- **Customer notifications** to the vehicle owner alongside dealer notifications
- **Partial-approval support** — approver can cap below the dealer's estimate
- **Operational metrics dashboard** (4 tiles)

### Hackathon context

This is a submission for the **Salesforce Automotive Cloud Hackathon**. Mandatory tools (Automotive Cloud + Agentforce) and bonus tools (Digital Engagement, Data Cloud) are all in use.

### Current state

- ✅ All Apex / triggers / flows / fields deployed and tested
- ✅ Both agents working end-to-end (ARIA + Approver)
- ✅ All 3 Prompt Builder templates configured and active (Apex side updated to use ClaimContext text-blob inputs)
- ✅ Documentation, presentation, video script all written
- ✅ Permission set + Admin profile patch deployed
- ⚠️ Experience Cloud site (Automotive template) — created but not yet finished. Pending: page assembly + Messaging for Web wiring + branding
- ⚠️ Demo video — not yet recorded

### Where teammates pick up

Three distinct work tracks remain. See [§19 Outstanding tasks](#19-outstanding-tasks) for the full list.

---

## 2. What this system does

### The user-facing scenarios

| Persona | Channel | Action |
|---|---|---|
| **Dealer service advisor** | WhatsApp / Web Chat | Submits a warranty prior-authorization request via conversational intake |
| **OEM approver** | Slack (`#all-electra-cars-approvers`) | Reviews queued claims, approves/rejects/clarifies/escalates |
| **Vehicle owner (customer)** | WhatsApp | Receives notification when their claim is approved |

### The decision paths

```
                    Dealer submits via ARIA
                           │
                  Auto-routing layer
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
      Auto-approve     Queue for      Auto-reject
      (Likely +        human review   (Not Covered)
       ≤$500 +         on Slack
       conf≥90 +
       trust≥75)
            │              │              │
            │              ▼              │
            │     Approver decides:       │
            │   Approve / Reject /        │
            │   Clarify / Goodwill        │
            │              │              │
            └──────────────┼──────────────┘
                           ▼
                     Outcomes:
            • PDF authorization (if approved)
            • Dealer WhatsApp notification
            • Customer WhatsApp notification
            • Repair guidance (if approved)
            • Empathetic rejection (if rejected)
            • Trust score recalc
```

---

## 3. Architecture overview

### Component layers

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EXTERNAL CHANNELS                            │
│  WhatsApp (Digital Engagement)  ·  Slack  ·  Web (Experience Cloud) │
└──────┬───────────────────────────┬─────────────────┬────────────────┘
       │                           │                 │
       ▼                           ▼                 ▼
┌─────────────────┐    ┌──────────────────────┐    ┌────────────────┐
│  ARIA Agent     │    │  Warranty Approver   │    │ Embedded Chat  │
│  (Service)      │    │   Agent (Employee)   │    │  → ARIA        │
└────────┬────────┘    └──────────┬───────────┘    └────────┬───────┘
         │                        │                         │
         └────────────────────────┼─────────────────────────┘
                                  │
                                  ▼
              ┌───────────────────────────────────────────┐
              │      AGENT ACTION LAYER (Apex + Flow)      │
              │                                            │
              │  Invocable Apex                            │
              │   ├─ FindVehicleByVin                      │
              │   ├─ CheckRecentClaims                     │
              │   ├─ CoverageEngine                        │
              │   ├─ GetWarrantyClaimApprovalContext       │
              │   ├─ ApproveWarrantyClaim                  │
              │   ├─ RejectWarrantyClaim                   │
              │   ├─ RequestDealerClarification            │
              │   ├─ SubmitGoodwillReview                  │
              │   ├─ GetClaimStatus                        │
              │   ├─ GetPendingClaimsQueue                 │
              │   ├─ ValidateRepairEstimate                │
              │   ├─ ImageDamageAnalyzer                   │
              │   ├─ DecodeDiagnosticCode                  │
              │   ├─ GetWhatsAppMediaUrl                   │
              │   └─ InvokeClaimVerdictPrompt              │
              │                                            │
              │  Flows                                     │
              │   ├─ Action_Create_Warranty_Claim (main)   │
              │   ├─ Action_Coverage_Engine (subflow)      │
              │   ├─ Slack_Notify_Approver_Flow            │
              │   └─ Send_WhatsApp_Clarification_Flow      │
              └────────────────┬───────────────────────────┘
                               │
                               ▼
              ┌───────────────────────────────────────────┐
              │           SERVICE / HELPER LAYER           │
              │   ├─ RouteClaimToApproverQueue             │
              │   ├─ GenerateApprovalAuthorization         │
              │   ├─ SendWhatsAppClaimDecision             │
              │   ├─ NotifyCustomerOfApproval              │
              │   ├─ ComposeDealerRejectionMessage         │
              │   ├─ ComposeRepairGuidance                 │
              │   ├─ DealerTrustScoreService               │
              │   ├─ RefreshTelemetrySignals               │
              │   └─ PostToSlackWebhook                    │
              └────────────────┬───────────────────────────┘
                               │
        ┌──────────────────────┼─────────────────────────┐
        ▼                      ▼                         ▼
┌───────────────┐   ┌─────────────────────┐    ┌──────────────────┐
│  Triggers     │   │   Platform Event    │    │  Prompt Builder  │
│ ClaimStatus   │   │  TelemetrySignal__e │    │  3 templates     │
│ Telemetry     │   │                     │    │  (live LLM)      │
│  Signal       │   │                     │    │                  │
└───────┬───────┘   └─────────┬───────────┘    └────────┬─────────┘
        │                     │                         │
        ▼                     ▼                         ▼
┌────────────────────────────────────────────────────────────────┐
│              AUTOMOTIVE CLOUD DATA MODEL                        │
│  Claim · ClaimItem · Vehicle · Asset · AssetWarranty            │
│  Account (Dealer) · Contact (Customer)                          │
│  Custom: SRTMatrix__c                                           │
└──────────────────────┬─────────────────────────────────────────┘
                       │
                       ▼
              ┌───────────────────┐
              │   Data Cloud      │
              │ Vehicle_Telemetry │
              │     __dlm         │
              └───────────────────┘
```

### Tech stack

**Salesforce platform:**
- Automotive Cloud (Vehicle, Asset, AssetWarranty, Account, Contact)
- Agentforce Service Agent (ARIA) + Employee Agent (Approver)
- Einstein Hyper Classifier (agent topic routing)
- Prompt Builder + ConnectApi.EinsteinLLM (3 live templates)
- Data Cloud (Streams, DLO, DMO)
- Digital Engagement (WhatsApp messaging channel)
- Experience Cloud (Automotive template — in progress)
- Slack for Salesforce
- Reports & Dashboards

**Platform features:**
- Apex (~30 classes)
- Apex Triggers (2)
- Platform Events (1)
- Flow (Auto-launched + Record-triggered)
- Visualforce (PDF rendering)
- Lightning Web Components (3 + Aura controller)
- ContentVersion + ContentDistribution (PDF/photo public URLs)

---

## 4. End-to-end data flow

### Path 1 — Auto-approval (no human touch)

```
1. Dealer messages ARIA: "VIN ELXDEMOHAPY010000, brake pad replacement, $180"
2. ARIA collects fields conversationally (Vin, odometer, part, symptom, cost)
3. Dealer says YES → ARIA fires tool_Action_Create_Warranty_Claim
4. Action_Create_Warranty_Claim flow:
   a. Get_Vehicle (SOQL by VIN)
   b. Subflow_Evaluate_Coverage → CoverageEngine.evaluateInvocable()
      → returns Eligibility: Likely
   c. Set_AI_Recommendation (formula: Likely → "Approve" / 90)
   d. Create_Claim_Rec (insert Claim with all fields)
   e. Get_Created_Claim (SOQL the new ID)
   f. Update_Claim_Name (rename to WC-XXXXX)
   g. Invoke_AI_Verdict_Prompt → InvokeClaimVerdictPrompt.run()
      → calls ConnectApi.EinsteinLLM template `Claim_Risk_Verdict`
      → writes back AI_Recommendation/Confidence/Summary
   h. Create_Chatter_Post + Create_Claim_Item
   i. Route_Claim_Apex → RouteClaimToApproverQueue.route()
      → Likely + ≤$500 + conf≥90 + trust≥75 → AUTO-APPROVE
      → Updates Claim.Status = 'Approved', Auto_Approved__c = true
5. ClaimStatusTrigger fires (after-update on Status change)
   → DealerTrustScoreService.recalculate(accountId)
6. ApproveWarrantyClaim NOT called (auto-route already set status)
   ⚠️ Note: in auto-approve path, PDF + WhatsApp would need to be triggered
   separately — currently only fires when ApproveWarrantyClaim is invoked
```

### Path 2 — Slack approval (human in the loop)

```
1-5. Same as Path 1 up through claim creation
6. Route_Claim_Apex sees: Likely + cost > $500 → QUEUE
   → Updates Claim.Status = 'Pending Approver Review'
7. Slack_Notify_Approver_Flow (record-triggered on Status change)
   → calls GetWarrantyClaimApprovalContext.getContext() to build the card
   → calls PostToSlackWebhook to post via the named-credential webhook
8. Approver sees rich card in #all-electra-cars-approvers Slack channel
   Card contains:
   - <!here> ping
   - Claim metadata (vehicle, customer, dealer, part, symptom, cost, mileage)
   - AI Verdict + confidence
   - Eligibility
   - Risk flags
   - 📊 Historical precedent (set by buildSimilarClaimsPrecedent helper)
   - 📡 Vehicle telemetry (Data Cloud — TelemetrySignal__c if populated)
   - Previous claims on this VIN
   - PDF link to view photo (if uploaded)
   - Salesforce record link
   - Shortcut commands
9. Approver replies in Slack: "@Electra Cars Warranty Approver Agent approve at 1700 — battery cost too high"
10. Approver Agent reasoning:
    a. agent_router routes to ClaimReview subagent (intent: "approve")
    b. ClaimReview STEP 1: token extraction → set_variable_claim_number
    c. tool_GetWarrantyClaimApprovalContext (loads claim context)
    d. STEP 4A APPROVE: PARTIAL-AMOUNT detection ("at 1700")
    e. set_variable_decision_rationale (text after rationale prompt)
    f. set_variable_approved_amount (1700)
    g. Above-$2000 confirm? Effective = 1700, no need
    h. tool_ApproveWarrantyClaim
11. ApproveWarrantyClaim.approve():
    a. Status guard (skip if already decided)
    b. claim.Status = 'Approved'; claim.ApprovalDate__c = now
    c. claim.ApprovedAmount = 1700 (partial cap)
    d. update updates;
    e. GenerateApprovalAuthorization.generate(claim.Id)
       → renders ApprovalAuthorizationPDF.page as PDF
       → ContentVersion + ContentDistribution
       → returns public URL
    f. SendWhatsAppClaimDecision.notify(claimId, APPROVED, null, rationale, pdfUrl, 1700)
       → tries push via active MessagingSession (Tier 1)
       → falls back to Chatter audit (Tier 2)
       → body includes:
         - "✅ Claim WC-XXXXX — APPROVED"
         - 💰 Approved amount: $1700 (capped from $2100)
         - 📄 PDF link
         - 🔧 Repair guidance (from Compose_Repair_Guidance_Message template)
    g. NotifyCustomerOfApproval.send(claimId, pdfUrl)
       → resolves Vehicle → Asset → Contact → MobilePhone
       → tries WhatsApp push, falls to Chatter audit
12. ClaimStatusTrigger → DealerTrustScoreService.recalculate(accountId)
13. Slack approver sees: "✅ WC-XXXXX APPROVED. Approved at $1700 (capped from $2100)."
```

### Path 3 — Auto-reject

```
1-5. Same up to Route_Claim_Apex
6. Coverage engine returned Eligibility = "Not Covered" (out of warranty / wear item)
7. Route_Claim_Apex → AUTO-REJECT
   → Claim.Status = 'Rejected'
   → DecisionRationale__c = "Auto-rejected: Coverage engine determined part/vehicle is not covered."
8. ⚠️ Note: SendWhatsAppClaimDecision is not currently called from auto-reject path
   (only called from RejectWarrantyClaim invocable). Auto-reject just updates status.
```

### Path 4 — Clarification (RFI)

```
1. Approver in Slack: "@... clarify WC-XXXXX please send diagnostic codes"
2. Approver Agent → STEP 4C → tool_RequestDealerClarification
3. RequestDealerClarification.requestClarification():
   a. Status guard (skip if already decided)
   b. Status = 'Needs More Info'
   c. ClarificationRequest__c = "please send diagnostic codes"
   d. RequiresFollowUp__c = true
4. Send_WhatsApp_Clarification_Flow (record-triggered on Status change)
   → calls SendWhatsAppRFINotification
   → posts message to dealer's WhatsApp session
```

### Path 5 — Goodwill exception

```
1. Approver in Slack: "@... goodwill WC-XXXXX customer is loyal long-term"
2. Approver Agent → STEP 4D
   a. set_variable_goodwill_intent_confirmed = True (THIS IS THE GATE)
   b. Asks for justification
   c. set_variable_decision_rationale
   d. tool_SubmitGoodwillReview
3. SubmitGoodwillReview.submit():
   a. Authorization_Type__c = 'Goodwill Exception' (picklist value)
   b. Priority__c = 'High'
   c. DealerResponseSummary__c = goodwill reason
4. Status remains Pending Approver Review (manager will reset later)
```

### Path 6 — Photo upload (during or after intake)

```
1. Dealer uploads a photo on WhatsApp
2. Salesforce Digital Engagement attaches photo as ContentVersion to MessagingSession
3. ARIA reasoning: "if dealer sends a photo, call tool_GetWhatsAppMediaURL then tool_AnalyzeImageDamage"
4. GetWhatsAppMediaUrl.getMediaUrl():
   a. Find MessagingSession for this dealer
   b. SELECT ContentDocumentLink WHERE LinkedEntityId = sessionId
   c. Return imageUrl (sfc/shepherd URL) + contentDocumentId
5. ImageDamageAnalyzer.analyze():
   a. Mocked vision analysis (switch on part name)
   b. Updates Claim.AI_Image_Analysis__c with the textual analysis
   c. Parses ContentVersion ID from imageUrl
   d. Creates ContentDocumentLink → links file to Claim (Files related list)
   e. Creates public ContentDistribution
   f. Updates Claim.PhotoPublicUrl__c with the public URL
6. Approver Slack card shows:
   - *Photo Analysis: <text from ImageDamageAnalyzer>*
   - 📸 View photo: <click to open> (links to public ContentDistribution URL)
```

### Path 7 — Data Cloud telemetry enrichment

```
1. Telematics events ingested as CSV → Vehicle_Telemetry__dlm (Data Cloud DLM)
2. RefreshTelemetrySignals.refresh() runs (manual or scheduled):
   a. SOQL Vehicle_Telemetry__dlm for events in last 30 days
   b. Aggregate per VIN: faultCounts, offNetworkCharges, lastEventDate
   c. EventBus.publish() → TelemetrySignal__e Platform Events
3. TelemetrySignalTrigger (after-insert on TelemetrySignal__e):
   a. For each event, look up Vehicle by VIN__c
   b. Find Claim WHERE Vehicle__c = vehicle.AssetId
   c. Update claim.TelemetrySignal__c with formatted summary
4. Next time GetWarrantyClaimApprovalContext loads the claim,
   the Slack body includes:
   :satellite_antenna: *Vehicle telemetry (Data Cloud):* 3 fault codes,
   1 off-network charges (last 30d). Last event: Apr 19, 2026
```

---

## 5. Apex class inventory

### Agent-facing classes (called via @InvocableMethod from agents)

| Class | Method | Called by | Purpose |
|---|---|---|---|
| `FindVehicleByVin` | `findByVin` | ARIA | Look up vehicle + active warranty by VIN |
| `CheckRecentClaims` | `checkRecent` | ARIA | Detect duplicate claims (same VIN+part within 30d) |
| `CoverageEngine` | `evaluateInvocable` | ARIA (via subflow) | Evaluate Likely/Borderline/Not Covered |
| `DecodeDiagnosticCode` | `decode` | ARIA | Translate DTC codes to human descriptions |
| `ValidateRepairEstimate` | `validate` | ARIA | Compare cost vs SRT matrix baseline (±20%) |
| `GetWhatsAppMediaUrl` | `getMediaUrl` | ARIA | Get URL of dealer-uploaded photo |
| `ImageDamageAnalyzer` | `analyze` | ARIA | (Mocked) vision AI on photo + persist analysis |
| `GetClaimStatus` | `getStatus` | ARIA + Approver | Look up claim by number/VIN |
| `GetWarrantyClaimApprovalContext` | `getContext` | Approver + Slack flow | Build the rich Slack card body |
| `GetPendingClaimsQueue` | `fetch` | Approver | List all queue claims |
| `ApproveWarrantyClaim` | `approve` | Approver | Approve a claim (with optional partial amount) |
| `RejectWarrantyClaim` | `reject` | Approver | Reject a claim with reason code |
| `RequestDealerClarification` | `requestClarification` | Approver | Send RFI to dealer |
| `SubmitGoodwillReview` | `submit` | Approver | Flag claim as Goodwill exception |
| `SubmitDealerClarificationResponse` | `submitResponse` | ARIA (ApproverFollowUp subagent) | Capture dealer's RFI response |
| `InvokeClaimVerdictPrompt` | `run` | Action_Create_Warranty_Claim flow | Live LLM verdict via Prompt Builder |

### Service / helper classes (called by other Apex)

| Class | Called by | Purpose |
|---|---|---|
| `RouteClaimToApproverQueue` | Action_Create_Warranty_Claim flow | Auto-approve / auto-reject / queue logic |
| `GenerateApprovalAuthorization` | ApproveWarrantyClaim | Render PDF, ContentVersion, ContentDistribution, return public URL |
| `SendWhatsAppClaimDecision` | ApproveWarrantyClaim, RejectWarrantyClaim | Three-tier WhatsApp delivery for decision |
| `SendWhatsAppRFINotification` | Send_WhatsApp_Clarification_Flow | WhatsApp push for RFI |
| `ComposeDealerRejectionMessage` | SendWhatsAppClaimDecision | Live LLM empathetic rejection message (Compose_Dealer_Rejection_Message template) |
| `ComposeRepairGuidance` | SendWhatsAppClaimDecision | Live LLM repair guidance (Compose_Repair_Guidance_Message template) |
| `NotifyCustomerOfApproval` | ApproveWarrantyClaim | WhatsApp the vehicle owner separately |
| `DealerTrustScoreService` | ClaimStatusTrigger | Recalculate Account.DealerTrustScore__c |
| `RefreshTelemetrySignals` | Manually run / scheduled | Read DLM → publish Platform Events |
| `PostToSlackWebhook` | Slack_Notify_Approver_Flow | Post claim card to Slack via named credential |
| `ClaimStatusController` | LWC `claimStatusLookup` | @AuraEnabled wrapper for portal status lookup |

### Utility / wrapper classes

| Class | Purpose |
|---|---|
| `CoverageEvaluateInput`, `CoverageEvaluateResult` | Wrapper types for CoverageEngine |
| `FindVehicleByVinInput`, `FindVehicleByVinResult` | Wrapper types for FindVehicleByVin |
| `CreateWarrantyClaimInput`, `CreateWarrantyClaimResult` | Wrapper types (legacy) |
| `WarrantyClaimFlowSupport` | Helper used by flow elements |
| `DemoScenarioSeeder` | Creates 10 demo VINs + scenarios for testing |

### Test classes (kept for future test coverage)

`ApproveWarrantyClaimTest`, `CoverageEngineTest`, `CreateWarrantyClaimTest`, `FindVehicleByVinTest`, `GetWarrantyClaimApprovalContextTest`, `ImageDamageAnalyzerTest`, `LinkUploadedEvidenceToClaimTest`, `RejectWarrantyClaimTest`, `RequestDealerClarificationTest`, `RouteClaimToApproverQueueTest`, `SendWarrantyExpiryAlertTest`, `SendWhatsAppRFINotificationTest`, `SubmitDealerClarificationResponseTest`, `SubmitGoodwillReviewTest`, `WarrantyAgentActionsTest`, `WarrantyClaimSlackFlowTest`, `TestDataFactory`

### Misc / orphaned (not actively wired)

- `New_Wto_Ext` — leftover from web-to-claim experiment
- `ProposeTradeInAndTestDrive` — built but not invoked anywhere; would create an Opportunity from a high-cost claim (roadmap)
- `SDO_Tool_TEGenController` — Salesforce demo org pre-built file
- `CreatePriorAuthorizationClaim` / `CreateWarrantyClaim` — superseded by `Action_Create_Warranty_Claim` flow
- `FindVehicleWarrantyByVin` — alternative to `FindVehicleByVin`
- `SendWarrantyExpiryAlert` — built but no scheduler hook in place
- `LinkUploadedEvidenceToClaim` — superseded by `ImageDamageAnalyzer`
- `HackathonDataPrep` — one-time data setup
- `ElectraHackathonDataSeeder` — alternative to `DemoScenarioSeeder`
- `CheckRecentClaims` — used by ARIA for duplicate detection

---

## 6. Triggers + Platform Events

### Triggers

| Trigger | Object | Event | Purpose |
|---|---|---|---|
| `ClaimStatusTrigger` | Claim | after-update | When `Status` flips to Approved/Rejected, recalculate `Account.DealerTrustScore__c` over last 90 days |
| `TelemetrySignalTrigger` | TelemetrySignal__e | after-insert | When a telemetry Platform Event fires, find Claims for that VIN and update `Claim.TelemetrySignal__c` |

### Platform Event

**`TelemetrySignal__e`** — fires whenever vehicle telemetry should propagate to the Slack approver card.

| Field | Type |
|---|---|
| `VIN__c` | Text(17) |
| `FaultCount30d__c` | Number |
| `OffNetworkCharges30d__c` | Number |
| `LastEventDate__c` | DateTime |

Published by `RefreshTelemetrySignals.refresh()` which reads from the Data Cloud DLM and aggregates per VIN.

---

## 7. Flows

### Main orchestrator

**`Action_Create_Warranty_Claim`** (autolaunched flow) — invoked by ARIA's `tool_Action_Create_Warranty_Claim`.

Element chain:

```
Get_Vehicle (SOQL by VIN)
  → Subflow_Evaluate_Coverage (calls Action_Coverage_Engine subflow)
  → Set_AI_Recommendation (assignment using formula values)
  → Create_Claim_Rec (insert Claim with all fields)
  → Get_Created_Claim (re-query for ID)
  → Update_Claim_Name (rename to WC-XXXXX based on auto-number)
  → Invoke_AI_Verdict_Prompt (calls InvokeClaimVerdictPrompt — live LLM)
  → Create_Chatter_Post (FeedItem on Claim)
  → Create_Claim_Item
  → Route_Claim_Apex (calls RouteClaimToApproverQueue)
  → Set_Summary_Results (assigns output variables)
```

### Record-triggered flows

| Flow | Trigger | Action |
|---|---|---|
| `Slack_Notify_Approver_Flow` | Claim after-save where Status = 'Pending Approver Review' | Calls `GetWarrantyClaimApprovalContext` + `PostToSlackWebhook` to post the rich card |
| `Send_WhatsApp_Clarification_Flow` | Claim after-save where Status = 'Needs More Info' | Calls `SendWhatsAppRFINotification` to push WhatsApp |

### Subflows (called from main orchestrator or as actions)

- `Action_Coverage_Engine` — wraps CoverageEngine.evaluateInvocable
- `Action_Approve_Claim` — wraps ApproveWarrantyClaim
- `Action_Reject_Claim` — wraps RejectWarrantyClaim
- `Action_Request_Clarification` — wraps RequestDealerClarification
- `Action_Submit_Goodwill_Review` — wraps SubmitGoodwillReview
- `Action_Get_Approval_Context` — wraps GetWarrantyClaimApprovalContext
- `Action_Get_Claim_Status` — wraps GetClaimStatus
- `Action_Image_Damage_Analyzer` — wraps ImageDamageAnalyzer
- `Action_Get_WhatsApp_Media_URL` — wraps GetWhatsAppMediaUrl
- `Action_Decode_Diagnostic_Code` — wraps DecodeDiagnosticCode
- `Action_Find_Vehicle_By_VIN` — wraps FindVehicleByVin
- `Action_Validate_Repair_Estimate` — wraps ValidateRepairEstimate
- `Action_Submit_Dealer_Response` — wraps SubmitDealerClarificationResponse
- `Action_Check_Recent_Claims` — wraps CheckRecentClaims
- `Action_Link_Uploaded_Evidence` — wraps LinkUploadedEvidenceToClaim
- `Action_Route_Claim_to_Queue` — wraps RouteClaimToApproverQueue (used by some flows; the main orchestrator calls Apex directly)

### Other / legacy flows

- `Approver_Clarification_Flow` — DEACTIVATED (was orphaned; agent calls Apex directly)
- `Dealer_Intake_Flow`, `Dealer_Clarification_Response_Flow`, `Claim_Queue_Routing_Flow`, `Get_Claim_Status`, `Find_Vehicle_Warranty_By_Vin`, `Evaluate_Coverage`, `Create_Prior_Authorization_Claim`, `Agent_Create_Warranty_Claim` — earlier iterations, kept for reference but not in the live path
- `Warranty_Expiry_Alert_Flow` — built but no scheduler hooked up
- `Messages_Routed_to_Agents_and_Queues`, `Route_Conversations_to_Agentforce_Service_Agent` — Digital Engagement messaging routing
- `SDO_*` — Salesforce demo org pre-built flows; ignore

---

## 8. Custom objects + fields

### Standard Automotive Cloud objects in use

- **Claim** — central record (custom + standard fields)
- **ClaimItem** — line items per claim
- **Vehicle** — vehicle catalog (linked via Asset)
- **Asset** — sold vehicle as an asset (links Vehicle ↔ Contact)
- **AssetWarranty** — coverage windows queried by CoverageEngine
- **Account** — dealer
- **Contact** — vehicle owner

### Custom Claim fields

| Field | Type | Set by | Read by |
|---|---|---|---|
| `Status__c` | Picklist | Sync mirror of standard Status | (legacy) |
| `Vehicle__c` | Lookup | ARIA flow (= AssetId) | Coverage engine, context builder |
| `PartCategory__c` | Picklist (Battery, Engine, etc.) | ARIA | Routing, AI verdict |
| `Symptom__c` | Long Text Area | ARIA | AI verdict, rejection composer |
| `Diagnosis__c` | Long Text Area | ARIA (DTC decode) | Repair guidance |
| `Odometer__c` | Number | ARIA | Coverage engine, AI verdict |
| `EstimatedCost__c` | Currency | ARIA | Auto-routing, partial-approval comparison |
| `Eligibility__c` | Picklist (Likely, Borderline, Not Covered) | CoverageEngine | Routing, AI verdict, Slack card |
| `EligibilityRationale__c` | Long Text Area | CoverageEngine | Slack card |
| `AI_Recommendation__c` | Picklist (Approve, Reject, Needs Clarification) | InvokeClaimVerdictPrompt | Slack card, routing |
| `AI_Confidence__c` | Number(5,0) | InvokeClaimVerdictPrompt | Auto-approve threshold check |
| `AI_Summary__c` | Long Text Area | InvokeClaimVerdictPrompt | Slack card |
| `AI_Image_Analysis__c` | Long Text Area | ImageDamageAnalyzer | Slack card |
| `AuthorizationPdfUrl__c` | (deleted — Industries Cloud Claim rejected Url type) | — | — |
| `PhotoPublicUrl__c` | LongTextArea(500) | ImageDamageAnalyzer | Slack card |
| `TelemetrySignal__c` | LongTextArea(500) | TelemetrySignalTrigger | Slack card |
| `Authorization_Type__c` | Picklist (Prior Authorization, Post Repair Claim, Goodwill Exception) | Action_Create_Warranty_Claim flow / SubmitGoodwillReview | Slack card |
| `Auto_Approved__c` | Checkbox | RouteClaimToApproverQueue | Reporting |
| `ApprovalDate__c` | DateTime | ApproveWarrantyClaim, RouteClaimToApproverQueue | Audit |
| `RejectionDate__c` | DateTime | RejectWarrantyClaim | Audit |
| `DecisionRationale__c` | Long Text Area | Approver agent | Audit, dashboard |
| `ReasonCode__c` | Picklist | RejectWarrantyClaim | Rejection composer |
| `ApproverQueue__c` | Text | RouteClaimToApproverQueue | Slack routing |
| `ApproverSlackRef__c` | Text | Approver agent | Audit |
| `ClarificationRequest__c` | Long Text Area | RequestDealerClarification | Status lookup |
| `RequiresFollowUp__c` | Checkbox | RequestDealerClarification | Slack card |
| `DealerResponseSummary__c` | Long Text Area | SubmitDealerClarificationResponse / SubmitGoodwillReview | Audit |
| `DealerWhatsAppNumber__c` | Text | ARIA flow | SendWhatsAppClaimDecision |
| `Priority__c` | Picklist | ARIA flow / SubmitGoodwillReview | Slack queue ordering |
| `SLA_Due_Date__c` | DateTime | ARIA flow | Status lookup |
| `SubmissionChannel__c` | Picklist (WhatsApp, Web, Email) | ARIA flow | Reporting |
| `MessagingSessionId__c` | Text | (intended use; not always set) | Future routing |
| `DecisionTimeHours__c` | Formula(Number) | — | Dashboard |
| `DecisionPath__c` | Formula(Text) | — | Dashboard |

### Custom Account field

| Field | Type | Set by | Read by |
|---|---|---|---|
| `DealerTrustScore__c` | Number(3,0) | Manually seeded + DealerTrustScoreService recalc | Auto-routing, Slack card |

### Custom objects

- **`SRTMatrix__c`** — Standard Repair Time matrix used by `ValidateRepairEstimate`. ~10 baselines pre-seeded for common parts (Battery, Engine, etc.).

---

## 9. Agentforce agents

### ARIA — `Warranty_Dealer_Intake_Agentt_4` (AgentforceServiceAgent)

**Channel:** WhatsApp via Digital Engagement, Web Chat (planned via Experience Cloud)

**Topology:** 7 subagents
- `agent_router` (entry point — Einstein Hyper Classifier)
- `WarrantyIntake` (main intake flow with 11-step reasoning)
- `ClaimStatusInquiry`
- `WarrantyPolicyFAQ`
- `GoodwillReview`
- `ApproverFollowUp`
- `Escalation`
- `off_topic`

**Variables (key ones):**
- `vin`, `vehicle_id`, `dealer_id`, `customer_id`
- `odometer`, `part_category`, `symptom`, `requested_amount`, `fault_date`, `repair_order_number`
- `coverage_eligibility`, `coverage_rationale`
- `claim_id`, `claim_number`, `claim_status`
- `user_confirmed` (deterministic submit gate)
- `srt_justification`
- `image_url`, `damage_analysis`
- `slack_notified`
- Plus linked vars: `EndUserId`, `RoutableId`, `ContactId`

**Setters (all `@utils.setVariables`):**
- `set_variable_vin`, `set_variable_odometer`, `set_variable_part_category`, `set_variable_symptom`, `set_variable_fault_date`, `set_variable_requested_amount`
- `set_variable_user_confirmed` (gate before submission)
- `set_variable_srt_justification`
- `set_variable_reset_after_submit` (clears state for next claim in same session)

**Tools (Apex/flow targets):**
- `tool_FindVehicleByVin` → apex://FindVehicleByVin
- `tool_CheckRecentClaims` → apex://CheckRecentClaims
- `tool_EvaluateCoverage` → apex://CoverageEngine
- `tool_DecodeDiagnosticCode` → apex://DecodeDiagnosticCode
- `tool_ValidateRepairEstimate` → apex://ValidateRepairEstimate
- `tool_Action_Create_Warranty_Claim` → flow://Action_Create_Warranty_Claim
- `tool_GetWhatsAppMediaURL` → apex://GetWhatsAppMediaUrl
- `tool_AnalyzeImageDamage` → apex://ImageDamageAnalyzer
- (ClaimStatusInquiry) `GetClaimStatus` → apex://GetClaimStatus
- (GoodwillReview) `SubmitGoodwillReview` → apex://SubmitGoodwillReview
- (ApproverFollowUp) `SubmitClarificationResponse` → apex://SubmitDealerClarificationResponse

**System instructions polish (recently added):**
- PERSONALITY block (warm, senior service writer voice)
- AUTOMOTIVE EXPERTISE block (TSB-2401, BMS vs cell, off-network charge fraud, wear items)
- EFFICIENCY block (terse with regulars, educational with newbies)
- English-only rule

### Warranty Approver Agent — `Warranty_Approver_Agent_3` (AgentforceEmployeeAgent)

**Channel:** Slack (`#all-electra-cars-approvers`)

**Topology:** 7 subagents
- `agent_router` (entry point with sticky-session rule)
- `ClaimReview` (main decision flow)
- `QueueOverview`
- `PolicyFAQ`
- `Escalation`
- `off_topic`
- `ambiguous_question`

**Variables (key ones):**
- `claim_id`, `claim_number`, `claim_status`
- `dealer_name`, `dealer_trust_score`
- `vin`, `customer_name`, `vehicle_model`, `odometer`
- `part_category`, `symptom`, `eligibility`, `estimated_cost`
- `warranty_end_date`, `risk_flags`, `previous_claims`
- `ai_summary`, `ai_recommendation`, `ai_confidence`, `ai_image_analysis`
- `decision_rationale`, `reason_code`, `clarification_question`
- `goodwill_intent_confirmed` (deterministic Goodwill gate)
- `approved_amount` (partial-approval support)
- `context_loaded` (sticky-session flag)
- `slack_reference`

**Setters:**
- `set_variable_claim_number`, `set_variable_context_loaded`, `set_variable_reset_for_new_claim`
- `set_variable_decision_rationale`, `set_variable_reason_code`, `set_variable_clarification_question`
- `set_variable_goodwill_intent_confirmed`, `set_variable_approved_amount`

**Tools:**
- `tool_GetWarrantyClaimApprovalContext` → apex://GetWarrantyClaimApprovalContext
- `tool_ApproveWarrantyClaim` → apex://ApproveWarrantyClaim (now passes `approvedAmount`)
- `tool_RejectWarrantyClaim` → apex://RejectWarrantyClaim
- `tool_RequestDealerClarification` → apex://RequestDealerClarification
- `tool_SubmitGoodwillReview` → apex://SubmitGoodwillReview
- (QueueOverview) `tool_GetClaimStatus`, `tool_GetPendingClaimsQueue`

**System instructions polish (recently added):**
- PERSPECTIVE block ("Read:" framing of every claim)
- PRECEDENT block (cite historical patterns)
- AUTOMOTIVE EXPERTISE block (BMS-vs-cell, TSB-2401, fraud signals)
- AUTHORITY block (partial-approval support documented)
- COMMUNICATION STYLE (one-line confirmations)

**Reasoning steps in ClaimReview:**
- STEP 1 — LOAD CONTEXT (with TOKEN EXTRACTION RULE)
- STEP 2 — SAFETY / FRAUD CHECK
- STEP 3 — ALREADY-DECIDED GUARD
- STEP 4 — ACTION ROUTING
  - 4A — APPROVE (with PARTIAL-AMOUNT detection)
  - 4B — REJECT (deterministic 3-turn flow)
  - 4C — CLARIFY (decisive in one turn)
  - 4D — GOODWILL (requires explicit intent)
- GUARDRAILS (no skip, no act on already-decided, etc.)

### ⚠️ Agent file deploy issue

Both `.agent` files are blocked from CLI deploy by a Salesforce platform syntax migration in progress (the `@subagent` keyword vs. newer `@topic` keyword). Local source has the latest fixes. **To apply changes to the org, paste via Agentforce Builder UI** — see [§19 Outstanding tasks](#19-outstanding-tasks).

---

## 10. Prompt Builder templates

Three templates configured + activated in the org. All called via `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate()`. All have rule-based fallbacks in their respective Apex invokers.

### `Claim_Risk_Verdict`

- **Type:** Flex
- **Resource:** `ClaimContext` (Text) — pre-rendered field blob from Apex
- **Output:** JSON `{recommendation, confidence, summary}`
- **Invoker:** `InvokeClaimVerdictPrompt.cls`
- **Called from:** `Action_Create_Warranty_Claim` flow
- **Writes back to:** `Claim.AI_Recommendation__c`, `AI_Confidence__c`, `AI_Summary__c`
- **Fallback:** Rule-based verdict mirroring CoverageEngine output (Likely → Approve/90, Not Covered → Reject/95, else Needs Clarification/50)

### `Compose_Repair_Guidance_Message`

- **Type:** Flex
- **Resource:** `ClaimContext` (Text)
- **Output:** Plain text — 3-4 bullets + italicized timeline line
- **Invoker:** `ComposeRepairGuidance.cls`
- **Called from:** `SendWhatsAppClaimDecision` (when decision == APPROVED)
- **Output goes to:** Dealer WhatsApp body (after the PDF link)
- **Fallback:** Rule-based per-category tips (battery, brake, motor, infotainment, generic)

### `Compose_Dealer_Rejection_Message`

- **Type:** Flex
- **Resources:** `ClaimContext` (Text), `ReasonCode` (Text), `AdjusterRationale` (Text)
- **Output:** Plain text — empathetic personalized rejection message
- **Invoker:** `ComposeDealerRejectionMessage.cls`
- **Called from:** `SendWhatsAppClaimDecision` (when decision == REJECTED)
- **Output goes to:** Dealer WhatsApp body
- **Fallback:** Rule-based template with reason code + rationale stubs

### Important detail — input shape

Apex passes the claim context as a **single text blob** to a `Input:ClaimContext` resource, NOT as a Map<->Object input. The earlier nested `{!$Input:Claim.PartCategory__c}` references didn't resolve from a Map and the LLM saw empty fields. Pre-rendering the blob in Apex sidesteps this entirely.

```apex
String contextBlob =
  'Claim details:\n'
  + '- Claim number: ' + c.Name + '\n'
  + '- Part category: ' + c.PartCategory__c + '\n'
  + '- Reported symptom: ' + c.Symptom__c + '\n'
  + ...;
ConnectApi.WrappedValue ctxWv = new ConnectApi.WrappedValue();
ctxWv.value = contextBlob;
inp.inputParams = new Map<String, ConnectApi.WrappedValue>{
    'Input:ClaimContext' => ctxWv,
    'Input:Claim'        => claimWv  // legacy fallback for old templates
};
```

The legacy `Input:Claim` Map is sent alongside for backward compat.

---

## 11. Permission sets + profiles

### Permission set `Agentforce_Permissions`

Comprehensive permset covering everything the Agentforce service user needs.

**Assigned via:** Setup → Users → \[user\] → Permission Set Assignments

**Includes:**
- ~36 Apex class accesses
- 80+ Claim field permissions (read+edit)
- Standard object access (Account, Asset, AssetWarranty, Claim, ClaimItem, Contact, Vehicle)
- API Enabled, Run Reports user permissions
- Flow accesses for all custom flows
- Agent access (`Warranty_Approver_Agent_3`)

### Permission set `Warranty_Claims_User`

Lighter permset for end users (claim viewers).

### Profile `Admin` (patched)

Patched to explicitly grant:
- All warranty Apex class accesses (33+ classes)
- `Claim.TelemetrySignal__c`, `Account.DealerTrustScore__c`, etc.
- API Enabled

This is additive — Salesforce merges with existing System Administrator profile permissions.

---

## 12. Data Cloud setup

### Components

| Component | Status | Purpose |
|---|---|---|
| **Data Stream:** `Vehicle_Telemetry_Events` | Live | CSV upload of telematics events (vin, event_date, event_type, fault_code, location) |
| **DLO** (auto-generated by stream) | Live | Raw event storage |
| **DMO:** `Vehicle_Telemetry__dlm` | Live | Mapped data, queryable from Apex SOQL |
| **Calculated Insight:** `Telemetry_Risk_Rollup_cio` | Configured (may not auto-fire) | Aggregates per VIN (fault count, off-network charges, last event) |
| **Data Action:** `Telemetry Risk To Claim` | Configured (intermittent) | Was supposed to publish Platform Events from CI; bypassed by RefreshTelemetrySignals |
| **Apex bridge:** `RefreshTelemetrySignals.cls` | Live | Reads DLM directly via SOQL, aggregates, publishes Platform Events |

### Important — we bypass the Data Action

The original architecture relied on **Data Cloud Data Action → Platform Event** firing automatically when the CI refreshed. This was unreliable in our org (Data Cloud UI quirks). We replaced it with:

- `RefreshTelemetrySignals.cls` — reads `Vehicle_Telemetry__dlm` directly, aggregates, publishes Platform Events programmatically.

This is **more reliable** but requires manual triggering OR scheduling:

```bash
# Manual trigger
sf apex run -f scripts/apex/seed_demo_telemetry.apex -o vscodeOrg

# Or schedule (via Apex)
sf apex run -f scripts/apex/schedule_telemetry_refresh.apex -o vscodeOrg
```

The schedule script runs `RefreshTelemetrySignals` every hour via System.schedule.

### Sample data

`scripts/datacloud/telematics-events.csv` has 9 rows for 4 demo VINs. Re-upload via the Data Stream UI to refresh.

---

## 13. Slack integration

### Channel

`#all-electra-cars-approvers` — the OEM approver pod's Slack channel.

### Two integration paths used

1. **Slack for Salesforce app** — the Approver agent posts/responds in-channel via the agent's Slack-Salesforce binding (configured in Agent Builder).
2. **Outgoing webhook** — `Slack_Notify_Approver_Flow` posts the rich claim card via:
   - **Named Credential:** `Slack_Webhook_Approver`
   - **Endpoint:** the webhook URL (REDACTED in repo for security; configured in the live org)

### Posting the claim card

Flow: `Slack_Notify_Approver_Flow` (record-triggered on Status = "Pending Approver Review")
- Calls `GetWarrantyClaimApprovalContext` to assemble the slackMessageBody
- Calls `PostToSlackWebhook.post()` to push it to the channel

### Approver replies

The approver `@`-mentions the agent in the channel. The agent receives the message via the Slack-Agentforce integration, processes it through the Approver Agent reasoning, and replies in-thread.

---

## 14. Experience Cloud site (in progress)

### Site

- **Name:** Electra Dealer Portal
- **Template:** Automotive (Salesforce-provided)
- **URL path:** `/electra-dealers` (configurable)

### Components shipped (LWCs)

See [§15 Lightning Web Components](#15-lightning-web-components).

### Pending UI work

1. Configure guest/public access (no-login demo path)
2. Drop the 3 LWCs onto the home page in Experience Builder
3. Create Messaging-for-Web channel + Embedded Service Deployment
4. Bind the deployment to ARIA
5. Paste the deployment's JS snippet into Builder → Settings → Advanced → Head Markup
6. Brand the theme (Electra blue, logo)
7. Publish + test in incognito browser

---

## 15. Lightning Web Components

### Built and deployed

| LWC | Location | Purpose |
|---|---|---|
| `claimStatusLookup` | `force-app/main/default/lwc/claimStatusLookup/` | Public-facing status tracker. Input claim number or VIN → renders branded result card with status badge, dealer, dates, estimated/approved cost, partial-cap line, decision rationale, next-step narrative |
| `electraHero` | `force-app/main/default/lwc/electraHero/` | Branded hero banner with headline, 2 CTAs, 3 stat tiles |
| `warrantyKnowledge` | `force-app/main/default/lwc/warrantyKnowledge/` | 3 policy cards (standard / EV battery / wear items) + goodwill footer |

All three target `lightningCommunity__Page` so they drag-drop into Experience Cloud's page builder.

### Apex controller for the LWCs

`ClaimStatusController.cls` — `@AuraEnabled lookup(claimNumber, vin)` returns a `ClaimStatusInfo` wrapper. Without sharing so guest users can read by their own claim number/VIN.

### Styling

CSS is component-scoped. Electra blue palette (#0B5394 primary, #073764 dark, #16B26B success, #D7263D rejection, #F0A30A pending).

---

## 16. How to deploy from scratch

### Prerequisites

- Salesforce CLI (`sf`) installed
- Org with Automotive Cloud, Agentforce, Data Cloud, Digital Engagement licenses
- Cloned repo

### Step 1 — Authenticate

```bash
sf org login web --alias vscodeOrg
```

### Step 2 — Deploy metadata

```bash
sf project deploy start -d force-app -o vscodeOrg
```

This deploys all classes, triggers, flows, fields, LWCs, permission sets, profile patches, page layouts, and the Platform Event in one shot.

⚠️ **Expected failure:** `.agent` files may fail compilation due to the `@subagent` syntax issue. Skip those:

```bash
sf project deploy start \
  -d force-app/main/default/classes \
  -d force-app/main/default/triggers \
  -d force-app/main/default/flows \
  -d force-app/main/default/objects \
  -d force-app/main/default/lwc \
  -d force-app/main/default/pages \
  -d force-app/main/default/permissionsets \
  -d force-app/main/default/profiles \
  -o vscodeOrg
```

### Step 3 — UI configuration in the org

These cannot be CLI-deployed. Do them in the Salesforce UI:

1. **Agent files** — pull the contents of `Warranty_Approver_Agent_3.agent` and `Warranty_Dealer_Intake_Agentt_4.agent`, paste into the Agentforce Builder UI for each agent. Save → Activate.
2. **Prompt templates** — create 3 Flex templates in Setup → Prompt Builder:
   - `Claim_Risk_Verdict` — single Text resource named `ClaimContext`, body uses `{!$Input:ClaimContext}` once + decision rules
   - `Compose_Repair_Guidance_Message` — same shape
   - `Compose_Dealer_Rejection_Message` — `ClaimContext` + `ReasonCode` + `AdjusterRationale` Text resources
   - Activate each
3. **Slack integration** — install Slack for Salesforce app, connect to `#all-electra-cars-approvers`, bind the Approver agent
4. **WhatsApp channel** — Setup → Messaging Settings → set up Digital Engagement WhatsApp channel
5. **Data Cloud** — upload `scripts/datacloud/telematics-events.csv` as a Data Stream named `Vehicle_Telemetry_Events`. Map to DMO `Vehicle_Telemetry__dlm`.
6. **Named Credential** — Setup → Named Credentials → create `Slack_Webhook_Approver` with the real Slack webhook URL.
7. **Permission Set assignment** — Setup → Users → assign `Agentforce_Permissions` to the Agentforce service user.

### Step 4 — Seed demo data

```bash
sf apex run -f scripts/apex/seed_demo_telemetry.apex -o vscodeOrg
# Plus run DemoScenarioSeeder if you want fresh demo VINs/claims
```

### Step 5 — Verify

```bash
sf apex run -f scripts/apex/qa_full_suite.apex -o vscodeOrg
sf apex run -f scripts/apex/verify_prompt_templates.apex -o vscodeOrg
sf apex run -f scripts/apex/prove_datacloud_chain.apex -o vscodeOrg
```

All assertions should pass.

---

## 17. How to run tests + verify

### Production scripts in `scripts/apex/`

| Script | Purpose |
|---|---|
| `qa_full_suite.apex` | Integration smoke test — 13 assertions covering all decision actions, coverage engine, context builder, triggers, Prompt Templates |
| `verify_prompt_templates.apex` | Live-fires each of the 3 templates against a real claim and reports OK LIVE / EMPTY / ERROR per template |
| `prove_datacloud_chain.apex` | Proves the full Data Cloud → Apex → Platform Event → Trigger → Claim writeback chain works end-to-end |
| `seed_demo_telemetry.apex` | Pre-seeds Platform Events for demo VINs so Slack cards have non-null TelemetrySignal |
| `schedule_telemetry_refresh.apex` | Schedules `RefreshTelemetrySignals` to run hourly |

### Run them

```bash
sf apex run -f scripts/apex/<script>.apex -o vscodeOrg
```

### What to look for in output

- **qa_full_suite** — `PASSED: 13` and `=== ALL CRITICAL ASSERTIONS PASSED ===`
- **verify_prompt_templates** — `✅ OK LIVE` for all 3 templates
- **prove_datacloud_chain** — three layers pass (DLM rows accessible, events published, claims populated)

### Apex unit tests

To run all Apex unit tests:

```bash
sf apex run-test -o vscodeOrg
```

Currently ~17 test classes exist. Coverage hasn't been the priority for the hackathon; production rollout would push for ≥75% coverage.

---

## 18. How to demo

### Pre-flight (5 min before recording)

```bash
# 1. Seed claims + telemetry
sf apex run -f scripts/apex/seed_demo_telemetry.apex -o vscodeOrg

# 2. Verify everything still works
sf apex run -f scripts/apex/qa_full_suite.apex -o vscodeOrg
```

### Browser windows to set up

1. **Window 1** — ARIA preview / WhatsApp web
2. **Window 2** — Slack `#all-electra-cars-approvers`
3. **Window 3** — Salesforce Claim record (open one in advance for closing shot)
4. **Window 4** — Warranty Ops Command Center dashboard

### Demo flow (5 min)

Follow `VIDEO_SCRIPT.md` exactly. Key beats:

1. **Hook** (0:00-0:25) — problem statement
2. **Dealer intake on WhatsApp** (0:25-1:10) — submit a battery claim, ARIA fires automotive expertise
3. **Auto-routing** (1:10-1:40) — show the structured Claim record
4. **Slack approver flow** (1:40-3:10) — **partial approval** is the killer beat
   - Type: `approve at 1700 estimate too high for new battery`
   - Capture: rationale, threshold confirm, ✅ APPROVED
5. **Decision propagates** (3:10-3:50) — dealer + customer WhatsApp, PDF, Claim record
6. **Resilience** (3:50-4:20) — guardrails, fallbacks
7. **Impact + close** (4:20-4:45) — dashboard, "three approvers, doing the work of ten"

### Useful demo VINs

- `ELXDEMOFRD0800000` — fraud scenario (3 fault codes + off-network charge)
- `ELXDEMOHAPY010000` — happy path (clean)
- `ELXDEMOSRT1000000` — clean charging history
- `ELXDEMOBIG0300000` — moderate fault count

---

## 19. Outstanding tasks

### Critical (must do before submission)

| # | Task | Owner | Time |
|---|---|---|---|
| 1 | Update 3 Prompt Builder templates to use `{!$Input:ClaimContext}` instead of nested `{!$Input:Claim.X}` | Anyone with Prompt Builder access | 15 min |
| 2 | Apply approver agent updates via Builder UI (token extraction, polish, partial-approval) — text in `Warranty_Approver_Agent_3.agent` | Agentforce admin | 15 min |
| 3 | Apply ARIA agent polish via Builder UI — text in `Warranty_Dealer_Intake_Agentt_4.agent` | Agentforce admin | 10 min |
| 4 | Record 5-min demo video using `VIDEO_SCRIPT.md` | Video lead | 60-90 min |
| 5 | Build the metrics dashboard (4 reports + 1 dashboard) | Salesforce admin | 45 min |

### Important (Experience Cloud, stretches submission narrative)

| # | Task | Owner | Time |
|---|---|---|---|
| 6 | Configure Experience Cloud Automotive site for guest access | Experience Cloud admin | 15 min |
| 7 | Drop the 3 LWCs onto the home page | Experience Cloud admin | 15 min |
| 8 | Set up Messaging for Web channel + Embedded Service Deployment + paste snippet | Salesforce admin | 30 min |
| 9 | Brand the site (logo, colors, navigation) | Designer / front-end | 30 min |
| 10 | Test in incognito browser, capture screenshots | QA | 15 min |

### Nice-to-have (post-hackathon polish)

| # | Task | Owner | Time |
|---|---|---|---|
| 11 | Replace mocked vision analyzer with real LLM (ConnectApi multimodal call) | Apex dev | 2-3 hours |
| 12 | Add Service Appointment auto-booking after approval | Salesforce dev | 2 hours |
| 13 | Implement Product2 catalog validation (replace free-text PartCategory) | Salesforce dev | 3 hours |
| 14 | Cross-OEM fraud detection via Data Cloud federation | Data Cloud dev | 6-8 hours |
| 15 | Predictive maintenance proactive outreach | Apex + Data Cloud | 4-6 hours |
| 16 | Multilingual ARIA (Spanish, French, German) | Agentforce admin | 2 hours per language |
| 17 | Apex unit test coverage to 75%+ for prod rollout | QA / dev | 8-12 hours |

---

## 20. Known issues + workarounds

### 🔴 Issue 1 — Agent files cannot be CLI-deployed

**Symptom:** `sf project deploy start -d ... .agent` fails with `Unexpected '@subagent'` errors.

**Root cause:** Salesforce platform syntax migration in progress. The CLI validator now requires `@topic` syntax but the runtime in this org still uses `@subagent`.

**Workaround:** Apply changes via Agentforce Builder UI instead of file deploy. Source-of-truth is the local `.agent` file; copy-paste relevant sections into the Builder.

### 🟡 Issue 2 — `AuthorizationPdfUrl__c` field couldn't be created

**Symptom:** Adding a Url-typed field to Claim silently failed (Industries Cloud Claim quirk).

**Workaround:** Removed the field; PDF URL now lives in WhatsApp body, Chatter audit, and ContentVersion attached to Claim. New `PhotoPublicUrl__c` field uses LongTextArea(500) instead of Url and deploys cleanly.

### 🟡 Issue 3 — Prompt template Map<->Object resolution is unreliable

**Symptom:** Templates with `{!$Input:Claim.PartCategory__c}` style nested references render empty when the Apex passes a Map<String,Object>. LLM sees blank fields, returns truncated `{` JSON.

**Workaround:** Apex now pre-renders all field values into a single Text blob and passes as `Input:ClaimContext`. Template body uses `{!$Input:ClaimContext}` once. Reliable, deterministic.

### 🟡 Issue 4 — Agent occasionally hallucinates DealerWhatsAppNumber__c

**Symptom:** ARIA's `tool_Action_Create_Warranty_Claim` action defines `dealerWhatsAppNumber` as an unbound input; the LLM fills it with garbage like `"Vin"` or `"None"`.

**Workaround:** Server-side guard in `SendWhatsAppClaimDecision.findActiveSession()` — rejects values with fewer than 8 digits. Falls cleanly through to Tier 2 Chatter audit.

### 🟡 Issue 5 — Goodwill misroute (older claims may exhibit)

**Symptom:** Approver typing "approve" sometimes called `SubmitGoodwillReview` because the available-when gate was loose.

**Workaround:** Added `goodwill_intent_confirmed` boolean variable + gate. Goodwill action now requires explicit "goodwill" keyword. Status guards on Approve/Reject/Clarify also prevent regression of Approved/Rejected claims.

### 🟡 Issue 6 — Slack webhook URL redacted in repo

**Symptom:** `force-app/main/default/namedCredentials/Slack_Webhook_Approver.namedCredential-meta.xml` has a placeholder URL (`REPLACE_WITH_YOUR_WEBHOOK_PATH`).

**Workaround:** Don't deploy that file to a working org or you'll overwrite the live webhook. After fresh org deploys, manually paste the real webhook URL via Setup → Named Credentials → Slack_Webhook_Approver → Edit. SUBMISSION.md includes a note about this for judges.

### 🟡 Issue 7 — Stuck "Not Covered" claims in queue

**Symptom:** Some pre-existing demo claims show `Eligibility = Not Covered` AND `Status = Pending Approver Review` — they should have been auto-rejected.

**Root cause:** Legacy data created before auto-reject routing was deployed.

**Workaround:** Ignore for the demo, OR run an admin cleanup script that flips them to Rejected. Newly-created claims route correctly.

---

## 21. Quick reference

### File paths (most-touched)

| What | Where |
|---|---|
| All Apex classes | `force-app/main/default/classes/` |
| Triggers | `force-app/main/default/triggers/` |
| Flows | `force-app/main/default/flows/` |
| Custom fields | `force-app/main/default/objects/<Object>/fields/` |
| Platform Event | `force-app/main/default/objects/TelemetrySignal__e/` |
| Agents | `force-app/main/default/aiAuthoringBundles/` |
| LWCs | `force-app/main/default/lwc/` |
| Permission set | `force-app/main/default/permissionsets/Agentforce_Permissions.permissionset-meta.xml` |
| Admin profile patch | `force-app/main/default/profiles/Admin.profile-meta.xml` |
| Visualforce PDF | `force-app/main/default/pages/ApprovalAuthorizationPDF.page` |
| Apex scripts (verify, seed, schedule) | `scripts/apex/` |
| Telemetry CSV | `scripts/datacloud/telematics-events.csv` |

### Common commands

```bash
# Auth
sf org login web --alias vscodeOrg

# Deploy a single class
sf project deploy start -d "force-app/main/default/classes/<Class>.cls" -o vscodeOrg

# Deploy a single agent
sf project deploy start -d "force-app/main/default/aiAuthoringBundles/<bundle>" -o vscodeOrg

# Run a script
sf apex run -f scripts/apex/<script>.apex -o vscodeOrg

# Run all Apex tests
sf apex run-test -o vscodeOrg

# Pull metadata from org
sf project retrieve start -m "ApexClass:<Name>" -o vscodeOrg

# Query records
sf data query --query "SELECT Id, Name FROM Claim LIMIT 5" -o vscodeOrg
```

### Documentation files (in repo)

| File | Purpose |
|---|---|
| `README.md` | Public-facing project overview (judges land here from GitHub) |
| `SUBMISSION.md` | Hackathon submission package — paste sections into the form |
| `CHANGELOG.md` | What shipped in v1.0.0 |
| `LICENSE` | MIT |
| `PITCH_DECK.md` | Speaker-notes deck with delivery checklist + Q&A prep |
| `SLIDES.md` | Paste-ready slide content for Pitch.com / Google Slides |
| `VIDEO_SCRIPT.md` | 5-min timestamped video script |
| `ARCHITECTURE_DIAGRAMS.md` | 3 Mermaid diagrams (system, sequence, guardrails) |
| `HANDOVER.md` | This file |

### Demo VINs

| VIN | Story | Account / Trust |
|---|---|---|
| `ELXDEMOFRD0800000` | Fraud scenario — 3 fault codes + off-network charge | (varies) |
| `ELXDEMOHAPY010000` | Happy path — clean | Trust 78-85 |
| `ELXDEMOSRT1000000` | Clean charging history | (varies) |
| `ELXDEMOBIG0300000` | 2 faults — moderate concern | (varies) |
| `ELXDEMOREJ0500000` | Out-of-warranty (rejection demo) | (varies) |
| `ELXDEMOGDWL060000` | Goodwill exception scenario | (varies) |

### Critical config in the org

| Item | Where | Value |
|---|---|---|
| Slack webhook | Setup → Named Credentials → `Slack_Webhook_Approver` | (live URL — set manually post-deploy) |
| Slack channel | (in app) | `#all-electra-cars-approvers` |
| Agent service user | Setup → Users | `warranty_dealer_intake_agentt@...ext` (assigned `Agentforce_Permissions`) |
| Default org | `.sf/config.json` | target-org: `vscodeOrg` |
| WhatsApp channel | Setup → Messaging Settings | Digital Engagement WhatsApp |

---

## 22. Glossary

| Term | Meaning |
|---|---|
| **ARIA** | Authorized Repair Intelligence Assistant — the dealer-facing agent (Warranty_Dealer_Intake_Agentt_4) |
| **Approver Agent** | Warranty_Approver_Agent_3 — the Slack-facing employee agent for OEM adjusters |
| **Auto-route** | Logic in `RouteClaimToApproverQueue` that decides if a new claim should be auto-approved, auto-rejected, or queued |
| **Coverage Engine** | `CoverageEngine.cls` — queries AssetWarranty to determine Likely / Borderline / Not Covered |
| **Decision Path** | The route a claim takes after submission. Tracked via the `DecisionPath__c` formula field |
| **DLM** | Data Lake Model — Data Cloud's term for ingested data tables |
| **DMO** | Data Model Object — Data Cloud's term for harmonized data entities |
| **Goodwill exception** | A claim approved as a one-off policy override despite not meeting standard coverage criteria |
| **Golden Rule** | Agent reasoning pattern — tool call + user-facing confirmation must happen in the same turn |
| **Partial approval** | Approver approves the claim at a dollar amount lower than the dealer's estimate. Stored on `Claim.ApprovedAmount` |
| **Platform Event** | `TelemetrySignal__e` — a publish-subscribe event fired by `RefreshTelemetrySignals` when telemetry changes |
| **Prior Authorization** | OEM-level pre-approval the dealer needs before commencing a warranty repair |
| **PromptTemplate (live)** | A Prompt Builder template that fires the LLM via `ConnectApi.EinsteinLLM`. Output captured back to the Claim or used in messaging |
| **RFI** | Request For Information — when the approver asks the dealer to clarify before deciding |
| **RouteClaimToApproverQueue** | The class that holds auto-routing logic |
| **SLA** | Service Level Agreement — 24-hour deadline for approver to review a queued claim |
| **SOQL** | Salesforce Object Query Language — Salesforce's SQL-equivalent |
| **SRT** | Standard Repair Time — the OEM's published baseline cost for a part. Stored in `SRTMatrix__c` |
| **Status guard** | Apex-level check that prevents already-decided claims from being regressed |
| **Three-tier delivery** | `SendWhatsAppClaimDecision` pattern: Tier 1 push → Tier 2 Chatter audit → guaranteed |
| **Token extraction rule** | Agent reasoning instruction that scans every message for `WC-[A-Z0-9]+` and extracts it as the claim number |
| **TSB** | Technical Service Bulletin — OEM-issued repair advisory (e.g., TSB-2401 for 2023 X5 drive motor) |
| **WrappedValue** | Salesforce ConnectApi type used to pass typed values to a Prompt Builder template |

---

## Closing notes

This project went from "blank Salesforce org" to "production-grade hackathon submission" in one focused build. The architecture is **opinionated and consistent** — agent → Apex action → service helper → Automotive Cloud record → audit trail. Every layer has a fallback. Every decision is auditable.

If you're picking this up cold, **read sections 3 (architecture) and 4 (data flow) carefully**. The rest is reference material you can grep when you need it.

If something feels broken, check [§20 Known issues + workarounds](#20-known-issues--workarounds) first — most things have a documented workaround.

When you ship a real change to the org:
1. Edit locally
2. `sf project deploy start -d <path>` to push
3. Run `qa_full_suite.apex` to verify nothing regressed
4. Commit + push to GitHub
5. Update CHANGELOG.md

Good luck. Build something they remember.

— *Original team, April 2026*
