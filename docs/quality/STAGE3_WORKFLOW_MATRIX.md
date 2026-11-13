# Stage 3 — Workflow Test Matrix

Status legend: `NOT STARTED` means no automated end-to-end test has yet been demonstrated in the supplied source snapshot. The matrix is a plan, not a claim that a feature is implemented or tested.

| Priority | Workflow | Role sequence | Success assertions | Negative/regression assertions | Status |
|---|---|---|---|---|---|
| P0 | Authentication and access | Signed-out → each of four roles | Correct profile, active membership, correct destination | Missing profile, disabled account, invalid role, inactive membership, wrong UID/colony | PARTIAL: model/phone tests; no service integration suite |
| P0 | Complaint lifecycle | Resident → Admin | Complaint persists with correct colony/author; Admin sees it | Resident cannot alter another user's complaint; wrong-colony reads denied | NOT STARTED |
| P0 | Cleanliness dispatch | Admin → Cleanliness Manager → Worker | Cleanliness item is assigned to active worker and visible in their task list | Inactive/unlinked worker rejected; manager cannot change attendance; cross-colony isolation | PARTIAL: rules QA covers worker task/attendance access scenarios, not full app workflow |
| P0 | Worker completion | Worker → Admin | Completion and timestamps persist; Admin sees updated state | Worker cannot complete another worker's task or modify protected fields | NOT STARTED |
| P0 | Worker attendance | Worker ↔ Admin/Cleanliness Manager | Own check-in/out and date register queries | Worker cannot read another worker or another colony; managers cannot write attendance | 10/10 candidate rules Emulator tests passed; live app not verified |
| P1 | Announcements | Admin → Resident | Published notice visible in same colony; acknowledgement persists if enabled | Draft/other-colony notice hidden; resident cannot publish or edit | NOT STARTED |
| P1 | Maintenance | Resident/Admin → Vendor/Worker → Admin | Job, vendor, bill and payment links reconcile | Invalid amounts/status transitions/unauthorized edits rejected | NOT STARTED |
| P1 | Payments/financial records | Resident → Admin | Payment reference/amount/status retained; ledger totals reconcile | Duplicate submission, amount tampering, cross-resident reads denied | NOT STARTED |
| P1 | Water supply | Admin → operational roles | Supplier/delivery/stock movements reconcile | Negative stock, duplicate delivery, unauthorized mutation rejected | NOT STARTED |
| P1 | Visitors | Gate/Admin → Resident as applicable | Check-in/out and host/household link persist | Unauthorized gate actions and cross-colony visibility denied | NOT STARTED |
| P2 | Remaining modules | Role-specific | Feature-specific acceptance criteria | Invalid state, denied access, retry and data integrity | NOT STARTED |
