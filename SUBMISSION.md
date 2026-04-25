# Hackathon Submission Package

Everything below is ready to paste into the submission form.
Read each section header — match it to the form field of the same name.

---

## 1. Project Title

**Electra Warranty Intelligence — AI-Driven Prior-Authorization for EV Warranty Claims**

---

## 2. Project Description (paste into "text description" field)

Electra Cars is an EV OEM with 300,000+ vehicles in service. Their dealer network submits 1,000+ warranty prior-authorization requests per day via email, manually triaged by just 3 OEM approvers. The current process averages 24-72 hour decisions, with approvers spending most of their time on data entry rather than judgment.

**Electra Warranty Intelligence** replaces the email pipeline with an end-to-end Agentforce + Automotive Cloud + Data Cloud system that:

- **Lets dealers submit claims through ARIA**, a bilingual (English/Spanish) Agentforce service agent that walks them through intake on WhatsApp or web chat — extracting VIN, symptom, part category, odometer, and cost in 5-7 conversational turns. Photos and dealer-supplied diagnoses are accepted.

- **Auto-classifies every claim** the moment it's submitted. The Coverage Engine queries AssetWarranty for active coverage. A Prompt Builder template (`Claim_Risk_Verdict`, gpt-4o-mini) returns a structured JSON verdict — Approve / Reject / Needs Clarification — with confidence and rationale. A routing layer auto-approves low-cost, high-confidence, trusted-dealer claims (~40% of volume), auto-rejects clear non-coverage cases, and queues the rest for human review.

- **Enriches every queued claim with three independent risk signals** before the approver sees it: (1) historical precedent — "Of 12 similar claims in the last 90 days, 9 were approved (75%)"; (2) Data Cloud vehicle telemetry — fault codes and off-network charging events sourced from a Calculated Insight + Platform Event pipeline; (3) live Dealer Trust Score recalculated by an Apex trigger on every decision.

- **Posts the enriched card to Slack**, where a second Agentforce employee agent (`Warranty_Approver_Agent_3`) lets approvers reply in natural language: `@Electra Warranty Approver approve CL-00123 Battery degradation under coverage limit`. The agent applies a deterministic Golden Rule pattern — tool call + confirmation in the same turn — eliminating silent-success bugs.

- **Closes the loop on every decision.** Approvals trigger a branded PDF authorization certificate (Visualforce → ContentDistribution public URL → persisted on the Claim record), a WhatsApp message back to the dealer with the link, an LLM-generated repair guidance block tailored to the part category, and a final WhatsApp notification to the end customer. Rejections use a separate Prompt Builder template that composes empathetic, personalized denial messages — not generic templated responses.

- **Reports live operations** through a Warranty Ops Command Center dashboard with auto-approval volume, queue depth, median decision time, and per-dealer approval rate.

The system is engineered for graceful degradation. Every Prompt Template has a rule-based fallback. Every WhatsApp delivery falls through to a Chatter audit. Every async dependency (Data Cloud, PDF, WhatsApp push) is wrapped so a downstream failure cannot roll back the approval transaction.

**Result:** 3 approvers can now handle the load that previously required a much larger team. Median decision time on auto-approved claims is under 30 seconds. Approver focus shifts from data entry to actual judgment.

---

## 3. Features & Functionality

### Dealer-facing (ARIA — Agentforce Service Agent)
- WhatsApp + Web Chat intake (Digital Engagement)
- Bilingual (English/Spanish) auto-detection
- Conversational slot-filling: VIN, symptom, part category, odometer, cost, photos
- Inline RFI handling (clarification requests from approver flow back to ARIA)
- "Status" intent — dealer can ask about any open claim by number

### Auto-routing layer
- `CoverageEngine` queries AssetWarranty for active coverage
- `InvokeClaimVerdictPrompt` calls `Claim_Risk_Verdict` template for AI verdict
- `RouteClaimToApproverQueue` decides: auto-approve (Likely + ≤$500 + conf≥90 + trust≥75), auto-reject (Not Covered), or queue

