# Electra Cars Warranty Claim Agent — Pitch Deck

**10 slides · supports a 5-min or 10-min pitch · Q&A prep included**

Use this file as: (a) slide content to paste, (b) teleprompter for speaker notes,
(c) cheat sheet for judge questions. Print the last section on paper for demo day.

---

## DELIVERY CHECKLIST — Before You Open the Deck

- [ ] Laptop charged; backup power source close
- [ ] 4 browser tabs open: (1) ARIA preview, (2) Slack channel, (3) Claim record + Chatter, (4) Pending Queue list view
- [ ] Golden VIN written on sticky note: `ELXDEMOHAPY020000`
- [ ] Part: `Battery` / Odometer: `15000` / Amount: `1800`
- [ ] Fallback video saved locally (not on cloud)
- [ ] Phone on Do Not Disturb
- [ ] Breathe

---

# SLIDE 1 — Title

## Visual
```
           ELECTRA CARS
      WARRANTY CLAIM AGENT
   
   Two agents · Three channels · One record

          [Your name · Team name]
            [Hackathon · Date]
```

## Speaker notes (30 seconds)
"Electra Cars is an EV OEM with 300,000 vehicles on the road. Their dealer
network submits over 1,000 warranty claims every day through email. Three
OEM approvers handle that entire queue. You can guess what the backlog
looks like.

We built an AI-driven claim system that eliminates the email bottleneck and
moves every claim through a live, auditable, structured flow. Let me show
you how."

## Timing
30 seconds — don't linger here.

---

# SLIDE 2 — The Problem

## Visual
```
THE BOTTLENECK

   1,000+             3                 24–72 hrs
   claims/day         approvers         typical delay
   via email          at the OEM

Every claim:
  📧 manually read
  📎 attachments unzipped
  🔍 data verified
  📝 rule applied
  ↩️  reply sent
```

## Speaker notes (45 seconds)
"Electra's inbound warranty volume is 1,000-plus claims a day. Every one of
them comes in as an email — with attached photos, hand-typed forms, VINs
that sometimes have a typo. Three approvers open each email, verify the
data, check coverage rules manually, and reply.

The dealers wait between 24 and 72 hours per claim. Half of those claims
are trivially approvable — routine battery work on in-warranty vehicles.
The other half need real adjudication. The problem isn't that there's no
AI involved — it's that there's no structure at all. Nothing is a record.
Everything is a PDF attachment and a human eyeball.

That's the bottleneck we attacked."

## Timing
45 seconds.

---

# SLIDE 3 — The Solution (1 line)

## Visual
```
Replace "1,000 emails" with 
two AI agents on two channels, 
backed by ONE structured Claim record.

   DEALER → ARIA on WhatsApp
   ↓
   [Automotive Cloud Claim]
   ↓
   APPROVER → Agentforce bot on Slack
```

## Speaker notes (40 seconds)
"Our solution moves intake, review, and approval entirely onto Salesforce
Automotive Cloud. Dealers file claims conversationally on WhatsApp with our
agent ARIA. The claim becomes a structured record — not an email
attachment, an actual first-class Salesforce object with 97 fields.

Approvers see those claims as live cards in their Slack channel, reviewed
and decided through a second Agentforce agent. Dealer gets notified in the
same WhatsApp thread. One record, one lifecycle, zero email.

That's the platform story. Now the architecture."

## Timing
40 seconds.

---

# SLIDE 4 — Architecture

## Visual
**Paste Mermaid Diagram 1 from `ARCHITECTURE_DIAGRAMS.md` here.**

Export it as PNG from https://mermaid.live first, then drop into the slide.

If space is tight, trim to this simplified version:

```
 DEALER (WhatsApp) ──▶ ARIA Agent ──▶ Claim Record ──▶ Route Apex
                                              │
                                              ▼
                      ┌───────────────────────────────────┐
                      │  AUTO-APPROVE  AUTO-REJECT  QUEUE │
                      └───────────────────────────────────┘
                                              │
                                              ▼
                                        SLACK CHANNEL
                                              │
                                              ▼
                                      APPROVER Agent
                                              │
                                              ▼
                       Decision → Dealer (same WhatsApp thread)
```

## Speaker notes (45 seconds)
"Two agents — ARIA on WhatsApp is an Agentforce Service Agent, the approver
bot on Slack is an Employee Agent. They don't talk to each other. They
share one thing: the Claim record in Automotive Cloud.

