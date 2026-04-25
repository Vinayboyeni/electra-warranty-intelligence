<div align="center">

# ⚡ Electra Warranty Intelligence

### AI-driven warranty prior-authorization for EV OEMs

*Replacing the 1,000-claims-a-day email bottleneck with a Slack-native, WhatsApp-conversational, Data-Cloud-enriched approval system — built on Salesforce Automotive Cloud + Agentforce + Data Cloud.*

[![Salesforce](https://img.shields.io/badge/Salesforce-Automotive%20Cloud-00A1E0?logo=salesforce&logoColor=white)](https://www.salesforce.com/products/automotive-cloud/)
[![Agentforce](https://img.shields.io/badge/Agentforce-Service%20%2B%20Employee-0070D2)](https://www.salesforce.com/agentforce/)
[![Data Cloud](https://img.shields.io/badge/Data%20Cloud-Enabled-1798C1)](https://www.salesforce.com/data/)
[![Apex API](https://img.shields.io/badge/Apex-API%20v60-2496ED)](#)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Hackathon-Submitted-brightgreen)](#)

</div>

---

## 📑 Table of Contents

- [The Problem](#-the-problem)
- [The Solution](#-the-solution)
- [Architecture](#-architecture)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Repository Layout](#-repository-layout)
- [Setup for Reviewers](#-setup-for-reviewers)
- [Demo Flow](#-demo-flow)
- [Bugs Found & Fixed (QA log)](#-bugs-found--fixed-qa-log)
- [Roadmap](#-roadmap)
- [License](#-license)

---

## 🎯 The Problem

Electra Cars is an EV OEM with **300,000+ vehicles in service**. Their dealer network submits **1,000+ warranty prior-authorization requests per day** via email, manually triaged by just **3 OEM approvers**. Average decision time: **24–72 hours**. Approvers spend most of their time on data entry instead of judgment.

## ✨ The Solution

| | Before | After |
| :--- | :--- | :--- |
| **Intake channel** | Email + PDF forms | WhatsApp / Web Chat (ARIA conversational agent) |
| **Triage** | 1 claim at a time, manual | Auto-classified at submission via Coverage Engine + Prompt Builder verdict |
| **Approval** | Inbox triage | Slack-native, rich context card |
| **Auto-decision rate** | 0% | ~40% of claims (auto-approve / auto-reject) |
| **Decision time (auto path)** | 24–72 hours | < 30 seconds |
| **Approver capacity** | ~333 claims/day each | ~3× with auto-routing handling 40% of volume |

## 🏗 Architecture

```
DEALER ─WhatsApp─▶ ARIA ─▶ Claim record ─▶ Coverage Engine + AI Verdict (Prompt Builder)
                                                       │
                                               Auto-route layer
                                               ┌────────┼────────┐
                                               ▼        ▼        ▼
                                         Auto-approve  Queue   Auto-reject
                                               │        │        │
                                               ▼        ▼        ▼
                                        (PDF + WhatsApp) Slack   (Empathetic
                                                        Card     rejection)
                                                        │
                                                        ▼
                                              Approver Agent (Slack)
                                                        │
                                                        ▼
                                              approve / reject / clarify / goodwill
                                                        │
                                                        ▼
                                       PDF certificate · Dealer WhatsApp · Repair guidance
                                       Customer notification · Dealer Trust Score recalc
```

Full sequence and component diagrams in [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md).

## 🚀 Key Features

### Dealer-side intake (ARIA — Agentforce Service Agent)
- 📱 Conversational WhatsApp + Web Chat
- 🌐 **Bilingual** auto-detection (English + Spanish)
- 🔍 Slot-filling for VIN, symptom, part, odometer, cost
- 📷 Photo upload + Vision AI damage analysis
- 🔁 Inline RFI handling (clarification requests flow back to ARIA)

### Auto-routing engine
- **Coverage Engine** — AssetWarranty lookup
- **AI Verdict** — Prompt Builder template (`Claim_Risk_Verdict`) returns structured JSON via `ConnectApi.EinsteinLLM`
- **Smart routing** —
  - Auto-approve: `Likely + ≤ $500 + confidence ≥ 90 + dealer trust ≥ 75`
  - Auto-reject: `Eligibility = Not Covered`
  - Queue otherwise for human review

### Approver agent (Slack-native)
- 4 decision paths: **Approve** / **Reject** / **Clarify** / **Goodwill**
- Rich context card with:
  - 📊 Historical precedent ("Of 12 similar claims, 9 were approved")
  - 📡 Vehicle telemetry (Data Cloud–sourced)
  - 🤖 AI verdict + confidence
  - 🏆 Live dealer trust score
- **Golden Rule** pattern: tool call + confirmation in the same turn — no silent successes
- Status-guard hardening prevents already-decided claims from being regressed

### Post-decision automation
- 📄 Branded PDF authorization certificate (Visualforce → ContentDistribution public URL)
- 💬 Three-tier WhatsApp delivery (live push → Chatter audit → guaranteed)
- 🛠 LLM-generated **part-specific repair guidance** to dealer
- 📧 Customer (vehicle owner) notified separately
- 📈 Dealer Trust Score recalculated on every decision (auto-update trigger)

### Operational metrics
- 4-tile dashboard: auto-approval volume, queue depth, median decision time, per-dealer rate
- Custom formula fields: `DecisionTimeHours__c`, `DecisionPath__c` (auto/manual/rejected)

## 🛠 Tech Stack

**Salesforce Products**
- Automotive Cloud — Vehicle, Asset, AssetWarranty, Account, Contact
- Agentforce — Service Agent (ARIA) + Employee Agent (Approver)
- Einstein Hyper Classifier — agent topic routing
- Prompt Builder — 3 active templates with rule-based fallbacks
- Data Cloud — Streams, DLO, DMO, queryable from Apex SOQL
- Digital Engagement — WhatsApp messaging
- Slack for Salesforce — incoming webhook + Agentforce channel binding
- Reports & Dashboards

**Platform Features**
- Apex (15+ classes) · Apex Triggers (2) · Platform Events
- Flow (orchestrator + subflows)
- Visualforce (PDF rendering)
- ContentVersion + ContentDistribution
- Custom Objects, Custom Fields, Formula Fields

**APIs**
- `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate` — live LLM
- `EventBus.publish` — Platform Events
- `Invocable.Action` — agent action standard

## 📂 Repository Layout

```
force-app/main/default/
├── aiAuthoringBundles/              # Agentforce agents
│   ├── Warranty_Approver_Agent_3/   # Slack-facing approver
│   └── Warranty_Dealer_Intake_Agentt_4/ # ARIA — dealer WhatsApp
├── classes/                          # 30+ Apex classes
│   ├── ApproveWarrantyClaim.cls               # Approval invocable
│   ├── RejectWarrantyClaim.cls                # Rejection invocable
│   ├── RequestDealerClarification.cls         # RFI invocable
│   ├── SubmitGoodwillReview.cls               # Goodwill invocable
│   ├── RouteClaimToApproverQueue.cls          # Auto-routing
│   ├── CoverageEngine.cls                     # AssetWarranty lookup
│   ├── GetWarrantyClaimApprovalContext.cls    # Slack card builder
│   ├── InvokeClaimVerdictPrompt.cls           # AI verdict (ConnectApi)
│   ├── ComposeDealerRejectionMessage.cls      # Empathetic rejection
│   ├── ComposeRepairGuidance.cls              # Post-approval tips
│   ├── DealerTrustScoreService.cls            # Trust-score recalc
│   ├── GenerateApprovalAuthorization.cls      # PDF + ContentDistribution
│   ├── NotifyCustomerOfApproval.cls           # Customer WhatsApp
│   ├── SendWhatsAppClaimDecision.cls          # Dealer WhatsApp (3-tier)
│   ├── RefreshTelemetrySignals.cls            # Data Cloud → Platform Event bridge
│   └── ...
├── triggers/
│   ├── ClaimStatusTrigger.trigger              # Trust-score recalc
│   └── TelemetrySignalTrigger.trigger          # Data Cloud event handler
├── flows/                            # Orchestrator + subflows
├── objects/Claim/                    # Custom fields
├── objects/TelemetrySignal__e/       # Platform Event for Data Cloud
├── pages/                            # ApprovalAuthorizationPDF (Visualforce)
├── permissionsets/                   # Agentforce_Permissions, Warranty_Claims_User
├── profiles/                         # Admin profile patches
└── promptTemplates/                  # (configured directly in Prompt Builder UI)

scripts/
├── apex/                             # 4 production-useful scripts
│   ├── seed_demo_telemetry.apex      # Pre-demo telemetry seeder
│   ├── prove_datacloud_chain.apex    # End-to-end Data Cloud verification
│   ├── verify_prompt_templates.apex  # Prompt Template health check
│   └── qa_full_suite.apex            # Integration smoke test (24 assertions)
└── datacloud/
    └── telematics-events.csv         # Sample telemetry data
```

## 📋 Setup for Reviewers

### 1 — Deploy metadata

```bash
sf project deploy start -d force-app -o your-org-alias
```

### 2 — Configure Prompt Templates (UI step)

In **Setup → Prompt Builder**, create 3 Flex templates with single Object resource named `Claim`:
- `Claim_Risk_Verdict` (returns JSON: recommendation/confidence/summary)
- `Compose_Repair_Guidance_Message` (returns plain-text repair tips)
- `Compose_Dealer_Rejection_Message` (returns empathetic rejection text)

Save → **Activate** each. Detailed walkthroughs in [`SUBMISSION.md`](SUBMISSION.md) §8.

### 3 — Configure integrations (UI step)

- **Slack** — install Slack for Salesforce, bind to `#all-electra-cars-approvers`
- **WhatsApp** — Digital Engagement messaging channel
- **Data Cloud** — upload `scripts/datacloud/telematics-events.csv` as a Data Stream

### 4 — Seed demo data

```bash
# Seed claims for demo
sf apex run -f scripts/apex/seed_demo_telemetry.apex -o your-org-alias

# Verify everything works
sf apex run -f scripts/apex/qa_full_suite.apex -o your-org-alias
sf apex run -f scripts/apex/verify_prompt_templates.apex -o your-org-alias
sf apex run -f scripts/apex/prove_datacloud_chain.apex -o your-org-alias
```

Expected: all assertions pass, all 3 templates show `OK LIVE`, Data Cloud chain published events to Claims.

## 🎬 Demo Flow

| # | Action | Expected outcome |
|---|---|---|
| 1 | Open ARIA in WhatsApp · "VIN ELXDEMOFRD0800000, battery dead" | ARIA collects symptom, odometer, cost; submits claim |
| 2 | Watch Slack `#all-electra-cars-approvers` | Rich card appears: AI verdict + precedent + telemetry + trust score |
| 3 | Reply `@Electra Approver approve <claim#> battery defect under coverage` | One-shot approval, PDF link, dealer + customer notified |
| 4 | Submit a "Not Covered" claim | Auto-rejected; dealer gets empathetic LLM-generated rejection |
| 5 | Open dashboard | 4 tiles update live with the day's decisions |

5-minute video script with timing breakdown in [`SUBMISSION.md`](SUBMISSION.md) §8.

## 🐛 Bugs Found & Fixed (QA log)

| # | Bug | Resolution |
|---|---|---|
| 1 | Prompt Templates didn't fire live LLM (`Invocable.Action` rejected `generativeAi:generatePromptTemplateResponse`) | Migrated to `ConnectApi.EinsteinLLM` with `Map<String, Object>` input shape |
| 2 | Goodwill misroute — typing "approve" sometimes called `SubmitGoodwillReview` | Removed broken `confirmed_above_threshold` gate; added explicit `goodwill_intent_confirmed` flag |
| 3 | Goodwill submission failed with `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST` | Fixed picklist value: `'Goodwill'` → `'Goodwill Exception'` |
| 4 | Approved claims could be regressed to "Needs More Info" by an RFI call | Added Apex-level status guards on Approve/Reject/Clarify |
| 5 | JSON parameter dump leaked to Slack channel | Set `require_user_confirmation: False` on decision actions |
| 6 | Data Cloud Data Action UI didn't fire events automatically | Replaced with `RefreshTelemetrySignals` Apex (queries DLM directly) |

Full QA report in commit history.

## 🗺 Roadmap

- **Service Appointment auto-booking** — auto-create `ServiceAppointment` after approval; customer gets appointment link via WhatsApp
- **OEM parts catalog validation** — replace free-text part category with `Product2` lookup
- **Cross-OEM fraud detection** — federate dealer service histories with partner data warehouses
- **Predictive maintenance outreach** — Data Cloud calculated insights flag at-risk VINs before claim filing
- **Warranty-to-upgrade conversion** — high-cost claims on aging vehicles auto-create Opportunity for trade-in consultation

## 📜 License

[MIT License](LICENSE) — original work submitted to the Salesforce Automotive Cloud Hackathon.
No third-party intellectual property included.

---

<div align="center">

**Built with ⚡ for the Salesforce Automotive Cloud Hackathon**

</div>
