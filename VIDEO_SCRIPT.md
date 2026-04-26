# 🎬 5-Minute Video Script — Electra Warranty Intelligence

**Total target: 4:50 (gives 10s buffer for the 5:00 limit)**

Read aloud at a comfortable pace. Pauses for visuals are marked `[…wait…]`.
Word counts are calibrated for ~150 wpm — about average for a confident pitch.

---

## PRE-RECORDING CHECKLIST

- [ ] Run pre-flight: `sf apex run -f scripts/apex/seed_demo_telemetry.apex`
- [ ] Pre-create one Pending claim for the approver beat (pick a $2,100 Battery claim)
- [ ] 4 browser windows arranged side-by-side or quick-switchable:
  - Window 1: ARIA preview / WhatsApp web
  - Window 2: Slack channel `#all-electra-cars-approvers`
  - Window 3: Salesforce — Claim record (open one in advance for closing shot)
  - Window 4: Warranty Ops Command Center dashboard
- [ ] OBS or Camtasia configured at 1080p, audio levels checked
- [ ] Phone on Do Not Disturb · door closed · water bottle nearby

---

## SCRIPT

### 0:00 — 0:25 — Hook (the problem)

**Visual:** Slide 1 (title) → Slide 2 (the problem with bold numbers).

**Voiceover:**
> "Electra Cars is an EV OEM with three hundred thousand vehicles in service. Their dealer network submits over a thousand warranty prior-authorization requests every single day — through email. Three OEM approvers handle that entire queue. Decisions take 24 to 72 hours. We replaced this with an AI-driven system that decides 40 percent of claims in under 30 seconds. Let me show you."

**Word count:** ~70 words · runs ~28 seconds at moderate pace.

---

### 0:25 — 1:10 — Dealer intake (ARIA on WhatsApp)

**Visual:** Switch to Window 1 — ARIA preview / WhatsApp.

**Type into ARIA:**
```
Hi
ELXX3E23000000001
12555
Battery
not charging
2300
yes
```

Wait for each ARIA response between inputs.

**Voiceover (over the conversation):**
> "A dealer opens WhatsApp. Our intake agent — ARIA — collects the VIN, odometer, part category, symptom, and cost in five conversational turns. Notice the BMS diagnostic suggestion when the dealer says 'not charging' on a low-mileage battery. That's not a script — that's the agent's automotive expertise prompt firing on a known pattern.
>
> Confirmation submitted. Claim number `WC-XXX` is now a structured record in Automotive Cloud."

**Word count:** ~75 words.

---

### 1:10 — 1:40 — Auto-routing decision (silent demo of speed)

**Visual:** Switch to Window 3 (Salesforce Claim record).

Show the new claim with all fields populated:
- Status: Pending Approver Review
- Eligibility: Likely
- AI_Recommendation: Approve / 90% confidence
- Auto_Approved: false (because cost > $500)

**Voiceover:**
> "The moment that claim is created, three things fire automatically. The Coverage Engine queries AssetWarranty. The Claim Risk Verdict prompt template runs the LLM via ConnectApi. The routing layer decides — auto-approve, auto-reject, or queue for human review. This claim is a $2,300 battery — high cost, so it queues for an adjuster."

**Word count:** ~65 words.

---

### 1:40 — 3:10 — The approver flow (the killer demo — partial approval)

**Visual:** Switch to Window 2 (Slack `#all-electra-cars-approvers`).

The card has appeared. Highlight the rich content with the cursor:
- AI Verdict: Approve / 92% (LLM-derived)
- Eligibility: Likely
- Historical precedent: "Of 12 similar claims, 9 were approved"
- Vehicle telemetry (Data Cloud): "3 fault codes, 1 off-network charge (last 30d)"
- Dealer Trust Score: 85
- Photo link

**Voiceover:**
> "The approver gets this Slack card the instant the claim queues. Look at the enrichment — historical precedent, dealer trust score, and a Data Cloud telemetry signal showing fault codes that appeared a week before this claim was filed. That corroborates the dealer's story without the approver leaving Slack."

**Now type in Slack:**
```
@Electra Cars Warranty Approver Agent approve at 1700 estimate too high for new battery
```

Wait for threshold confirm prompt.

```
yes
```

**Voiceover:**
> "I'm capping this at seventeen hundred — below the dealer's twenty-three hundred estimate. Watch — the agent recognized the partial-approval intent, captured my rationale, prompted the threshold confirmation because we're above two thousand, and approved. The dealer's WhatsApp now shows the cap explicitly."

**Word count:** ~95 words. This is the longest beat — the killer differentiator.

