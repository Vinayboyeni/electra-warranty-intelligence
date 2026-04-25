# Electra Cars Warranty Claim Agent — Functional Specification

**Hackathon Submission | Automotive Cloud + Agentforce**

---

## 1. Executive Summary

Electra Cars is an Original Equipment Manufacturer (OEM) with 300,000+ vehicles on the road. Its dealer network submits 1,000+ warranty claim prior-authorization requests per day, handled manually by only 3 OEM claim approvers. The result is a severe bottleneck: claims sit in email queues, dealers repeat information, and approvers cannot reach data-backed decisions quickly.

**This solution replaces the manual email-to-approval process with an AI-driven, conversational workflow** spanning WhatsApp (for dealer intake) and Slack (for OEM approver adjudication), with all claim records stored structurally in Salesforce Automotive Cloud.

---

## 2. Business Problem

| Current State | Impact |
|---|---|
| 1,000+ warranty claims/day arriving via unstructured email | Manual triage consumes most adjuster capacity |
| 3 OEM claim approvers handling the entire volume | 24–72 hour response delays; dealer frustration |
| Each email manually opened, attachments inspected, data verified | Decision quality varies by individual adjuster fatigue |
| No real-time visibility into claim status for dealers | High repeat contact rate ("where is my claim?") |
| Coverage rules, SRT baselines, and precedent live in adjuster memory | Inconsistent decisions; no auditable trail |

---

## 3. Solution Overview

A two-agent, three-channel system:

| Persona | Channel | Agent |
|---|---|---|
| **Dealership Service Advisor** | WhatsApp | **ARIA** — Authorized Repair Intelligence Assistant |
| **OEM Warranty Approver (Adjuster)** | Slack | **Warranty Approver Agent v3** — Internal adjuster assistant |
| **Warranty Policy Manager** | Slack / Salesforce | Manual review for Goodwill exceptions |

Each conversation creates or updates a structured `Claim` record in Automotive Cloud. AI handles data capture, coverage evaluation, estimate validation, image damage analysis, duplicate prevention, and precedent-aware recommendations.

---

## 4. Personas

### 4.1 Dealership Service Advisor (Dealer)
- Works at an authorized Electra Cars service center
- Receives a customer vehicle with a warranty issue
- Needs prior authorization from OEM before starting the repair
- Prefers fast, mobile-friendly interactions — uses WhatsApp on a phone between jobs
- Volume: ~3–10 claims per day per advisor

### 4.2 OEM Warranty Claim Approver (Adjuster)
- Employee of Electra Cars at the OEM
- Reviews claims from the dealer network and approves/rejects/clarifies
- Works primarily in Slack (with Salesforce console as fallback for complex cases)
- Authority: unilateral approval up to $2,000; above that requires explicit confirmation
- Volume: currently ~300+ claims/day per adjuster — the target is to reduce this through auto-approval of low-risk claims

### 4.3 Warranty Policy Manager
- Senior OEM role responsible for Goodwill exceptions and escalated cases
- Reviews claims where standard coverage is denied but compelling business case exists
- SLA: 48–72 business hours

---

## 5. User Journeys

### 5.1 Primary Journey — Dealer Submits a Warranty Claim (WhatsApp)

**Scenario:** A dealer needs prior authorization to replace a battery on a 2024 Electra X5 at 40,000 miles.

```
1. Dealer opens WhatsApp, types "hi" to ARIA's number
2. ARIA greets and asks for VIN
3. Dealer: "vin is ELX10000000000001"
4. ARIA verifies vehicle in Automotive Cloud → "2024 Electra X5 Sport verified"
5. ARIA collects (one field per message):
   - Odometer reading
   - Part category (Battery)
   - Symptom description
   - Fault date
   - Repair order number
6. ARIA checks for duplicate open claims on same VIN + part (silent)
7. ARIA evaluates coverage → "Likely"
8. ARIA asks for optional DTC code (dealer types NONE)
9. ARIA asks for estimated repair amount ($4,200)
10. ARIA validates against SRT baseline ($4,500) — within range, proceeds silently
11. ARIA shows claim summary, asks for YES confirmation
12. Dealer: "Yes"
13. ARIA creates Claim record → returns "WC-K7F3M"
14. ARIA asks for optional damage photo
15. If photo sent → AI image analysis runs, attaches to claim
16. Dealer can reply "STATUS" anytime to check progress
```

**Outcome:** Structured Claim record created. OEM approver auto-notified in Slack. SLA clock starts (24 business hours).

### 5.2 Secondary Journey — Approver Reviews Claim (Slack)