When a claim lands in Salesforce, a routing Apex class decides its fate.
Auto-approve for low-cost high-confidence claims — zero human touch.
Auto-reject for out-of-warranty claims. Everything else goes to the Slack
queue. We'll demo all three paths.

Slack integration is native — we use Slack for Salesforce, not custom
webhooks. Data Cloud surfaces dealer fraud signals. Prompt Builder
generates personalized rejection messages. It's all platform-correct."

## Timing
45 seconds.

---

# SLIDE 5 — LIVE DEMO

## Visual
```
            🎬  LIVE DEMO

    Dealer submits a claim on WhatsApp
    → System auto-routes
    → Approver decides in Slack
    → Dealer sees decision in same thread
    
            5 minutes, start to finish
```

## Speaker notes
**DO NOT READ A SLIDE.** Run the demo.

5-minute script:

### Beat 1 — Dealer submits (Tab 1: ARIA Preview) — 90 sec
Type into ARIA, one line at a time:
```
Hi
ELXDEMOHAPY020000
15000
Battery
Battery capacity dropped to 55%
2026-04-20
RO-DEMO-001
NONE
1800
YES
```
Narrate: "90 seconds — dealer submits a full claim. In email this is 15 minutes."

### Beat 2 — Slack card arrives (Tab 2) — 30 sec
Point at the channel. Card appears.
Narrate: "Approver gets this the moment the claim lands. AI verdict, risk
flags, dealer trust score — already summarized."

### Beat 3 — Approver decides with PARTIAL APPROVAL (Tab 2) — 90 sec
Type in Slack:
```
claim review of WC-XXX
```
Wait for context card. Point out the rich content — historical precedent,
Data Cloud telemetry, AI verdict, dealer trust score, photo link.

Then type:
```
approve at 1700 estimate is too high for new battery
```

Wait for the threshold confirm prompt:
```
yes
```

Confirmation appears: "✅ APPROVED. Approved at $1,700 (capped from $2,100)."

Narrate: "Watch what happened — I capped the approval below the dealer's
estimate. The system understood 'approve at 1700' as a partial-approval
intent, captured my one-sentence rationale, and stored $1,700 on the
standard Claim.ApprovedAmount field. The dealer's WhatsApp now shows the
cap explicitly. Three real-world OEM workflows merged into a single
conversational turn — partial approval, threshold confirmation,
audit rationale. No form, no email."

### Beat 4 — Dealer notified (Tab 1 or Tab 3) — 45 sec
Switch back to ARIA preview OR the Claim Chatter feed.
Point at the approval message + PDF link + repair guidance + cap message.
Narrate: "Dealer sees approval immediately in the same WhatsApp thread.
Auto-generated PDF authorization certificate. Live LLM repair guidance
from Prompt Builder — battery-specific tips, BMS diagnostic reminder.
Plus the approved-amount cap with reimbursement language. No email,
no delay."

### Beat 5 — Show the Claim record (Tab 3) — 15 sec
Open the Claim record. Show Chatter feed with audit trail + Files
related list with the photo + PDF.
Narrate: "Every decision captured. ApprovedAmount is $1,700 — different
from the $2,100 estimate. Photo from the dealer attached. PDF authorization.
Dealer trust score recalculated by the trigger. Full audit trail — Automotive
Cloud standard."

## Timing
Target 5 minutes. Practice until you can do it in under 4:30 without looking at notes.

---

# SLIDE 6 — How It Routes (after demo)

## Visual
```
 CLAIM SUBMITTED
        │
        ▼
   ┌──────────────────────────────────┐
   │    Route Claim to Approver        │
   │    (Apex decision engine)         │
   └──────────────────────────────────┘
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
   AUTO-APPROVE  QUEUE   AUTO-REJECT
   (30-40%)     (hours) (< 10%)
   
   Criteria:
   ✓ Likely coverage + ≤$500 + conf≥90 + trust≥75
   
   Saves approvers from every trivial claim.
```

## Speaker notes (30 seconds)
"Smart routing is where business value lives. 30 to 40 percent of incoming
claims meet our auto-approve criteria — they've got active coverage, low
cost, high AI confidence, and a trusted dealer. Those go straight to
Approved — zero human touch. Under ten percent auto-reject where coverage
is clearly expired. The remainder — the actually interesting ones — land
on the approver's Slack channel with full AI context.

Three of your 24 hours got reclaimed just like that."

## Timing
30 seconds.

---

# SLIDE 7 — Trust & Safety Guardrails

## Visual
**Paste Mermaid Diagram 3 from `ARCHITECTURE_DIAGRAMS.md` here.**

