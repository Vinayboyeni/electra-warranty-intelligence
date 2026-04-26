# 📊 Slides — Paste-Ready Content

**Drop each block into a separate slide in Pitch.com, Google Slides, or Canva.**

Each slide has:
- **Title** (paste into slide title)
- **Body** (paste into main content area)
- **Visual hint** (what image / diagram to add)

No speaker notes here — those are in `PITCH_DECK.md`. This file is purely for slide layout.

---

## SLIDE 1 — Title

**Title:**
> Electra Warranty Intelligence

**Body (large, centered):**
> AI-driven warranty prior-authorization for EV OEMs
>
> *Two agents · Three channels · One record*

**Footer:**
> [Your Name] · [Team Name] · Salesforce Automotive Cloud Hackathon · April 2026

**Visual:** Big bold electric-blue title block. Background: gradient or single accent photo of EV charging or service bay.

---

## SLIDE 2 — The Problem

**Title:**
> Email is killing OEM warranty operations

**Body:**
| | |
|---|---|
| **300,000** | vehicles in service |
| **1,000+** | warranty claims submitted **per day** |
| **3** | OEM approvers handling them all |
| **24-72 hrs** | average decision latency |
| **0%** | structured field capture (everything in email body) |

**Visual:** Stack of paper / overflowing inbox icon · or stark counter graphic with the numbers.

---

## SLIDE 3 — The Solution

**Title:**
> Replace email with two AI agents and one structured record

**Body:**
- 📱 **ARIA** (WhatsApp/Web) — dealer-facing intake agent
- 💼 **Approver Agent** (Slack) — adjuster's right-hand decision support
- 🗂️ **One Claim record** in Automotive Cloud — single source of truth
- ⚙️ **Auto-routing** handles 30-40% of claims with zero human touch
- 🛡️ **Deterministic guardrails** at agent + Apex layers

**Visual:** Three-channel diagram (WhatsApp ↔ Slack ↔ Salesforce) with arrows pointing inward to a Claim record icon.

---

## SLIDE 4 — Architecture

**Title:**
> One platform · five Salesforce technologies

**Body:** *(replace with the rendered Mermaid diagram)*

```
DEALER (WhatsApp) ──▶ ARIA Agent ──▶ Claim Record ──▶ Coverage Engine + AI Verdict
                                              │
                                       Routing Apex
                              ┌───────────────┼───────────────┐
                              ▼               ▼               ▼
                        Auto-approve        Queue        Auto-reject
                        (PDF + WhatsApp)      │      (empathetic LLM)
                                              ▼
                                       Slack Approver Agent
                                              │
                                       approve / reject /
                                       clarify / goodwill
                                              │
                                              ▼
                            PDF · Dealer WhatsApp · Customer notification
                                Repair guidance · Trust score recalc
```

**Visual:** Mermaid → mermaid.live → export PNG. Or use the ASCII above as a placeholder.

**Footer text:**
> Automotive Cloud · Agentforce · Data Cloud · Prompt Builder · Digital Engagement

---

## SLIDE 5 — LIVE DEMO (placeholder slide)

**Title:**
> 🎬 Live Demo

**Body (centered, large):**
> Dealer submits a claim on WhatsApp
> → System auto-routes
> → Approver decides in Slack with partial approval
> → Dealer + customer notified instantly
>
> **5 minutes start to finish**

**Visual:** Single full-bleed screenshot of the rich Slack approver card. Optional play-button overlay.

---

## SLIDE 6 — Auto-Routing

**Title:**
> Smart routing reclaims 40% of approver capacity

**Body:**

| Path | Trigger | Outcome | Human touch |
|---|---|---|---|
| **Auto-approve** | Likely + ≤$500 + AI conf ≥ 90% + dealer trust ≥ 75 | Approved · PDF + WhatsApp in 30s | None |
| **Auto-reject** | Eligibility = Not Covered | Rejected · empathetic LLM message | None |
| **Queue** | Anything else | Slack card with full context | One adjuster |

**Footer:**
> Three approvers can now handle the load that previously required ten.

**Visual:** Three-pipe funnel showing % distribution. Color-code: green / red / yellow.

---

## SLIDE 7 — Trust & Safety

**Title:**
> Production-grade guardrails — at both agent AND Apex layers

**Body:**

```
AGENT-LAYER GATES
①  context_loaded == true
②  decision_rationale captured
③  goodwill_intent_confirmed (Goodwill only)
④  $2,000 threshold yes/no confirmation

APEX-LAYER GATES
⑤  Skip if claim is already Approved or Rejected
⑥  Reject hallucinated phone numbers in dealer field
```

**Footer:**
> When the LLM hallucinates, Apex catches it. Defense in depth.