---

### 3:10 — 3:50 — The decision propagates (closing the loop)

**Visual:** Switch to Window 1 (WhatsApp, dealer side).

Dealer received: ✅ APPROVED message + PDF authorization link + repair guidance + cap message.

**Voiceover:**
> "Dealer sees this in the same WhatsApp thread within seconds. Approval message, branded PDF authorization certificate with verification code, AI-generated repair guidance specific to a battery diagnostic — that's a third Prompt Builder template firing live. And the approved-amount cap. The customer — the actual vehicle owner — also gets a separate WhatsApp message."

**Visual:** Switch to Window 3 (Claim record).

Show:
- Status: Approved
- ApprovedAmount: $1,700 (different from EstimatedCost: $2,300)
- DecisionRationale captured
- Files: PDF + dealer photo
- Chatter: full audit trail

**Voiceover (continuing):**
> "Here's the Claim record. ApprovedAmount captured as a separate field — seventeen hundred — distinct from the dealer's twenty-three hundred ask. Decision rationale captured. PDF and photo attached. Dealer trust score recalculated by the trigger. Full audit trail — Automotive Cloud standard."

**Word count:** ~95 words.

---

### 3:50 — 4:20 — Resilience and architecture punch

**Visual:** Switch to Slide 7 (guardrails) and Slide 8 (AI maturity) — show together if possible.

**Voiceover:**
> "Production resilience — every Prompt Builder template has a deterministic fallback. Every WhatsApp delivery has a Chatter audit. Every async dependency is wrapped — Data Cloud could be down and our approvals still ship. We engineered six guardrails across the agent and Apex layers. When the LLM tries to take a shortcut, Apex catches it. That's the difference between 'interesting demo' and 'deployable to production'."

**Word count:** ~75 words.

---

### 4:20 — 4:45 — Impact and close

**Visual:** Switch to Window 4 — Warranty Ops Command Center dashboard.

Show:
- Today's auto-approved count
- Queue depth
- Median decision time
- Approval rate by dealer

**Voiceover:**
> "The Warranty Ops dashboard tracks all of this live. Auto-approval rate, queue depth, median decision time, per-dealer approval rate. The numbers tell the story — our three approvers can now handle the load that previously required ten."

**Visual:** Switch to Slide 10 (roadmap + close).

**Voiceover:**
> "Three Salesforce technologies working together: Automotive Cloud holds the data. Agentforce holds the conversation. Data Cloud holds the signal. Thank you."

**Word count:** ~60 words.

---

## TIMING SUMMARY

| Segment | Time | Words | Notes |
|---|---|---|---|
| Hook | 0:00 — 0:25 | 70 | Strong open |
| Intake | 0:25 — 1:10 | 75 | Live ARIA |
| Auto-route | 1:10 — 1:40 | 65 | Show structured record |
| Approver flow | 1:40 — 3:10 | 95 | **Killer demo — partial approval** |
| Decision propagates | 3:10 — 3:50 | 95 | Three-channel close |
| Resilience | 3:50 — 4:20 | 75 | Engineering depth |
| Impact + close | 4:20 — 4:45 | 60 | Dashboard + thank you |
| **TOTAL** | **4:45** | **535** | 15s buffer to 5:00 limit |

## RECORDING TIPS

1. **Stand up.** Voice projects better.
2. **Two takes minimum.** First take is always tighter than you think it is.
3. **Practice the demo cold once.** Submit, approve, observe, end-to-end without help. If you fumble, redo.
4. **Cut every dead second** in post — every "um", every wait-for-screen, every transition gap.
5. **Record at 1080p, 30fps.** Anything more is overkill; anything less looks unpolished.
6. **Add captions in post.** Camtasia auto-generates them. Many judges watch on mute.
7. **End on a beat.** The line "doing the work of ten" is your closer. Pause after it before cutting.

## FALLBACK PLAN

If a live demo fails during recording (LLM down, Slack lag, WhatsApp issue):

1. **Skip the partial-approval beat** — record just the auto-approve path which is more deterministic
2. **Use pre-recorded screen captures** intercut with your voiceover as cover
3. **Lean on the Slack card screenshot** + dashboard screenshot rather than live navigation
4. **Time check after each beat** — if you're behind, cut Slide 7 or 8 narration short

The system will work most of the time. The fallback plan is insurance, not the plan.

## ONE-LINE PUNCHLINE (memorize this)

> "Three approvers, doing the work of ten."

Use it once at the close. Don't dilute it by saying it earlier.

---

**Good luck. You've shipped the system. Now go tell the story.**
