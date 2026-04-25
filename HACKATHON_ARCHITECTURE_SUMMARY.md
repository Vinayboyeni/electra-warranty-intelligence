# Electra Cars Warranty Hackathon Architecture

This document provides a comprehensive list of the Salesforce objects, custom fields, agents, and declarative actions used in the Electra Cars Warranty Prior-Authorization system.

## 1. Objects and Fields

### Core Automotive Cloud Objects
| Object | Fields Used | Purpose |
| :--- | :--- | :--- |
| **Claim** | `Status__c`, `EstimatedCost__c`, `PartCategory__c`, `Symptom__c`, `AI_Recommendation__c`, `Eligibility__c`, `Priority__c`, `SubmissionChannel__c`, `ApproverSlackRef__c` | Stores the primary warranty request and AI evaluation results. |
| **Vehicle** | `Current_Mileage__c`, `LastOdometerReading`, `ModelName`, `ModelYear` | Stores vehicle identity and odometer history for coverage checking. |
| **AssetWarranty** | `CoveredCategories__c`, `MileageCap__c`, `EndDate` | Defines the specific coverage terms for a vehicle/part combination. |
| **Asset** | `Name`, `AccountId`, `ContactId` | Links the individual vehicle to the Customer and Dealership. |

### Relationship & Identity Objects
| Object | Fields Used | Purpose |
| :--- | :--- | :--- |
| **Account** | `DealerWhatsAppNumber__c`, `DealerTrustScore__c` | Represents the dealership and its verified contact number. |
| **Contact** | `FirstName`, `LastName`, `Email` | Represents the vehicle owner (Customer). |
| **MessagingSession** | `MessagingEndUserId`, `Status` | Manages the live WhatsApp session context. |

---

## 2. Agentforce Agents

### 🤖 Dealer Intake Agent (ARIA)
*   **Persona**: Authorized Repair Intelligence Assistant.
*   **Channel**: WhatsApp.
*   **Goal**: Guides service advisors through VIN lookup, data gathering, coverage evaluation, and claim submission.

### 🤖 Warranty Approver Agent
*   **Persona**: Backend OEM Adjuster.
*   **Channel**: Slack / Internal Console.
*   **Goal**: Assists human adjusters by summarizing claims, analyzing photos, and facilitating clarification requests to dealers.

---

## 3. Declarative Actions (Flow-Based)

These actions represent the "brain" of the agents, recently migrated from legacy Apex to 100% declarative Flows.

### 🚗 Intake Actions
1.  **Action_Find_Vehicle_By_VIN**: Look up vehicle and active warranty terms.
2.  **Action_Check_Recent_Claims**: Prevent duplicate submissions for the same VIN/Part.
3.  **Action_Coverage_Engine**: Evaluate real-time eligibility (Likely/Borderline/Not Covered).
4.  **Action_Decode_Diagnostic_Code**: Translate raw DTCs (e.g., P0420) into plain English.
5.  **Action_Validate_Repair_Estimate**: High-side validation against SRT (Standard Repair Time) baselines.
6.  **Action_Create_Warranty_Claim**: Atomic creation of the Claim record in Automotive Cloud.
7.  **Action_Get_WhatsApp_Media_URL**: Securely fetch photo URLs from MessagingSessions.
8.  **Action_Image_Damage_Analyzer**: AI-powered damage assessment of uploaded photos.
9.  **Action_Get_Claim_Status**: Instant lookup for existing claim updates.

### 🛡️ Approver Actions
10. **Action_Approve_Claim**: Finalizes approval and notifies the dealer.
11. **Action_Reject_Claim**: Logs rejection rationale and notifies the dealer.
12. **Action_Request_Clarification**: Triggers a proactive WhatsApp message to the dealer for more info.
13. **Action_Submit_Dealer_Response**: Processes the dealer's reply to a clarification request.
14. **Action_Submit_Goodwill_Review**: Handles policy exception requests for borderline cases.
15. **Action_Get_Approval_Context**: Gathers all Claim/Vehicle/Customer data for the approver UI.
16. **Action_Link_Uploaded_Evidence**: Attaches AI analysis results to the core Claim record.
17. **Action_Route_Claim_to_Queue**: Places new claims into the appropriate OEM regional queue.

---

## 4. Security & Access
All permissions are strictly managed via the **Agentforce_Permissions** Permission Set, ensuring the agents only have `Read/Create` access to required objects and explicit `flowAccess` to the 17 actions listed above.
