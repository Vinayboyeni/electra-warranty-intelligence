# Electra Warranty Intelligence

AI-driven warranty prior-authorization for EV OEMs, built on Salesforce Automotive Cloud + Agentforce + Data Cloud.

## The problem

Electra Cars is an EV OEM with 300,000 vehicles in service. Their dealer network submits **1,000+ warranty prior-authorization requests per day** via email, manually triaged by **3 approvers**. Median decision time is 24–72 hours.

## The solution

| | Before | After |
|---|---|---|
| Intake channel | Email + PDF forms | WhatsApp / Web Chat (ARIA conversational agent) |
| Triage | Manual, 1 claim at a time | Auto-classified at submission via Coverage Engine + Prompt Builder verdict |
| Approval | Inbox triage | Slack-native, rich context card |
| Decision time (auto path) | 24–72 hours | < 30 seconds |
| Approver capacity | ~333 claims/day each | ~3x with auto-routing taking 40% off the queue |

## Architecture

```
DEALER ─WhatsApp─▶ ARIA ─▶ Claim record ─▶ Coverage Engine + AI Verdict
                                                      │
                                              Auto-route layer
                                              ┌────────┼────────┐
                                              ▼        ▼        ▼
                                        Auto-approve  Queue   Auto-reject
                                              │        │        │
                                              ▼        ▼        ▼
                                       (PDF + WhatsApp) Slack   (rejection
                                                       card     WhatsApp)
                                                       │
                                                       ▼
                                             Approver Agent (Slack)
                                                       │
                                                       ▼
                                             approve / reject / clarify
                                                       │
                                                       ▼
                                       PDF + WhatsApp to dealer
                                       Repair guidance
                                       Customer WhatsApp
                                       Trust score recalc
```

See [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md) for full sequence and component diagrams.

## Repository layout

```
force-app/main/default/
├── aiAuthoringBundles/          # Agentforce agents (ARIA, Approver)
├── classes/                      # 15+ Apex classes
│   ├── ApproveWarrantyClaim.cls               # Approval invocable
│   ├── RejectWarrantyClaim.cls                # Rejection invocable
│   ├── RouteClaimToApproverQueue.cls          # Auto-routing logic
│   ├── CoverageEngine.cls                     # AssetWarranty lookup
│   ├── GetWarrantyClaimApprovalContext.cls    # Slack card builder
│   ├── InvokeClaimVerdictPrompt.cls           # Prompt Builder invoker
│   ├── ComposeDealerRejectionMessage.cls      # Empathetic rejection
│   ├── ComposeRepairGuidance.cls              # Post-approval tips
│   ├── DealerTrustScoreService.cls            # Trust score recalc
│   ├── GenerateApprovalAuthorization.cls      # PDF + ContentDistribution
│   ├── NotifyCustomerOfApproval.cls           # Customer WhatsApp
│   ├── SendWhatsAppClaimDecision.cls          # Dealer WhatsApp (3-tier)
│   └── ...
├── triggers/
│   ├── ClaimStatusTrigger.trigger             # Trust score recalc trigger
│   └── TelemetrySignalTrigger.trigger         # Data Cloud event handler
├── flows/                        # Orchestrator + subflows
├── objects/
│   ├── Claim/                    # Custom fields (TelemetrySignal, etc.)
│   └── TelemetrySignal__e/       # Platform Event for Data Cloud
└── pages/
    └── ApprovalAuthorizationPDF.page          # Branded PDF certificate

scripts/
├── apex/
│   ├── seed_demo_telemetry.apex               # Pre-demo telemetry seeder
│   ├── diagnose_telemetry.apex                # End-to-end chain diagnostic
│   └── backfill_authorization_urls.apex       # Backfill PDF URLs
└── datacloud/
    └── telematics-events.csv                  # Data Cloud sample data
```

## Prompt Builder templates

Three templates, all in Prompt Builder UI:

1. **`Claim_Risk_Verdict`** — Flex template, takes Claim record, returns JSON `{recommendation, confidence, summary}`
2. **`Compose_Dealer_Rejection_Message`** — Flex template, generates empathetic personalized denial
3. **`Compose_Repair_Guidance_Message`** — Flex template, returns part-specific repair tips

Every template has a rule-based fallback in Apex so the system never silently fails.

## Data Cloud integration

CSV-sourced telematics → DLO → DMO → Calculated Insight → Data Action → Salesforce Platform Event → Apex trigger writes signal to `Claim.TelemetrySignal__c` → surfaced on approver Slack card.

## Setup (for judges / reviewers)

1. **Deploy metadata:**
   ```bash
   sf project deploy start -d force-app -o your-org-alias
   ```
2. **Seed demo data:** run `DemoScenarioSeeder.cls` from anonymous Apex
3. **Configure Prompt Templates** — see `SUBMISSION.md` for UI walkthroughs of all 3 templates
4. **Connect Slack** — install the Slack for Salesforce app, bind to `#all-electra-cars-approvers`
5. **Configure WhatsApp** — Digital Engagement messaging channel
6. **Seed telemetry signals (pre-demo):**
   ```bash
   sf apex run -f scripts/apex/seed_demo_telemetry.apex -o your-org-alias
   ```

## Demo flow

See `SUBMISSION.md` Section 8 for the 5-minute video script.

Quick path:
1. Open ARIA preview → submit a claim for VIN `ELXDEMOFRD0800000`
2. Watch auto-route to Slack queue
3. View enriched Slack card with AI verdict + telemetry + precedent
4. Approve via `@Electra Warranty Approver approve <claim#> <rationale>`
5. Verify dealer WhatsApp + PDF + customer WhatsApp + trust score recalc

## Tech stack

- Salesforce Automotive Cloud (Vehicle, Asset, AssetWarranty, Account, Contact)
- Agentforce (Service Agent + Employee Agent)
- Einstein Hyper Classifier
- Prompt Builder (3 templates)
- Data Cloud (Streams, DLO, DMO, CI, Data Action, Platform Event target)
- Digital Engagement (WhatsApp)
- Slack for Salesforce
- Apex, Triggers, Platform Events, Flow, Visualforce
- Reports & Dashboards

## License & attribution

Original work submitted to the Salesforce Automotive Cloud Hackathon.
No third-party intellectual property included.