**Scenario:** Approver sees a new Slack notification and needs to decide.

```
1. Slack channel shows the claim card: vehicle, dealer, symptom, AI verdict, risk flags, previous claims
2. Approver types: "review WC-K7F3M" in Slack
3. Approver Agent v3 loads full context via GetWarrantyClaimApprovalContext
4. Approver reviews AI recommendation (Approve, 90% confidence)
5. Approver types: "approve — battery capacity degradation confirmed"
6. Agent captures rationale (audit trail), checks cost ≤ $2000 → auto-confirms
7. Agent calls ApproveWarrantyClaim Apex
8. Claim status = Approved
9. Dealer receives WhatsApp confirmation on the same thread:
   "✅ Claim WC-K7F3M approved! Proceed with repair."
```

### 5.3 Exception Journey — Approver Needs More Info

```
1. Approver: "clarify WC-00123 — need before/after photos of the engine mount"
2. Agent calls RequestDealerClarification Apex
3. Claim.Status = "Needs More Info"
4. Apex looks up dealer's WhatsApp session from DealerWhatsAppNumber__c
5. ARIA posts the question into the SAME WhatsApp thread
6. Dealer sees the question inline, replies with explanation + photo
7. ARIA's ApproverFollowUp subagent captures the response
8. Claim.Status flips back to "Pending Approver Review"
9. Approver sees the dealer's reply in the original Slack thread
```

### 5.4 Exception Journey — Coverage Denied but Goodwill Requested

```
1. Coverage verdict = "Not Covered" (odometer just outside range)
2. Dealer types "GOODWILL" or approver says "approve anyway"
3. Agent routes to GoodwillReview subagent
4. Asks for justification (loyal customer, safety-critical, etc.)
5. Calls SubmitGoodwillReview Apex
6. Warranty Policy Manager reviews within 48–72 hours
7. Dealer notified on same WhatsApp thread
```

### 5.5 Status Inquiry Journey

```
1. Dealer types "STATUS WC-K7F3M" or "where is my claim"
2. ARIA routes to ClaimStatusInquiry subagent
3. Returns: current status, assigned approver, SLA due, approver comments
```

---

## 6. Business Rules

### 6.1 Warranty Coverage Terms
| Coverage | Term |
|---|---|
| Standard warranty | 4 years / 50,000 miles (whichever first) |
| Powertrain (Engine, Transmission, Drive Motor) | 5 years / 60,000 miles |
| EV Battery extended warranty | 8 years / 100,000 miles |

### 6.2 Covered Part Categories
Engine, Transmission, Drive Motor, HVAC, Suspension, Brake System, Electrical System, Charging System, Infotainment, Battery.

### 6.3 NOT Covered (Wear Items)
Brake pads, tires, wiper blades.

### 6.4 Auto-Approval Criteria (all must be true)
- Eligibility = "Likely"
- Estimated Cost ≤ $500
- AI Confidence ≥ 90%
- Dealer Trust Score ≥ 75/100

Auto-approved claims skip the Slack notification and are immediately marked Approved.

### 6.5 Adjuster Authority
- Unilateral approval up to $2,000
- Claims above $2,000 require explicit "yes" confirmation in the chat
- Goodwill exceptions always require Warranty Policy Manager review

### 6.6 SRT (Standard Repair Time) Validation
- Every repair estimate is compared against a baseline maintained in `SRTMatrix__c` custom object (with hardcoded fallback)
- Variance > 20% above baseline → dealer must provide written justification (stored as `srtJustification`)
- Justification is visible to the approver in Slack for informed decisions

### 6.7 Duplicate Prevention
- Before creating a new claim, ARIA checks for open claims on the same VIN + part category within the last 30 days
- If found, the dealer is warned and offered to update the existing claim or file a separate one

### 6.8 SLA
- Standard approver review: 24 business hours from claim submission
- Goodwill review: 48–72 business hours
- Clarification response: dealer expected within 24 hours; claim auto-expires if no response after 5 business days

### 6.9 Safety Rule
If the dealer mentions fire, smoke, brake failure, or steering loss — ARIA immediately:
1. Halts the claim workflow
2. Provides the Electra Safety Hotline: 1-800-ELECTRA (24/7)
3. Marks the claim Priority = High and flags for fast-track review

---

## 7. Features by Persona

