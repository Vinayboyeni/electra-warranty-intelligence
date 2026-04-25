# Changelog

All notable changes to this project are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] — Hackathon Submission

### Added
- **ARIA dealer-intake agent** with bilingual (English/Spanish) WhatsApp + Web Chat support
- **Warranty Approver Agent** — Slack-native, 4 decision paths (Approve/Reject/Clarify/Goodwill)
- **Coverage Engine** — AssetWarranty lookup with Likely / Borderline / Not Covered verdicts
- **Auto-routing** — sub-$500 + Likely + trusted dealer auto-approves; Not Covered auto-rejects
- **Prompt Builder integration** — 3 templates (`Claim_Risk_Verdict`, `Compose_Repair_Guidance_Message`, `Compose_Dealer_Rejection_Message`) invoked via `ConnectApi.EinsteinLLM`
- **Branded PDF authorization certificate** — Visualforce → ContentDistribution public URL
- **Three-tier WhatsApp delivery** — live MessagingSession push → Chatter audit → guaranteed
- **Customer notification** — vehicle owner notified separately via WhatsApp
- **Data Cloud telemetry pipeline** — DLM ingestion → Apex aggregation → Platform Event → Trigger → Claim
- **Dealer Trust Score auto-update** — Apex trigger recalculates on every decision over 90-day window
- **Historical precedent** — every Slack approver card shows "Of N similar claims, M were approved"
- **Slack notification flow** — record-triggered, posts rich context card on claim queueing
- **Metrics dashboard recipe** — 4 tiles (auto-approval volume, queue depth, median decision time, per-dealer rate)
- **Status guards** on all 4 decision actions to prevent already-decided claims from being regressed
- **Permission set & profile** — `Agentforce_Permissions`, `Admin` profile patches with all 33 Apex classes + new fields

### Fixed
- Prompt Templates now fire live LLM via `ConnectApi.EinsteinLLM` (replacing broken `Invocable.Action.createStandardAction('generativeAi:generatePromptTemplateResponse')`)
- Prompt Template input must be `Map<String, Object>` keyed by field API names — not the SObject directly
- Goodwill misroute — typing "approve" no longer triggers `SubmitGoodwillReview` due to a tightened `goodwill_intent_confirmed` gate
- Picklist mismatch — `Authorization_Type__c` now correctly uses `Goodwill Exception` (not `Goodwill`)
- Approved claims can no longer be silently regressed by an RFI call (Apex-level status guards added)
- JSON parameter dump no longer leaks to Slack — `require_user_confirmation: False` on Approve/Reject/Goodwill
- Data Cloud Data Action UI replaced with reliable Apex orchestration (`RefreshTelemetrySignals`)

### Changed
- `InvokeClaimVerdictPrompt` now wired into `Action_Create_Warranty_Claim` flow as a record-creation action call (was previously deployed but unreferenced)
- `Approver_Clarification_Flow` deactivated (orphan — agent calls `RequestDealerClarification` directly)

### Removed
- `AuthorizationPdfUrl__c` field (Industries Cloud Claim entity rejected the deploy silently; URL now lives in Chatter audit + WhatsApp body)
- Debug/exploratory scripts (probe_*, check_*, list_vins, etc.)

---

This was built in a single intensive session with iterative QA, architect-level review, and end-to-end integration testing.