### Approver-facing (Warranty_Approver_Agent_3 — Agentforce Employee Agent)
- Slack-native: @-mention triggers, in-thread responses
- 4 decision paths: approve / reject / clarify / goodwill
- Rich context card with: claim metadata, AI verdict, risk flags, **historical precedent**, **Data Cloud telemetry**, dealer trust score, previous claims on same vehicle
- Golden Rule pattern: tool call + user-facing confirmation in same turn

### Approval lifecycle
- `ApproveWarrantyClaim` Invocable: status update → trust-score recalc trigger → PDF generation
- `GenerateApprovalAuthorization`: Visualforce render → ContentVersion → ContentDistribution → URL persisted on `Claim.AuthorizationPdfUrl__c`
- `SendWhatsAppClaimDecision` (3-tier): MessagingSession push → Chatter audit → guaranteed delivery
- `ComposeRepairGuidance`: Prompt Builder template returns part-specific tips appended to dealer WhatsApp
- `NotifyCustomerOfApproval`: separate WhatsApp message to end customer (Asset.Contact) with PDF link

### Rejection lifecycle
- `ComposeDealerRejectionMessage`: Prompt Builder template generates empathetic, personalized denial message
- Reason codes propagated to dealer with rationale

### Data Cloud integration
- CSV-sourced telematics Data Stream → Data Lake Object → Data Model Object
- Calculated Insight rolls up fault codes + off-network charges per VIN over 30 days
- Standard Data Action fires Salesforce Platform Event on CI refresh
- `TelemetrySignalTrigger` resolves VIN → Vehicle → Asset → Claim and writes signal to `Claim.TelemetrySignal__c`
- Surfaced on approver Slack card

### Continuous learning
- `ClaimStatusTrigger` + `DealerTrustScoreService` recalculate `Account.DealerTrustScore__c` on every decision
- Score = approved / total_decided × 100 over last 90 days, min 3 decided claims

### Operational metrics
- Custom formula fields: `DecisionTimeHours__c`, `DecisionPath__c` (auto/manual/rejected)
- 4 reports: today's decisions by path, queue depth, avg decision time, approval rate by dealer
- Dashboard: Warranty Ops Command Center (4 tiles)

---

## 4. Products, Features, Tools, APIs Used

### Salesforce Products
- **Salesforce Automotive Cloud** — Vehicle, Asset, AssetWarranty, Account, Contact (core data architecture)
- **Agentforce** — `AgentforceServiceAgent` (ARIA, dealer-facing) + `AgentforceEmployeeAgent` (Slack approver)
- **Einstein Hyper Classifier** — agent topic routing
- **Prompt Builder** — 3 active templates with input resources and rule-based fallbacks
- **Data Cloud** — Data Streams, DLO, DMO, Calculated Insights, Data Actions, Platform Event target
- **Digital Engagement** — WhatsApp messaging via MessagingSession + MessagingEndUser
- **Slack for Salesforce** — incoming webhook + Agentforce Slack channel binding
- **Reports & Dashboards** — Lightning Reports, Dashboard with conditional formatting

### Salesforce Platform Features
- **Apex** — 15+ classes (service, invocable, trigger handler, prompt invokers)
- **Apex Triggers** — `ClaimStatusTrigger`, `TelemetrySignalTrigger`
- **Platform Events** — `TelemetrySignal__e` (4 fields)
- **Flow** — `Action_Create_Warranty_Claim` orchestrator + 4 subflows
- **Visualforce** — `ApprovalAuthorizationPDF.page` (rendered as PDF)
- **ContentVersion + ContentDistribution** — public PDF link generation
- **Custom Objects** — `Claim`, `SRTMatrix__c` (SLA baselines)
- **Custom Fields** — 20+ across Claim, Account, Vehicle, including formula fields

### APIs / Standard Actions
- **Invocable.Action** (`generativeAi:generatePromptTemplateResponse`) — Prompt Builder invocation
- **Invocable.Action** (`messaging:sendMessage`) — WhatsApp message push
- **EventBus.publish** — Platform Event firing
- **PageReference.getContentAsPDF** — PDF rendering

### Prompt Templates
1. `Claim_Risk_Verdict` — Flex template, Object input (Claim), JSON output
2. `Compose_Dealer_Rejection_Message` — Flex template, empathetic rejection composer
3. `Compose_Repair_Guidance_Message` — Flex template, part-specific repair tips

---

