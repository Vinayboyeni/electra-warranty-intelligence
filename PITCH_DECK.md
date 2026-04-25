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

### Beat 3 — Approver decides (Tab 2) — 90 sec
Type in Slack:
```
@Electra Warranty Approver WC-XXX
```
Wait for context card.
```
approve
```
Wait for rationale prompt.
```
Battery degradation confirmed per TSB-2025-03
```
Narrate: "Watch for the confirmation. Because this claim is above $1,500,
a $2,000 unilateral confirmation is NOT triggered — but if it were $3,000,
the agent would ask me to confirm. That's coded in Apex, not prompt
discipline."

Confirmation appears: "✅ APPROVED."

### Beat 4 — Dealer notified (Tab 1 or Tab 3) — 45 sec
Switch back to ARIA preview OR the Claim Chatter feed.
Point at the approval message + PDF link.
Narrate: "Dealer sees approval immediately in the same WhatsApp thread.
Auto-generated PDF authorization certificate attached — with verification
code and QR to the claim record. No email, no delay."

### Beat 5 — Show the Claim record (Tab 3) — 15 sec
Open the Claim record. Show Chatter feed with audit trail.
Narrate: "Every decision captured. Adjuster rationale, AI verdict, Slack
thread reference. Full audit trail — Automotive Cloud standard."

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
 Five deterministic gates on every approval:
 
 ①  context_loaded == true
 ②  claim_status ≠ Approved/Rejected
 ③  decision_rationale captured
 ④  cost ≤ $2,000 OR explicit confirmation
 ⑤  risk_flags clear of fraud/duplicate/velocity
 
 All enforced in Apex available_when conditions.
 Even the LLM can't override them.
```

## Speaker notes (45 seconds)
"This is where production-grade differs from demo-grade. We don't rely on
prompt discipline to keep things safe. We rely on Apex.

Every approve action has five `available when` gates coded into the agent.
The $2,000 threshold is a boolean variable the approver must explicitly
confirm. Can't re-approve a closed claim. Can't skip the rationale — it's
required for audit. If a risk flag is up, the agent refuses to auto-approve
and recommends clarification.

If the LLM tries to take a shortcut — which they do — the Apex blocks the
action entirely. Deterministic guardrails are the difference between
'interesting demo' and 'deployable to production'."

## Timing
45 seconds.

---

# SLIDE 8 — AI Maturity

## Visual
```
  AI IS EVERYWHERE IN THE SYSTEM
  
  ○ Einstein Hyper Classifier → agent routing
  ○ Apex rule engine         → eligibility verdict (today)
  ● Prompt Builder           → dealer rejection letter (LIVE)
  ◐ Prompt Builder           → claim risk verdict (Phase 2)
  ◐ Data Cloud RAG           → similar-claim precedent (Phase 2)
  ◐ Vision AI                → damage photo analysis (scaffolded)
  
  Graceful degradation at every layer.
  Every decision tagged with its SOURCE for audit.
```

## Speaker notes (40 seconds)
"Our AI isn't one model — it's an orchestrated stack. Einstein classifies
intent to route the right agent. A rule-based engine handles coverage
eligibility. Prompt Builder composes personalized empathetic WhatsApp
rejection messages — that was live in the demo. The same pattern is
scaffolded for claim risk verdicts and RAG over historical claim data
for Phase 2.

Every AI call has a fallback. Every decision carries a `source` field —
was this LLM output, rule-based, or cached? Auditors know exactly what ran.
That's platform-correct AI, not magical thinking."

## Timing
40 seconds.

---

# SLIDE 9 — Data Cloud + Metrics

## Visual
```
  DATA CLOUD FOUNDATION
  ─────────────────────────────────────────
  
  Claim__dlm                ← live
  DealerClaimVelocity       ← deployed, populate Phase 2
  PartFailureRate__dlm      ← Phase 2
  DealerPerformance__dlm    ← Phase 2
  
  → feeds approver risk flags
  → feeds RAG claim precedent
  → feeds fraud pattern detection
  
  PROJECTED IMPACT
  ─────────────────────────────────────────
  
  Email volume:        1,000/day → 0
  Decision latency:    24-72 hr  → <2 hr median
  Auto-approved rate:  0%         → 30-40%
  Dealer self-serve:   0%         → 70% on status lookups
  Data completeness:   ~60%       → 100% (structured)
```

## Speaker notes (45 seconds)
"Data Cloud is the memory layer that makes the AI smart. Our
DealerClaimVelocity calculated insight is deployed. Data Stream activation
is the production go-live step — for the hackathon we use a fallback risk
flag from DealerTrustScore. Same output shape, ready to swap.

The projected metrics: zero inbound emails. Median decision under two
hours versus 24 to 72. Thirty to forty percent of claims auto-resolved.
Dealers stop calling to ask 'where is my claim' because they can self-
serve the status. Data completeness jumps from patchy email parsing to
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
  ✓ Auto-approve / auto-reject routing
  ✓ $2,000 deterministic gate
  ✓ Prompt Builder rejection letters
  ✓ Branded PDF authorization certificates
  ✓ Bilingual dealer intake (en / es)
  ✓ 97-field Automotive Cloud claim model
  ✓ Full audit trail via Chatter


 PHASE 2 — ARCHITECTED ⏳
 ────────────────────
  ○ Prompt Builder claim risk verdict
  ○ Data Cloud full DMO activation
  ○ RAG on historical claims
  ○ Interactive Slack buttons (Block Kit)
  ○ Vehicle Service History DMO

  
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