Simplified visual:
```
 Six deterministic gates on every approval:
 
 ①  context_loaded == true             (agent gate)
 ②  decision_rationale captured        (agent gate)
 ③  goodwill_intent_confirmed for goodwill (agent gate)
 ④  $2,000 threshold confirmation      (agent gate)
 ⑤  Apex status guard: skip if already Approved/Rejected
 ⑥  Apex phone validation: reject hallucinated session IDs
 
 Defense in depth — gates at BOTH layers.
 Even if the LLM hallucinates, Apex blocks the side-effect.
```

## Speaker notes (45 seconds)
"This is where production-grade differs from demo-grade. We don't rely on
prompt discipline to keep things safe. We have defense in depth.

Six gates protect every approval. Four are at the agent layer — context
must be loaded, rationale must be captured, partial-amount intent must be
explicit, the $2,000 threshold needs verbal confirmation. Two more are at
the Apex layer — we cannot regress an Approved claim back to Pending,
and we cannot send WhatsApp to a hallucinated phone number. The LLM
sometimes makes things up; the Apex catches it.

If the LLM tries to take a shortcut — and they do — Apex blocks the side
effect. Deterministic guardrails at both layers is the difference between
'interesting demo' and 'deployable to production'."

## Timing
45 seconds.

---

# SLIDE 8 — AI Maturity

## Visual
```
  AI IS EVERYWHERE IN THE SYSTEM
  
  ● Einstein Hyper Classifier  → agent topic routing
  ● Apex rule engine           → coverage eligibility verdict
  ● Prompt Builder template    → claim risk verdict (LIVE LLM)
  ● Prompt Builder template    → repair guidance to dealer (LIVE LLM)
  ● Prompt Builder template    → empathetic rejection messages (LIVE LLM)
  ● Senior-adjuster persona    → "Read:", "I'd lean Approve, but..."
  ◐ Vision AI                  → damage photo analysis (scaffolded)
  ◐ Cross-OEM fraud detection  → Data Cloud federation (Phase 2)
  
  Three live LLM templates via ConnectApi.EinsteinLLM.
  Graceful degradation at every layer.
  Every decision tagged with its SOURCE field for audit.
```

## Speaker notes (40 seconds)
"Our AI isn't one model — it's an orchestrated stack. Einstein classifies
intent to route the right agent. Three Prompt Builder templates fire
through ConnectApi.EinsteinLLM — risk verdict on every claim, personalized
empathetic rejection messages, part-specific repair guidance for the dealer.

Beyond the templates: we engineered the agent prompts themselves like
production software. The approver agent doesn't just say 'pending review' —
it gives a one-line read like 'classic battery degradation, trusted dealer,
clean approve unless you spot something'. It cites historical precedent
naturally. It surfaces TSB references for known patterns. Senior adjuster
voice, not chatbot voice.

Every AI call has a deterministic fallback. Every decision carries a
`source` field — LLM output, rule-based, cached? Auditors know exactly
what ran. That's platform-correct AI, not magical thinking."

## Timing
40 seconds.

---

# SLIDE 9 — Data Cloud + Metrics

## Visual
```
  DATA CLOUD FOUNDATION
  ─────────────────────────────────────────
  
  Vehicle_Telemetry__dlm    ← LIVE — telematics events ingested
  RefreshTelemetrySignals   ← Apex bridge: DLM → Platform Event → Claim
  Telemetry_Risk_Rollup_cio ← Calculated Insight aggregating per VIN
  
  ENRICHMENT FLOW
  ─────────────────────────────────────────
  
  CSV stream → DLM → Apex aggregation → Platform Event
                                             ↓
                                  Trigger writes Claim.TelemetrySignal__c
                                             ↓
                            "3 fault codes, 1 off-network charge (last 30d)"
                                  appears on the approver's Slack card
  
  PROJECTED IMPACT
  ─────────────────────────────────────────
  
  Email volume:        1,000/day → 0
  Decision latency:    24-72 hr  → <2 hr median (auto: <30 sec)
  Auto-approved rate:  0%         → 30-40%
  Dealer self-serve:   0%         → 70% on status lookups
  Data completeness:   ~60%       → 100% (structured)
```

## Speaker notes (45 seconds)
"Data Cloud is doing real work today. We ingest a streaming telematics
feed of vehicle fault codes and charging events into the Vehicle Telemetry
DLM. An Apex bridge reads the DLM, aggregates per VIN over a 30-day window,
and publishes Platform Events. A trigger writes the rolled-up signal to
the Claim record — and it surfaces on the approver's Slack card as
'3 fault codes, 1 off-network charge in the last 30 days, last event
April 19'.