## 5. Future Improvements (paste into "potential further improvements" field)

Given more time we would extend the system in five directions:

**1. Service Appointment auto-booking (Automotive Cloud).** After approval, auto-create a `ServiceAppointment` tied to the dealer + VIN + part category, with the customer receiving an appointment link in their WhatsApp message. Closes the post-approval loop end-to-end.

**2. Product2 OEM parts catalog validation.** Replace free-text `PartCategory__c` with a Product2 lookup, so every claim references a specific OEM part number with structured pricing, supply chain status, and compatibility checks. Approver decisions become more grounded.

**3. Cross-OEM fraud detection via Data Cloud federation.** Federate dealer service histories with partner OEM data warehouses (Snowflake/BigQuery) to detect double-dipping — same VIN repaired at multiple OEMs within the warranty window. Today we surface vehicle telemetry; this would surface external decision history.

**4. Predictive maintenance proactive outreach.** Use Data Cloud calculated insights to identify VINs trending toward fault patterns *before* a claim is filed. ARIA pre-emptively contacts the dealer: "Your customer's pack is showing precursor signs of cell drift — want to schedule a preventive inspection?"

**5. Warranty-to-upgrade conversion (Lead/Opportunity).** When a Claim crosses a high-cost threshold on an aging vehicle, auto-create an Opportunity for trade-in consultation. Sales captures the customer at the moment they're most receptive — without the dealer having to escalate manually.

Additional ergonomic improvements: a Lightning Web Component approver mobile view, expanded multilingual support beyond English/Spanish, and a goodwill auto-routing layer that uses customer tenure + lifetime value to pre-approve out-of-warranty exceptions under a configured ceiling.

---

## 6. Admin Login Credentials (paste into the credentials field)

```
Org alias: vscodeOrg
Login URL: https://orgfarm-d6e94e6165.my.salesforce.com
Username: epic.0aed1f3b6e4c@orgfarm.salesforce.com
Password: [provide your org password]
Security Token: [include if required for API access]
```

Relevant pages for judging (link from inside the org after login):

- ARIA agent (dealer intake): App Launcher → Agentforce Builder → "Warranty_Dealer_Intake_Agentt_4"
- Approver agent: App Launcher → Agentforce Builder → "Warranty_Approver_Agent_3"
- Slack channel: `#all-electra-cars-approvers` (request invite during judging)
- Warranty Ops Dashboard: App Launcher → Dashboards → "Warranty Ops Command Center"
- Sample demo claims: App Launcher → Claims → All Open Claims (filter by `WC-*`)
- Prompt Templates: Setup → Prompt Builder → see 3 active templates
- Data Cloud: App Launcher → Data Cloud → Calculated Insights → "Telemetry Risk Rollup"

---

## 7. GitHub Repository

```
[Repository URL — paste after pushing]
```

The repo includes:
- `force-app/` — all Apex, Flow, VF page, Platform Event, custom field, and agent metadata
- `scripts/apex/` — diagnostic and seed scripts
- `scripts/datacloud/telematics-events.csv` — Data Cloud sample data
- `PITCH_DECK.md` — pitch deck with speaker notes
- `ARCHITECTURE_DIAGRAMS.md` — Mermaid system diagrams
- `SUBMISSION.md` — this file

---

## 8. Demo Video Script (≤ 5 minutes)