### 7.1 ARIA (Dealer-Facing)
| Feature | Description |
|---|---|
| Conversational VIN lookup | Validates 17-char VIN against Vehicle records |
| Guided data intake | Collects claim fields one at a time, WhatsApp-optimized |
| Coverage evaluation | Real-time Likely/Borderline/Not Covered verdict |
| DTC decoding | Translates OBD-II codes (P0456, P0A80) into plain English |
| SRT validation | Flags estimates >20% above baseline for justification |
| Duplicate detection | Prevents re-submission within 30 days |
| Photo analysis | Vision AI damage assessment on uploaded photos |
| Status lookup | "Where is my claim?" self-service |
| Multilingual (English/Spanish) | Auto-detects language from first message |
| Goodwill request | Easy escalation path when coverage is denied |
| Safety halt | Fire/smoke/brake/steering trigger Electra Safety Hotline |

### 7.2 Approver Agent v3 (Adjuster-Facing)
| Feature | Description |
|---|---|
| Instant Slack notification | Rich claim card with AI verdict, risk flags, precedent |
| Context loader | One-call retrieval of all relevant claim/dealer/vehicle data |
| Approve / Reject / Clarify / Goodwill | All decisions from Slack chat |
| Shortcut commands | `APPROVE WC-XXXXX [reason]` — one-shot processing |
| $2,000 deterministic gate | Hard stop above threshold, auto-confirm below |
| Already-decided guard | Prevents re-approving a closed claim |
| Fraud safety rule | Refuses auto-approval when risk flags present |
| Goodwill routing | Smart path when adjuster tries to override "Not Covered" |
| Queue overview | Find claims by number or VIN |
| Policy FAQ | Answers coverage questions without leaving Slack |

---

## 8. Success Metrics (KPIs)

| Metric | Baseline | Target |
|---|---|---|
| Average claim submission time | 10–15 min (email) | < 3 min (WhatsApp conversation) |
| Claims auto-approved without human review | 0% | 30–40% (low-risk, <$500) |
| Approver decision time (human-needed claims) | 24–72 hrs | < 2 hrs median |
| Dealer repeat-contact rate ("where is my claim?") | High | Reduce 70% via self-service STATUS |
| Claim data completeness at submission | Variable | 100% (structured fields) |
| Missed SLA rate | Not tracked | < 5% |
| Fraud claim detection | Manual / reactive | Proactive via Data Cloud calculated insight |

---

## 9. Out of Scope (Hackathon)

- Payment processing / reimbursement workflow
- Parts inventory integration
- Field service dispatch
- Warranty policy management UI (rules are coded)
- Mobile-native app (WhatsApp is the mobile channel)
- Full Data Cloud DMO buildout (only calculated insight included)

---

## 10. Future Roadmap

### Phase 2 (Post-Hackathon)
- Prompt Builder templates for AI-drafted clarification questions and rejection letters
- Full Data Cloud integration with RAG (retrieval-augmented generation) against historical claims
- Agentforce Prompt Builder flex templates to replace hardcoded policy rules
- Vehicle Service History DMO for "this part has failed before" detection
- Dealer Trust Score auto-computation from payment + dispute history

### Phase 3 (Production)
- Predictive claim routing based on symptom patterns
- Multi-language expansion (French, German, Portuguese)
- Video-call escalation for complex cases
- Integration with dealer DMS systems for auto-populated RO data
- Customer-facing transparency portal ("my repair status")

---

## 11. Compliance & Audit Requirements

- Every approve/reject/goodwill decision captures an adjuster **Decision Rationale** (audit trail)
- All claim status changes recorded via Chatter FeedItems on the Claim record
- `ApproverSlackRef__c` field links each decision to its originating Slack thread
- Warranty policy rules are version-controlled in source (Apex + agent YAML)
- All dealer interactions are logged via `MessagingSession` records
- Goodwill exceptions are tracked via a dedicated Record Type on `Claim`

---

## Appendix A — Glossary

| Term | Definition |
|---|---|
| **ARIA** | Authorized Repair Intelligence Assistant (dealer-facing agent) |
| **DTC** | Diagnostic Trouble Code — standard OBD-II fault code (e.g., P0456) |
| **OEM** | Original Equipment Manufacturer — Electra Cars in this context |
| **RFI** | Request For Information — approver's clarification question to dealer |
| **RO** | Repair Order number — dealer's internal DMS reference |
| **SLA** | Service Level Agreement — response time commitment |
| **SRT** | Standard Repair Time — OEM's baseline labor/parts cost matrix |
| **Trust Score** | 0–100 rating of dealer reliability based on historical behavior |
| **TSB** | Technical Service Bulletin — OEM-published known-issue notice |
| **VIN** | Vehicle Identification Number (17 characters) |