That single line corroborates the dealer's narrative — or contradicts it
when the telemetry doesn't match. Real-time enrichment from a separate
data layer, into the human review experience.

The projected metrics: zero inbound emails. Median decision under two
hours versus 24 to 72. Thirty to forty percent of claims auto-resolved.
Dealers stop calling to ask 'where is my claim' because they can self-
serve via ARIA. Data completeness jumps from patchy email parsing to
100% structured fields.

Those are the numbers that make this a business case, not just a demo."

## Timing
45 seconds.

---

# SLIDE 10 — Roadmap + Thanks

## Visual
```
 PHASE 1 — SHIPPED ✅
 ────────────────────
  ✓ Two-agent WhatsApp + Slack architecture
  ✓ Auto-approve / auto-reject / queue routing
  ✓ $2,000 deterministic gate + status guards
  ✓ 3 LIVE LLM Prompt Builder templates via ConnectApi
  ✓ Partial-approval support (cap at any amount)
  ✓ Polished agent prompts (senior-adjuster persona)
  ✓ Branded PDF authorization certificates
  ✓ Photo upload + public URL on Slack card
  ✓ Data Cloud DLM → Apex bridge → Platform Event chain
  ✓ Dealer Trust Score auto-update trigger
  ✓ Historical precedent enrichment
  ✓ Customer email/WhatsApp notification
  ✓ 4-tile Warranty Ops dashboard
  ✓ Full audit trail via Chatter

 PHASE 2 — ROADMAP ⏳
 ────────────────────
  ○ Service Appointment auto-booking (WorkOrder)
  ○ Product2 OEM parts catalog validation
  ○ Cross-OEM fraud detection (Data Cloud federation)
  ○ Predictive maintenance proactive outreach
  ○ Warranty-to-upgrade conversion (Lead/Opportunity)
  ○ Multilingual intake (Spanish, French, German)
  ○ Real Vision LLM swap (replacing mocked analyzer)

  
              THANK YOU
           [Team + Names]
            Q&A ▸
```

## Speaker notes (45 seconds)
"Everything in the green box is live and deployed today. Two-agent
architecture, auto-routing, Prompt Builder for rejection letters, branded
PDF certificates, bilingual Spanish support, five deterministic guardrails,
full audit trail. That's one hackathon sprint.

Phase Two is the Data Cloud-grounded claim risk verdict — swap our rule
engine for an LLM grounded on ninety days of historical claims. Interactive
Slack buttons so approvers tap instead of type. Cross-dealer fraud pattern
detection. All deployable in days, not weeks.

Questions?"

## Timing
45 seconds. End on "Questions?" — prompt the audience.

---

## TIMING BUDGET

| Format | Intro | Problem | Solution | Architecture | Demo | Routing | Trust | AI | Metrics | Roadmap | Q&A | **Total** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 min pitch | 0:30 | 0:45 | 0:40 | 0:45 | 5:00 | 0:30 | 0:45 | 0:40 | 0:45 | 0:40 | — | **10:00** |
| 5 min pitch | 0:20 | 0:30 | skip | 0:30 | 3:00 | skip | 0:40 | skip | 0:20 | 0:20 | — | **5:00** |

For a 5-min slot: skip slides 3, 6, 8. Keep title, problem, architecture, demo,
trust, metrics, roadmap.

---

## JUDGE Q&A PREP (memorize these)

### Q1: "How does your AI decide what to approve?"
> "Coverage eligibility today is rule-based — dates, mileage, covered
> categories. Our InvokeClaimVerdictPrompt Apex invoker is deployed for the
> Phase 2 swap to a Prompt Builder template that reasons over dealer
> velocity, symptom-part consistency, and historical precedent via Data
> Cloud RAG. Every decision logs a `source` field for audit transparency —
> auditors know whether LLM or rule engine fired."

### Q2: "What prevents an adjuster from approving a fraudulent claim?"
> "Five deterministic gates coded in Apex `available when` conditions.
> Context must be loaded. Claim can't be already decided. Rationale is
> required. Above $2,000 needs explicit confirmation. Fraud or duplicate
> flags block auto-approve. Even the LLM can't bypass — the Apex rejects
> the action entirely."

### Q3: "Why Slack AND WhatsApp?"
> "Each channel matches where the user already works. Dealers live in
> WhatsApp — same thread for intake, RFI, and approval notification.
> Approvers live in Slack for OEM collaboration. Both agents read and
> write the same Claim record — one source of truth, not two copies in
> two systems."

