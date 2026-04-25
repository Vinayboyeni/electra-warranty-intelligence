# Electra Cars Warranty Claim Agent — Technical Specification

**Hackathon Submission | Platform: Salesforce Automotive Cloud + Agentforce**

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEALER (WhatsApp)                            │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                    WhatsApp Messaging API (Digital Engagement)
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                ARIA — Warranty_Dealer_Intake_Agentt_4                │
│          (AgentforceServiceAgent, Einstein classifier router)        │
│  Subagents: WarrantyIntake, ClaimStatusInquiry, WarrantyPolicyFAQ,   │
│             GoodwillReview, ApproverFollowUp, Escalation, off_topic  │
└─────────────────────────────────────────────────────────────────────┘
                                   │
            Actions (flow:// and apex://) → Apex classes & Flows
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                     AUTOMOTIVE CLOUD (Data Layer)                    │
│  Claim, Vehicle, Asset, AssetWarranty, Account, Contact,             │
│  MessagingSession, MessagingEndUser, FeedItem                        │
└─────────────────────────────────────────────────────────────────────┘
                                   │
              Record-triggered Flow → FeedItem → Slack bridge
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                      OEM APPROVER (Slack)                            │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                      Slack for Salesforce app
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│              Warranty_Approver_Agent_3                               │
│        (AgentforceEmployeeAgent, Einstein classifier)                │
│   Subagents: ClaimReview, QueueOverview, PolicyFAQ, Escalation,      │
│              off_topic, ambiguous_question                           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Platform Stack

| Layer | Technology |
|---|---|
| Data Platform | Salesforce Automotive Cloud |
| AI Agents | Agentforce (Service Agent + Employee Agent) |
| AI Model Router | `model://sfdc_ai__DefaultEinsteinHyperClassifier` |
| Automation | Salesforce Flows (Record-Triggered + Auto-Launched) |
| Business Logic | Apex (43 classes) |
| Dealer Channel | WhatsApp via Digital Engagement / Messaging API |
| Approver Channel | Slack via Slack for Salesforce integration |
| Analytics | Data Cloud Calculated Insight (`DealerClaimVelocity__dlm`) |
| Notifications | Chatter FeedItem → Slack mirror (no custom Slack API code) |

---

## 3. Data Model

### 3.1 Core Objects

#### Claim (Automotive Cloud standard object + custom fields)
Primary record for each warranty request. ~97 fields including:

| Field | Type | Purpose |
|---|---|---|
| `Name` | Auto / Text | Human-readable claim number (`WC-XXXXX`) |
| `AccountId` | Lookup | Dealer Account |
| `Vehicle__c` | Lookup | Asset representing the vehicle |
| `Status` | Picklist | Submitted, Pending Approver Review, Approved, Rejected, Needs More Info |
| `Odometer__c` | Number | Miles at time of fault |
| `PartCategory__c` | Text | Battery, Engine, etc. |
| `Symptom__c` | LongText | Dealer description |
| `Diagnosis__c` | Text | Decoded DTC description |
| `EstimatedCost__c` | Currency | Dealer's quote |
| `Eligibility__c` | Picklist | Likely / Borderline / Not Covered |
| `EligibilityRationale__c` | LongText | Why the verdict |
| `AI_Recommendation__c` | Picklist | Approve / Reject / Needs Clarification |
| `AI_Confidence__c` | Number(0–100) | Confidence score |
| `AI_Summary__c` | LongText | One-line AI summary |
| `AI_Image_Analysis__c` | LongText | Vision AI damage assessment |
| `SLA_Due_Date__c` | DateTime | 24 business hours from submission |
| `SubmissionChannel__c` | Picklist | WhatsApp / Web / SMS |
| `DealerWhatsAppNumber__c` | Phone | For RFI round-trips |
| `ClarificationRequest__c` | LongText | Approver's question |
| `DealerResponseSummary__c` | LongText | Dealer's reply + SRT justification |
| `ApproverQueue__c` | Text | Queue name for routing |
| `ApproverSlackRef__c` | Text | Slack thread reference for audit |
| `ApprovalDate__c` | DateTime | When approved |
| `DecisionRationale__c` | LongText | Adjuster's reason (audit trail) |
| `Auto_Approved__c` | Checkbox | True if bypass-routed |
| `Priority__c` | Picklist | Low / Medium / High (High for safety keywords) |
| `Repair_Order_Number__c` | Text | Dealer's internal RO# |
| `RequiresFollowUp__c` | Checkbox | True during Needs More Info |

**Record Types:** `Prior_Authorization`, `Post_Repair_Claim`, `Goodwill_Exception`

**List Views:** `All_Claims`, `Warranty_Claim_Approvers_Claim`, `Warranty_Claim_Critical_Claim`

#### Vehicle (Automotive Cloud standard)
Linked to `Asset` (which holds AccountId and ContactId for dealer + owner).

#### AssetWarranty (Automotive Cloud standard + custom)
| Custom Field | Purpose |
|---|---|
| `CoveredCategories__c` | Comma-separated part categories |
| `MileageCap__c` | Max odometer under this warranty |
| `LaborPolicy__c` | Labor coverage terms |
| `Vehicle__c` | Link to Vehicle |

#### Account (with Dealer custom fields)
| Custom Field | Purpose |
|---|---|
| `DealerTrustScore__c` | 0–100 reliability score |

#### SRTMatrix__c (to be created manually)
| Field | Type | Purpose |
|---|---|---|
| `Part_Category__c` | Text | Lookup key |
| `Baseline_Amount__c` | Currency | SRT standard cost |
| `IsActive__c` | Checkbox | Filter for active baselines |

### 3.2 Messaging Objects (Digital Engagement)
- `MessagingSession` — live WhatsApp conversation
- `MessagingEndUser` — dealer's WhatsApp identity (keyed by phone)
- `ContentVersion` — uploaded photos

### 3.3 Data Cloud DMOs (Calculated Insight target)
| DMO | Status |
|---|---|
| `Claim__dlm` | Needs manual mapping post-deploy |
| `DealerClaimVelocity__dlm` | Calculated Insight defined |

---

## 4. Agent Architecture

### 4.1 ARIA — Warranty_Dealer_Intake_Agentt_4

**Type:** `AgentforceServiceAgent` (external-facing, runs as dedicated user)

**Router:** `agent_router` with Einstein classifier

**Subagents:**
| Subagent | Purpose |
|---|---|
| WarrantyIntake | Main claim creation flow (11 steps) |
| ClaimStatusInquiry | "Where is my claim?" lookup |
| WarrantyPolicyFAQ | General coverage Q&A (no VIN) |
| GoodwillReview | Exception request handler |
| ApproverFollowUp | Dealer response to RFI |
| Escalation | Human handoff |
| off_topic | Redirect non-warranty messages |
| ambiguous_question | Ask for clarifying details |

**Variables (Mutable):** `vin`, `vehicle_id`, `vehicle_model`, `vehicle_year`, `customer_id`, `dealer_id`, `odometer`, `part_category`, `symptom`, `requested_amount`, `fault_date`, `repair_order_number`, `diagnostic_code_description`, `srt_justification`, `coverage_eligibility`, `coverage_rationale`, `claim_id`, `claim_number`, `claim_status`, `image_url`, `damage_analysis`, `slack_notified`, `srt_baseline_amount`, `srt_is_within_range`, `duplicate_claim_found`, `duplicate_claim_number`, `user_confirmed`

**Variables (Linked — Session Context):**
| Variable | Source |
|---|---|
| `EndUserId` | `@MessagingSession.MessagingEndUserId` |
| `RoutableId` | `@MessagingSession.Id` |
| `ContactId` | `@MessagingEndUser.ContactId` |

**Key Design Patterns:**
- `set_variable_*` helpers for deterministic field persistence
- `available when` gates on every Apex/Flow action (e.g., `CreateWarrantyClaim` requires `user_confirmed == True`)
- `tool_` prefix on action invocations for clarity
- Safety rule halts workflow on fire/smoke/brake/steering keywords

### 4.2 Warranty_Approver_Agent_3

**Type:** `AgentforceEmployeeAgent` (internal, Slack-native)

**Router:** `agent_router` with Einstein classifier + sticky-session rule (stays in ClaimReview once context loaded)

**Subagents:**
| Subagent | Purpose |
|---|---|
| ClaimReview | Load context + approve/reject/clarify/goodwill |
| QueueOverview | Lookup claims by number/VIN |
| PolicyFAQ | Coverage rule Q&A |
| Escalation | Warranty Policy team handoff |
| off_topic / ambiguous_question | Input validation |

**Deterministic Guardrails:**
| Gate | Mechanism |
|---|---|
| `$2,000 threshold` | `confirmed_above_threshold: boolean` — reasoning sets True automatically for small claims, requires explicit adjuster "yes" for large |
| `Already-decided guard` | `available when claim_status != "Approved" and claim_status != "Rejected"` |
| `Context-first guard` | All action calls require `context_loaded == True` |
| `Rationale required` | `available when decision_rationale is not None` for approve/reject/goodwill |
| `Not Covered override` | Reasoning routes to GoodwillReview instead of direct approval |
| `Fraud safety rule` | System instructions halt auto-approval if risk_flags contains fraud/duplicate/velocity |

---

## 5. Apex Components

43 Apex classes organized by role:

### 5.1 Intake Actions (called by ARIA)
| Class | Purpose |
|---|---|
| `FindVehicleByVin.cls` | VIN lookup → Vehicle, Dealer, Customer IDs |
| `CheckRecentClaims.cls` | Duplicate detection (same VIN + part in last 30 days) |
| `CoverageEngine.cls` | Evaluates Likely / Borderline / Not Covered |
| `DecodeDiagnosticCode.cls` | Translates DTCs (e.g., P0A80) |
| `ValidateRepairEstimate.cls` | SRT matrix comparison, ±20% threshold |
| `CreateWarrantyClaim.cls` | Orchestrates claim + ClaimItem + FeedItem insert, generates `WC-XXXXX` name |
| `GetWhatsAppMediaUrl.cls` | Fetches latest dealer photo URL |
| `ImageDamageAnalyzer.cls` | Invokes vision AI on damage photo |
| `GetClaimStatus.cls` | Status lookup (by number or VIN, with WC-XXXXX fallback) |

### 5.2 Approver Actions (called by Warranty_Approver_Agent_3)
| Class | Purpose |
|---|---|
| `GetWarrantyClaimApprovalContext.cls` | Returns full claim context + formatted Slack markdown |
| `ApproveWarrantyClaim.cls` | Sets Status=Approved, stamps rationale, notifies dealer |
| `RejectWarrantyClaim.cls` | Sets Status=Rejected with reason code |
| `RequestDealerClarification.cls` | Sets Status=Needs More Info, stores question |
| `SubmitGoodwillReview.cls` | Creates/flags Goodwill Exception record |
| `SubmitDealerClarificationResponse.cls` | Dealer reply handler — resumes claim |

### 5.3 Routing & Notifications
| Class | Purpose |
|---|---|
| `RouteClaimToApproverQueue.cls` | Auto-approve/reject logic + queue assignment |
| `SendWhatsAppRFINotification.cls` | Posts approver question into existing WhatsApp session |
| `LinkUploadedEvidenceToClaim.cls` | Attaches photos to the Claim |
| `SendWarrantyExpiryAlert.cls` | Proactive alert before warranty expires |

### 5.4 Support & Utilities
| Class | Purpose |
|---|---|
| `TestDataFactory.cls` | Test data builder |
| `HackathonDataPrep.cls` | Seeds demo data |
| `ElectraHackathonDataSeeder.cls` | Bulk demo data for judges |
| `CreateWarrantyClaimInput.cls` / `CreateWarrantyClaimResult.cls` | Invocable DTOs |
| `FindVehicleByVinInput.cls` / `FindVehicleByVinResult.cls` | Invocable DTOs |
| `CoverageEvaluateInput.cls` / `CoverageEvaluateResult.cls` | Invocable DTOs |
| `*Test.cls` | Unit tests for each class |

---

## 6. Flow Components

21 warranty-specific flows (ignoring the SDO demo flows):

### 6.1 Autolaunched Flows (invoked from agents)
- `Action_Find_Vehicle_By_VIN`
- `Action_Check_Recent_Claims`
- `Action_Coverage_Engine` (shared subflow)
- `Action_Decode_Diagnostic_Code`
- `Action_Validate_Repair_Estimate`
- **`Action_Create_Warranty_Claim`** — main orchestrator (creates Claim, renames to WC-XXXXX, routes, notifies)
- `Action_Get_WhatsApp_Media_URL`
- `Action_Image_Damage_Analyzer`
- `Action_Get_Claim_Status`
- `Action_Approve_Claim`
- `Action_Reject_Claim`
- `Action_Request_Clarification`
- `Action_Submit_Dealer_Response`
- `Action_Submit_Goodwill_Review`
- `Action_Get_Approval_Context`
- `Action_Link_Uploaded_Evidence`
- `Action_Route_Claim_to_Queue`

### 6.2 Record-Triggered Flows
| Flow | Trigger |
|---|---|
| `Slack_Notify_Approver_Flow` | Claim.Status = "Pending Approver Review" → posts Chatter FeedItem (bridges to Slack) |
| `Send_WhatsApp_Clarification_Flow` | Claim.Status = "Needs More Info" → sends RFI to dealer |
| `Warranty_Expiry_Alert_Flow` | Scheduled — notifies dealer of upcoming expiry |
| `Claim_Queue_Routing_Flow` | Secondary routing rules |
| `Dealer_Clarification_Response_Flow` | Captures dealer's RFI reply |
| `Approver_Clarification_Flow` | Notifies approver of dealer reply |

---

## 7. Integrations

### 7.1 WhatsApp (Digital Engagement)
- Inbound: `MessagingSession` created on first dealer message, routed to ARIA agent
- Outbound (synchronous during chat): Agent responds in same session
- Outbound (asynchronous RFI): `SendWhatsAppRFINotification.cls` looks up active `MessagingSession` by phone, posts into the same conversation
- Fallback: If session inactive, message queued as FeedItem on Claim, delivered on dealer's next ARIA interaction

### 7.2 Slack
- No custom Slack API code — uses **Slack for Salesforce** connected app
- Admin configures a Slack channel to subscribe to `Warranty Claim Approvers` queue FeedItems
- `Slack_Notify_Approver_Flow` posts a Chatter FeedItem with markdown-formatted `slackMessageBody` → auto-mirrored to Slack
- Warranty_Approver_Agent_3 runs as a Slack-connected Agentforce Employee Agent
- `ApproverSlackRef__c` field stores thread reference for audit

### 7.3 Data Cloud
- `DealerClaimVelocity.calculatedInsight-meta.xml` — computes per-dealer claim rate over rolling 30-day window
- Needs post-deploy manual setup: Data Stream from `Claim` object → `Claim__dlm` DMO
- Used by Approver Agent's risk flag logic (via `GetWarrantyClaimApprovalContext`)

---

## 8. Key End-to-End Workflows

### 8.1 Happy Path — Claim Submission
```
WhatsApp "yes" → ARIA
  ↓ tool_Action_Create_Warranty_Claim (flow)
Flow: Get_Vehicle → Subflow_Evaluate_Coverage → Create_Claim_Rec
  → Get_Created_Claim → Update_Claim_Name (renames to WC-XXXXX)
  → Create_Chatter_Post → Create_Claim_Item → Subflow_Route_Claim
  → Set_Summary_Results (returns claimNumber = "WC-XXXXX")
  ↓
RouteClaimToApproverQueue.cls decides:
  - AUTO-APPROVE (if Likely + ≤$500 + conf≥90 + trust≥75)
  - AUTO-REJECT (if Not Covered)
  - QUEUE (otherwise) → sets Status = "Pending Approver Review"
  ↓ Record trigger fires
Slack_Notify_Approver_Flow
  ↓ GetWarrantyClaimApprovalContext.cls
  ↓ FeedItem on Claim with slackMessageBody
  ↓ Slack for Salesforce mirrors to channel
Approver sees claim card in Slack
```

### 8.2 Approval Decision
```
Slack "approve WC-XXXXX" → Warranty_Approver_Agent_3
  ↓ set_variable_claim_number
  ↓ tool_GetWarrantyClaimApprovalContext (available when claim_number is set)
  ↓ set_variable_decision_rationale (adjuster provides reason)
  ↓ set_variable_confirmed_above_threshold (auto for ≤$2000, explicit for >$2000)
  ↓ tool_ApproveWarrantyClaim (available when all gates pass)
ApproveWarrantyClaim.cls → Claim.Status = "Approved"
  ↓ Triggers dealer WhatsApp notification via existing session
```

### 8.3 RFI Round-Trip (Slack ↔ WhatsApp)
```
Approver: "clarify WC-XXXXX — need RO photo"
  ↓ RequestDealerClarification.cls
  ↓ Claim.Status = "Needs More Info"
  ↓ ClarificationRequest__c stored
  ↓ Record trigger fires
Send_WhatsApp_Clarification_Flow
  ↓ SendWhatsAppRFINotification.cls
  ↓ Looks up MessagingEndUser by DealerWhatsAppNumber__c
  ↓ Finds active MessagingSession
  ↓ Posts question into same WhatsApp thread
Dealer replies in WhatsApp
  ↓ ARIA agent_router → ApproverFollowUp subagent
  ↓ SubmitDealerClarificationResponse.cls
  ↓ DealerResponseSummary__c stored
  ↓ Claim.Status = "Pending Approver Review"
Approver sees reply in original Slack thread
```

---

## 9. Deployment

### 9.1 Prerequisites (Manual Setup in Org)
1. Create `SRTMatrix__c` custom object with `Part_Category__c`, `Baseline_Amount__c`, `IsActive__c` fields
2. Populate SRT baseline records (Battery → $4500, Engine → $5500, etc.)
3. Install Slack for Salesforce; map a Slack channel to the `Warranty Claim Approvers` queue
4. Configure WhatsApp Messaging Channel in Digital Engagement
5. Authorize the Agentforce service user account (`warranty_dealer_intake_agentt@...ext`)
6. Set up Data Cloud Data Stream from `Claim` object → `Claim__dlm` DMO (optional)

### 9.2 Deploy Order (Critical)
```bash
# Layer 1 — Objects & Fields (deploy first, everything depends on these)
sf project deploy start \
  --source-dir force-app/main/default/objects \
  --target-org electra-dev

# Layer 2 — Apex Classes (must precede agents due to metadata registration)
sf project deploy start \
  --source-dir force-app/main/default/classes \
  --target-org electra-dev

# Layer 3 — Flows
sf project deploy start \
  --source-dir force-app/main/default/flows \
  --target-org electra-dev

# Layer 4 — Permission Sets, Tabs, Calculated Insights
sf project deploy start \
  --source-dir force-app/main/default/permissionsets \
  --source-dir force-app/main/default/tabs \
  --source-dir force-app/main/default/calculatedInsights \
  --target-org electra-dev

# Layer 5 — Agent Bundles (MUST be last; Agentforce validates against deployed Apex metadata)
sf project deploy start \
  --source-dir force-app/main/default/aiAuthoringBundles/Warranty_Dealer_Intake_Agentt_4 \
  --source-dir force-app/main/default/aiAuthoringBundles/Warranty_Approver_Agent_3 \
  --target-org electra-dev
```

### 9.3 Agent Bundles — Active Versions
Only deploy these; other bundles in the folder are legacy iterations with known issues:
- `Warranty_Dealer_Intake_Agentt_4` (ARIA — current)
- `Warranty_Approver_Agent_3` (current)

Legacy (do NOT deploy): `Warranty_Dealer_Intake_Agent`, `Warranty_Dealer_Intake_Agentt_1/2/3`, `Warranty_Approver_Agent`, `Warranty_Approver_Agent_1`, `Warranty_Approver_Agent_2`, `ARIA`, `Test_Agent`.

---

## 10. Security & Permissions

### 10.1 Permission Sets
| Name | Purpose |
|---|---|
| `Agentforce_Permissions` | Grants agent runtime user access to required objects + 17 invocable actions |
| `Warranty_Claims_User` | Grants dealer/approver user profiles read/write on Claim, Vehicle, AssetWarranty |

### 10.2 Sharing & Record Access
- Claim records owned by the `Warranty Claim Approvers` queue
- Dealers see only their own claims (criteria-based sharing by `AccountId`)
- Warranty Policy Managers see Goodwill Exception record types org-wide

### 10.3 Data Handling
- `DealerWhatsAppNumber__c` stored on Claim for RFI round-trips
- No PCI/PII beyond what's required for claim adjudication
- WhatsApp media stored via Salesforce `ContentVersion` with standard org-level retention

---

## 11. Testing Strategy

### 11.1 Apex Unit Tests (included)
- `CreateWarrantyClaimTest.cls` — happy path claim creation
- `CoverageEngineTest.cls` — Likely / Borderline / Not Covered verdicts
- `FindVehicleByVinTest.cls` — VIN lookup
- `ApproveWarrantyClaimTest.cls`, `RejectWarrantyClaimTest.cls`
- `ImageDamageAnalyzerTest.cls`
- `RequestDealerClarificationTest.cls`, `SubmitDealerClarificationResponseTest.cls`
- `WarrantyAgentActionsTest.cls` — integration
- `WarrantyClaimSlackFlowTest.cls` — notification flow
- `RouteClaimToApproverQueueTest.cls`
- `GetWarrantyClaimApprovalContextTest.cls`
- `SendWarrantyExpiryAlertTest.cls`
- `LinkUploadedEvidenceToClaimTest.cls`
- `SendWhatsAppRFINotificationTest.cls`
- `SubmitGoodwillReviewTest.cls`

Target: 75%+ code coverage per Salesforce deployment requirement.

### 11.2 Demo Test Scenarios
| Scenario | Expected Outcome |
|---|---|
| Low-cost Battery claim, Likely | Auto-approved (no Slack) |
| $4,000 Engine claim, Likely | Slack notification, $2k gate triggers |
| Odometer 60,000 on standard warranty | Not Covered → Goodwill path offered |
| Duplicate submission within 30 days | Warning displayed; no new claim |
| Dealer says "fire from battery" | Safety Hotline message, workflow halted |
| Repair estimate 30% above SRT | Justification prompt shown |

---

## 12. Known Limitations & Quirks

| Item | Explanation | Workaround |
|---|---|---|
| Agentforce output types require `object + complex_data_type_name` for non-primitive types | Direct `number` fails at runtime | Use pattern `"field": object` + `complex_data_type_name: "lightning__numberType"`, except for numeric fields from Decimal returns which use plain `number` |
| SRT validation falls back to hardcoded map if `SRTMatrix__c` not deployed | Dynamic SOQL wraps the query in try/catch | Create the object post-deploy; no code change needed |
| Old claims (created before `Update_Claim_Name` flow step) have `Name = "Warranty Claim: VIN"` | WC-XXXXX only applies to new claims | `GetClaimStatus.cls` has fallback logic that searches by last 5 chars of Id |
| Dealer trust score requires manual population on Account | No auto-compute yet | Add via Data Cloud insight in Phase 2 |
| No native retry if Slack notification fails | Chatter FeedItem always writes; Slack mirror is eventually consistent | Manual re-notify via Flow debug |
| Agent bundles must deploy AFTER Apex changes | Agentforce caches invocable action metadata | Always deploy Apex first, then bundles |

---

## 13. Monitoring & Observability

- All claim status transitions logged as Chatter FeedItems on Claim
- Flow faults captured via Salesforce Setup → Flow Error Emails
- Apex errors logged via `System.debug` + Developer Console
- Agentforce conversations viewable in Agentforce Analytics
- Slack notifications have built-in delivery receipts via Slack app
- SLA breaches visible via `Warranty_Claim_Critical_Claim` list view

---

## 14. Project Structure

```
Warrenty Claim agent/
├── force-app/main/default/
│   ├── aiAuthoringBundles/
│   │   ├── Warranty_Dealer_Intake_Agentt_4/   ← ARIA (active)
│   │   ├── Warranty_Approver_Agent_3/         ← Approver (active)
│   │   └── [legacy versions — do not deploy]
│   ├── classes/                                ← 43 Apex classes + tests
│   ├── flows/                                  ← 21 warranty flows + SDO demo flows
│   ├── objects/
│   │   ├── Claim/                              ← 97 custom fields, 3 record types
│   │   ├── Vehicle/ (standard)
│   │   ├── AssetWarranty/
│   │   └── Account/ (DealerTrustScore__c)
│   ├── permissionsets/
│   ├── tabs/
│   └── calculatedInsights/
│       └── DealerClaimVelocity.calculatedInsight-meta.xml
├── manifest/
│   └── package.xml
├── FUNCTIONAL_SPECIFICATION.md                 ← business/user docs
├── TECHNICAL_SPECIFICATION.md                  ← this file
├── DATA_MODEL_MAPPING.md
├── HACKATHON_ARCHITECTURE_SUMMARY.md
└── README.md
```

---

## Appendix A — Complete Action Catalog

| Action | Type | Called By | Purpose |
|---|---|---|---|
| FindVehicleByVin | Apex | ARIA | VIN → Vehicle, Dealer, Customer |
| CheckRecentClaims | Apex | ARIA | Duplicate prevention |
| EvaluateCoverage | Apex → CoverageEngine | ARIA | Likely / Borderline / Not Covered |
| DecodeDiagnosticCode | Apex | ARIA | Translate DTCs |
| ValidateRepairEstimate | Apex | ARIA | SRT matrix ±20% check |
| Action_Create_Warranty_Claim | Flow | ARIA | Full claim creation orchestration |
| GetWhatsAppMediaURL | Apex | ARIA | Fetch uploaded photo |
| AnalyzeImageDamage | Apex | ARIA | Vision AI on damage photo |
| GetClaimStatus | Apex | ARIA + Approver | Status lookup |
| SubmitGoodwillReview | Apex | ARIA + Approver | Flag as goodwill exception |
| SubmitClarificationResponse | Apex | ARIA | Dealer's reply to RFI |
| GetWarrantyClaimApprovalContext | Apex | Approver | Full context + Slack card markdown |
| ApproveWarrantyClaim | Apex | Approver | Finalize approval |
| RejectWarrantyClaim | Apex | Approver | Finalize rejection |
| RequestDealerClarification | Apex | Approver | Trigger RFI to dealer |
| SendWhatsAppRFINotification | Apex | RFI Flow | Post into WhatsApp session |
| RouteClaimToApproverQueue | Apex | Claim Flow | Auto-approve/reject/queue |

---

## Appendix B — Key File References

| File | Role |
|---|---|
| [CreateWarrantyClaim.cls](force-app/main/default/classes/CreateWarrantyClaim.cls) | Claim creation orchestrator |
| [CoverageEngine.cls](force-app/main/default/classes/CoverageEngine.cls) | Coverage evaluation logic |
| [RouteClaimToApproverQueue.cls](force-app/main/default/classes/RouteClaimToApproverQueue.cls) | Auto-approve/reject rules |
| [GetWarrantyClaimApprovalContext.cls](force-app/main/default/classes/GetWarrantyClaimApprovalContext.cls) | Slack card builder |
| [SendWhatsAppRFINotification.cls](force-app/main/default/classes/SendWhatsAppRFINotification.cls) | RFI round-trip to WhatsApp |
| [Action_Create_Warranty_Claim.flow-meta.xml](force-app/main/default/flows/Action_Create_Warranty_Claim.flow-meta.xml) | Main claim creation flow |
| [Slack_Notify_Approver_Flow.flow-meta.xml](force-app/main/default/flows/Slack_Notify_Approver_Flow.flow-meta.xml) | Approver notification |
| [Warranty_Dealer_Intake_Agentt_4.agent](force-app/main/default/aiAuthoringBundles/Warranty_Dealer_Intake_Agentt_4/Warranty_Dealer_Intake_Agentt_4.agent) | ARIA agent definition |
| [Warranty_Approver_Agent_3.agent](force-app/main/default/aiAuthoringBundles/Warranty_Approver_Agent_3/Warranty_Approver_Agent_3.agent) | Approver agent definition |
| [Claim.object-meta.xml](force-app/main/default/objects/Claim/Claim.object-meta.xml) | Core Claim object |
