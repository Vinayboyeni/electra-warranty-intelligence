# Electra Cars Warranty Claim Agent — Architecture Diagrams

Two Mermaid diagrams for your pitch deck and documentation. Render natively in
GitHub README, Notion, Confluence, and most modern Markdown viewers. To export
as PNG for slides, use [mermaid.live](https://mermaid.live) — paste the code,
download as SVG or PNG.

---

## Diagram 1 — System Architecture (one-slide overview)

```mermaid
flowchart TB
    subgraph Personas["👥 PERSONAS"]
        Dealer["🧑‍🔧 Dealership<br/>Service Advisor"]
        Approver["👨‍💼 OEM Warranty<br/>Approver"]
        Policy["👑 Warranty Policy<br/>Manager"]
    end

    subgraph Channels["📱 CHANNELS"]
        WA["WhatsApp<br/>(Digital Engagement)"]
        Slack["Slack<br/>(Slack for Salesforce)"]
    end

    subgraph Agentforce["🤖 AGENTFORCE LAYER"]
        ARIA["ARIA<br/>Warranty_Dealer_Intake_Agentt_4<br/>AgentforceServiceAgent<br/>7 subagents · 11-step flow"]
        Approv["Warranty_Approver_Agent_3<br/>AgentforceEmployeeAgent<br/>6 subagents · 4 decision paths"]
    end

    subgraph AutoCloud["🗄️ AUTOMOTIVE CLOUD (System of Record)"]
        direction LR
        Claim["Claim (97 fields)<br/>Record Types:<br/>• Prior Authorization<br/>• Post Repair<br/>• Goodwill Exception"]
        Veh["Vehicle"]
        Asset["Asset"]
        AW["AssetWarranty"]
        Acct["Account (Dealer)<br/>+ DealerTrustScore__c"]
        MS["MessagingSession<br/>MessagingEndUser"]
        FI["FeedItem<br/>(Audit Trail)"]
        SRT["SRTMatrix__c<br/>(10 baselines)"]
    end

    subgraph Automation["⚙️ AUTOMATION & LOGIC"]
        direction LR
        CreateFlow["Action_Create_Warranty_Claim<br/>(Flow)"]
        CovEng["CoverageEngine<br/>(Apex)"]
        RouteQ["RouteClaimToApproverQueue<br/>(Apex — auto-approve/reject logic)"]
        SlackFlow["Slack_Notify_Approver_Flow<br/>(Record-triggered)"]
        SRTVal["ValidateRepairEstimate<br/>(±20% SRT check)"]
    end

    subgraph AI["🧠 AI LAYER"]
        EinsteinRouter["Einstein<br/>Hyper Classifier<br/>(agent routing)"]
        Prompt["Prompt Builder<br/>Claim_Risk_Verdict<br/>(Phase 2 — scaffolded)"]
        DataCloud["Data Cloud<br/>DealerClaimVelocity<br/>Calculated Insight"]
    end

    subgraph Webhooks["🔔 NOTIFICATIONS"]
        WebhookOut["PostToSlackWebhook<br/>(Named Credential)"]
        WAOut["SendWhatsAppRFINotification<br/>SendWhatsAppClaimDecision"]
    end

    Dealer --> WA
    Approver --> Slack
    WA <-.-> ARIA
    Slack <-.-> Approv

    ARIA --> CreateFlow
    ARIA --> CovEng
    ARIA --> SRTVal
    Approv --> Claim

    CreateFlow --> Claim
    CreateFlow --> RouteQ
    RouteQ -- "auto-approve<br/>(Likely + ≤$500 + conf≥90 + trust≥75)" --> Claim
    RouteQ -- "auto-reject<br/>(Not Covered)" --> Claim
    RouteQ -- "queue for review" --> Claim
    Claim -- "Status = Pending Approver Review" --> SlackFlow
    SlackFlow --> WebhookOut
    WebhookOut --> Slack

    Approv -- "Approve/Reject/Clarify" --> Claim
    Approv --> WAOut
    WAOut --> WA

    EinsteinRouter -.routes.-> ARIA
    EinsteinRouter -.routes.-> Approv
    Prompt -.future verdict.-> Claim
    DataCloud -.risk flags.-> Approv

    Claim --- Veh
    Claim --- Asset
    Asset --- AW
    Claim --- Acct
    Claim --- FI
    SRTVal --- SRT

    Policy -.escalation.-> Approv

    classDef persona fill:#E8F4FD,stroke:#0B5394,stroke-width:2px,color:#000
    classDef channel fill:#FFF2CC,stroke:#BF9000,stroke-width:2px,color:#000
    classDef agent fill:#D9EAD3,stroke:#38761D,stroke-width:3px,color:#000
    classDef data fill:#FCE5CD,stroke:#B45F06,stroke-width:2px,color:#000
    classDef logic fill:#D9D2E9,stroke:#674EA7,stroke-width:2px,color:#000
    classDef ai fill:#F4CCCC,stroke:#990000,stroke-width:2px,color:#000
    classDef notif fill:#CFE2F3,stroke:#1155CC,stroke-width:2px,color:#000

    class Dealer,Approver,Policy persona
    class WA,Slack channel
    class ARIA,Approv agent
    class Claim,Veh,Asset,AW,Acct,MS,FI,SRT data
    class CreateFlow,CovEng,RouteQ,SlackFlow,SRTVal logic
    class EinsteinRouter,Prompt,DataCloud ai
    class WebhookOut,WAOut notif
```

---

## Diagram 2 — Happy Path Sequence (demo slide)

```mermaid
sequenceDiagram
    autonumber
    participant D as 🧑‍🔧 Dealer (WhatsApp)
    participant A as 🤖 ARIA Agent
    participant SF as 🗄️ Automotive Cloud
    participant Route as ⚙️ RouteClaim<br/>ToApproverQueue
    participant H as 🔔 Slack Channel
    participant Appr as 🤖 Approver Agent
    participant OEM as 👨‍💼 Approver

    D->>A: "Hi" + VIN + symptoms + amount
    A->>SF: FindVehicleByVin, CheckRecentClaims
    A->>SF: EvaluateCoverage + ValidateRepairEstimate
    A->>D: Claim summary — confirm YES?
    D->>A: YES

    A->>SF: Create Claim (Status=Submitted)
    SF->>Route: Action_Route_Claim_to_Queue

    alt Likely + ≤$500 + conf≥90 + trust≥75
        Route->>SF: Status = Approved (auto)
        SF->>D: ✅ Auto-approved
    else Not Covered
        Route->>SF: Status = Rejected (auto)
        SF->>D: ❌ Rejected + goodwill option
    else Everything else
        Route->>SF: Status = Pending Approver Review
        SF->>H: 🔔 Slack card via webhook
        H-->>OEM: See notification with claim details

        OEM->>Appr: @Approver WC-XXXXX
        Appr->>SF: GetWarrantyClaimApprovalContext
        Appr-->>OEM: Show full claim card

        OEM->>Appr: "approve" + rationale
        Note over Appr: Golden Rule:<br/>set_variable + tool call<br/>+ confirmation ALL IN<br/>SAME TURN
        Appr->>SF: ApproveWarrantyClaim<br/>(writes DecisionRationale)
        SF-->>Appr: Status = Approved
        Appr-->>OEM: ✅ APPROVED confirmation
        SF->>D: ✅ Dealer notified via WhatsApp<br/>(same thread)
    end

    Note over D,OEM: One Claim record, one conversation,<br/>bidirectional lifecycle
```

---

## Diagram 3 — Deterministic Guardrails (defense-in-depth)

```mermaid
flowchart LR
    Start([Adjuster says<br/>'approve WC-XXX'])
    Gate1{context_loaded<br/>== True?}
    Gate2{claim_status<br/>≠ Approved<br/>≠ Rejected?}
    Gate3{decision_rationale<br/>captured?}
    Gate4{cost ≤ $2,000<br/>OR<br/>confirmed_above<br/>_threshold?}
    Gate5{risk_flags lack<br/>fraud/duplicate/<br/>velocity anomaly?}
    Action[ApproveWarrantyClaim<br/>Apex fires]
    Reject[Rejected by gate]

    Start --> Gate1
    Gate1 -- No: load context first --> Reject
    Gate1 -- Yes --> Gate2
    Gate2 -- No: already decided --> Reject
    Gate2 -- Yes --> Gate3
    Gate3 -- No: prompt for rationale --> Reject
    Gate3 -- Yes --> Gate4
    Gate4 -- No: prompt for explicit confirmation --> Reject
    Gate4 -- Yes --> Gate5
    Gate5 -- No: route to RFI or Escalation --> Reject
    Gate5 -- Yes --> Action

    classDef gate fill:#FFF2CC,stroke:#BF9000,stroke-width:2px,color:#000
    classDef action fill:#D9EAD3,stroke:#38761D,stroke-width:3px,color:#000
    classDef reject fill:#F4CCCC,stroke:#990000,stroke-width:2px,color:#000

    class Gate1,Gate2,Gate3,Gate4,Gate5 gate
    class Action action
    class Reject reject
```

---

## How To Use These in Your Pitch Deck

### Slide 3 (Architecture Overview)
- Paste Diagram 1
- Talking track: *"Two agents, three channels, one Claim record as source of truth. Automotive Cloud as system of record, Agentforce for conversational AI, standard Slack-for-Salesforce bridge for OEM review, Digital Engagement for dealer WhatsApp. No custom middleware."*

### Slide 5 or 6 (Demo Replay Slide)
- Paste Diagram 2 (sequence)
- Talking track: *"Here's what just happened in the demo — claim submitted, evaluated, auto-routed, approved, dealer notified. Every step captures rationale for audit. End-to-end in under 2 minutes."*

### Slide 7 (Trust & Safety)
- Paste Diagram 3
- Talking track: *"Five `available when` gates in Apex, not prompt discipline. Even the AI can't override the $2,000 threshold, can't re-approve a decided claim, can't skip the fraud check. Deterministic guardrails are the difference between hackathon demo and production-ready."*

---

## To Export As Images

1. Go to https://mermaid.live
2. Paste any diagram block (without the ```` ```mermaid ```` fence)
3. **Export** → PNG or SVG
4. Drop into your slide

Or using mermaid-cli:
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i diagram.mmd -o diagram.png -b transparent -w 2400 -H 1800
```