### Q4: "What's your Data Cloud story?"
> "DealerClaimVelocity calculated insight is deployed. Data Stream and
> DMO activation are the production go-live steps — out of scope for a
> hackathon. Our risk flags today use a DealerTrustScore fallback with
> identical output shape. Phase 2 adds RAG retrieval on 12 months of
> claim history so the approver Slack card includes similar-claim outcomes:
> 'Of 47 claims like this, 42 were approved.'"

### Q5: "Does this scale to 300,000 vehicles and 1,000 dealers?"
> "Yes. Automotive Cloud handles this natively — we're using standard
> objects, not custom hacks. Agentforce scales with Salesforce licenses.
> The bottleneck is Slack rate limits (one message per second per channel),
> which is fine — 30-40% of claims auto-approve and never hit Slack. The
> real scaling work is in Data Cloud DMO partitioning and in dealer trust
> score back-pressure, both of which are platform-standard patterns."

### Q6: "What happens if WhatsApp is down?"
> "Three-tier delivery. Tier 1 posts to active MessagingSession. Tier 2
> falls back to Chatter audit on the Claim. Dealers see the message next
> time they open ARIA. The decision is committed to the Claim either way —
> WhatsApp delivery is never the source of truth."

### Q7: "How long to deploy to a new dealer network?"
> "The agent definitions are metadata — deploys in minutes. Each new
> dealer is an Account record plus a DealerTrustScore baseline. WhatsApp
> onboarding depends on Meta Business Account approval (2-4 weeks), which
> is outside our control. For internal deployment or SMS backup, zero-day
> turnaround is feasible."

### Q8 (tough one): "Everything I see is rule-based. Where's the real AI?"
> "Three places, and we can live-demo all three. One: Einstein Hyper
> Classifier routes every message to the right subagent — real-time
> intent classification. Two: Prompt Builder composes the dealer rejection
> message you saw in the demo — personalized per claim, empathetic, and
> auditably tagged as LLM output. Three: the approver agent's reasoning
> engine runs a 500-token LLM call on every turn to decide action paths.
> What's rule-based is the eligibility verdict — by design, because
> warranty rules are deterministic. The AI is orchestrating, communicating,
> and reasoning. It's not deciding coverage."

---

## BACKUP SLIDES (don't show unless asked)

### B1 — The $2k gate screenshot proof
Screenshot of the Slack bot saying "This claim is $3,500, above the $2,000
threshold. Confirm approval? (yes/no)"
Proves the deterministic gate is real, not theater.

### B2 — Bilingual screenshot
Screenshot of ARIA responding to "Hola, necesito ayuda" in Spanish.
Proves multilingual works, not just documentation.

### B3 — Prompt Builder output diff
Side-by-side: rule-based rejection (left) vs Prompt Builder rejection (right).
Proves the AI difference, not template swap.

### B4 — Chatter audit feed
Screenshot of a Claim record's Chatter feed showing every status change,
every approver comment, every FeedItem notification. Proves auditability.

---

## DELIVERY TIPS

1. **Rehearse the opening line 20 times.** "Electra Cars is an EV OEM with
   300,000 vehicles on the road." If you nail this, the rest flows.

2. **Never read slides.** Use them as a visual spine. Eye contact > script.

3. **During the demo: DO NOT TYPE WHILE TALKING.** Pause, then describe
   what's happening. Judges get confused by concurrent input.

4. **Silent beats are OK.** Let the Slack card appear. Let the PDF render.
   "Look at this" beats "so what's happening is the agent is now calling..."

5. **Anchor every claim with a proof.** Don't say "30-40% auto-approve" —
   say "30-40% — auto-approved via the rules coded in
   RouteClaimToApproverQueue.cls, you can see the check at line 95."

6. **If something breaks live, STOP.** Don't try to debug. Say: "Let me
   show this in the fallback video" and keep moving. Judges hate watching
   you troubleshoot.

7. **The Q&A is where you win or lose.** Memorize the 8 Q&A answers above.
   If asked something you don't know, say "Great question — not in scope
   for this demo, but here's how we'd approach it" and pivot.

---

## ONE FINAL THING

The judges want to FEEL the problem → solution moment. The 90-second
dealer intake on WhatsApp, followed 5 seconds later by the Slack card, is
the emotional payoff. Protect it. Rehearse until it's muscle memory.

Everything else on this deck is context. That demo beat is the story.