**Visual:** Six-shield diagram in two rows (agent / apex). Or simple red+green "blocked / allowed" diagram.

---

## SLIDE 8 — AI Maturity

**Title:**
> Live LLM, deterministic fallbacks, every layer

**Body:**

```
● Einstein Hyper Classifier   → agent topic routing
● Coverage Apex rule engine   → eligibility verdict
● Prompt Builder template     → claim risk verdict (LIVE LLM)
● Prompt Builder template     → repair guidance to dealer (LIVE LLM)
● Prompt Builder template     → empathetic rejection messages (LIVE LLM)
● Senior-adjuster persona     → "Read:", "I'd lean Approve, but..."
◐ Vision AI                   → damage photo analysis (scaffolded)
◐ Cross-OEM fraud detection   → Data Cloud federation (Phase 2)
```

**Footer:**
> Three live templates via `ConnectApi.EinsteinLLM`. Every decision tagged with its source.

**Visual:** Stack diagram with filled vs hollow circles indicating maturity. Or icon row: Einstein + Apex + Prompt Builder + Vision + RAG.

---

## SLIDE 9 — Data Cloud + Metrics

**Title:**
> Data Cloud feeds the approver in real time

**Body (top half):**

```
CSV stream → Vehicle_Telemetry__dlm
            → RefreshTelemetrySignals (Apex bridge)
            → TelemetrySignal__e (Platform Event)
            → Trigger writes Claim.TelemetrySignal__c
            → "3 fault codes, 1 off-network charge (last 30d)"
              appears on the approver Slack card
```

**Body (bottom half — projected impact):**

| Metric | Before | After |
|---|---|---|
| Email volume | 1,000/day | 0 |
| Decision latency | 24-72 hr | < 2 hr median (auto: < 30 sec) |
| Auto-approved rate | 0% | 30-40% |
| Dealer self-service | 0% | 70% on status lookups |
| Data completeness | ~60% (parsed email) | 100% (structured) |

**Visual:** Dashboard screenshot of your Warranty Ops Command Center. Or split: left = data flow diagram, right = before/after numbers.

---

## SLIDE 10 — Roadmap + Close

**Title:**
> Shipped today · roadmap tomorrow

**Body — left column (SHIPPED):**

```
✅ Two-agent WhatsApp + Slack architecture
✅ Auto-routing (approve / reject / queue)
✅ 3 LIVE Prompt Builder templates
✅ Partial-approval support
✅ Polished agent prompts (senior-adjuster persona)
✅ Branded PDF authorization
✅ Photo upload + public URL on Slack card
✅ Data Cloud DLM → Platform Event chain
✅ Dealer Trust Score auto-update
✅ Historical precedent enrichment
✅ Customer + dealer notifications
✅ 4-tile metrics dashboard
```

**Body — right column (NEXT):**

```
⏳ Service Appointment auto-booking
⏳ Product2 OEM parts catalog
⏳ Cross-OEM fraud detection
⏳ Predictive maintenance outreach
⏳ Warranty → trade-in conversion
⏳ Real Vision LLM swap
⏳ Multilingual intake
```

**Bottom (centered, large):**
> **Three approvers, doing the work of ten.**
>
> Thank you. Questions?

**Visual:** Two-column layout. Subtle thumbs-up / arrow-forward icons.

---

## DESIGN PRINCIPLES

- **Color palette:** Salesforce blue `#0B5394` for primary, white background, dark gray text. Optional accent: green `#16B26B` for approved / red `#D7263D` for rejected.
- **Typography:** Sans-serif (Inter, SF Pro, or platform default). Large headlines (32-48pt), readable body (18-22pt).
- **One concept per slide.** Resist the urge to combine.
- **Numbers in big bold type.** "1,000+" should be 60-80pt.
- **Screenshots beat diagrams** when you can show real output.

## RECOMMENDED TOOLS

| Tool | Why use |
|---|---|
| [Pitch.com](https://pitch.com) | Modern templates, fast to polish, free tier works |
| [Google Slides](https://slides.google.com) | Familiar, easy share with judges |
| [Canva](https://canva.com) | If you want extra visual polish |
| [mermaid.live](https://mermaid.live) | Render the architecture diagrams as PNG |

## PRE-EXPORT CHECKLIST

- [ ] Replace `[Your Name]` and `[Team Name]` on slide 1
- [ ] Replace `[Team + Names]` on slide 10
- [ ] Insert architecture PNG on slide 4 (from `ARCHITECTURE_DIAGRAMS.md` via mermaid.live)
- [ ] Insert real Slack approver card screenshot on slide 5
- [ ] Insert real dashboard screenshot on slide 9
- [ ] Verify deck reads cleanly without your narration (a slide should make sense if a judge reviews it offline)