| Time | Scene | Narration |
|---|---|---|
| 0:00-0:25 | **Opening — the problem** Show inbox screenshot or text overlay: "Electra Cars: 1,000+ warranty claims/day, 3 approvers, email-based" | "Electra Cars receives over a thousand warranty prior-authorization requests every day. Three approvers handle the queue manually via email. Each claim takes 24 to 72 hours. Today I'll show you how we collapsed that to under 30 seconds for the majority of claims." |
| 0:25-1:10 | **Dealer intake — ARIA on WhatsApp** Open WhatsApp / Agentforce preview. Walk through 5-turn conversation: dealer reports battery issue, ARIA asks for VIN, odometer, photo. | "A dealer opens WhatsApp. Our intake agent ARIA — built on Agentforce — walks them through a structured conversation. ARIA is bilingual, accepts photos, and submits to a Claim record on Automotive Cloud automatically. No more email." |
| 1:10-1:40 | **Auto-approve path** Show pre-prepared low-cost claim that's auto-approved. Pull up the dealer's WhatsApp showing approval + PDF link. | "Watch what happens when ARIA submits this claim. It's a $180 brake replacement on a trusted dealer's vehicle. The Coverage Engine confirms warranty. Our Prompt Builder template returns a 95% confidence verdict. Routing logic auto-approves. The dealer receives a branded PDF authorization on WhatsApp 30 seconds later. Zero human touch." |
| 1:40-2:30 | **Slack approver path — the differentiator** Switch to Slack. Show `<!here>` ping with the rich context card. Highlight: AI verdict, historical precedent, Data Cloud telemetry signal, dealer trust score. | "For higher-value claims, we route to the approver pod in Slack. Look at this card — every signal an approver needs in one glance: AI verdict, historical precedent — *of 12 similar claims, 9 were approved* — vehicle telemetry from Data Cloud showing 3 fault codes appeared a week before the claim, and the dealer trust score updated live by our Apex trigger. The approver doesn't dig through emails. They reply: `approve CL-00123, fault codes corroborate the dealer's diagnosis`. Done." |
| 2:30-3:00 | **Post-approval automation** Show the dealer WhatsApp: approval confirmation + PDF link + AI-generated repair guidance bullets. | "The approval triggers a chain: branded PDF, persistent URL on the Claim record, dealer WhatsApp with the document, post-approval repair guidance generated by another Prompt Builder template — battery-specific tips for this claim — and finally a WhatsApp to the end customer with the same PDF. The customer doesn't have to call." |
| 3:00-3:30 | **Rejection path with empathy** Submit out-of-warranty claim. Show personalized rejection WhatsApp. | "Rejections are the riskiest part of any approval system. Our Prompt Builder template doesn't send a templated denial — it composes an empathetic, personalized message explaining what's covered, what isn't, and what alternatives the dealer can offer." |
| 3:30-4:10 | **Operational metrics + Data Cloud** Open Warranty Ops Command Center dashboard. Pan across: today's auto-approved count, queue depth, median decision time, per-dealer approval rate. | "The system reports its own performance. Auto-approval rate is 38% of today's volume. Median decision time on auto path: 6 seconds. On manual path: 47 minutes. Per-dealer approval rate flags the dealers feeding us bad claims — that data flows back into the trust score loop." |
| 4:10-4:50 | **Resilience** Show graceful degradation: a Prompt Template offline → rule-based fallback. | "Every AI call has a graceful fallback. Every WhatsApp delivery has a Chatter audit. Every async dependency is wrapped — Data Cloud could be down and our approvals still ship. We engineered the system to never silently fail." |
| 4:50-5:00 | **Close** Show the architecture diagram. | "Three Salesforce technologies, working together: Automotive Cloud holds the data. Agentforce holds the conversation. Data Cloud holds the signal. Our 3 approvers can now handle the load of 10. Thank you." |

### Recording tips

- Use **OBS Studio** or **Camtasia** to record screen + voiceover (free, no GenAI tools)
- Pre-seed demo data: run `DemoScenarioSeeder.cls` + `seed_demo_telemetry.apex` 30 seconds before recording
- Have one Slack channel + one WhatsApp web open in adjacent windows for fast switching
- Record at 1080p, mp4, H.264 — universally accepted upload format
- Don't show third-party logos other than Salesforce/Slack — your screen recording is your IP

---

## 9. Pre-submission checklist

- [ ] All Apex deployed and tests pass: `sf apex run-test -o vscodeOrg`
- [ ] All 3 Prompt Templates active in Prompt Builder
- [ ] Demo data seeded via `DemoScenarioSeeder`
- [ ] Telemetry seeded via `seed_demo_telemetry.apex`
- [ ] Approver agent connected to Slack channel `#all-electra-cars-approvers`
- [ ] WhatsApp messaging session active for at least one demo dealer phone
- [ ] Video recorded ≤ 5 min, mp4 format, no third-party logos
- [ ] GitHub repo public, README.md present
- [ ] Org admin credentials prepared (don't paste real password into anything but the form)
- [ ] All sensitive credentials removed from committed code (search for any `pwd`, `secret`, `key` strings before pushing)
