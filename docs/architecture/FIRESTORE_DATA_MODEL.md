# Firestore Data Model (source inventory)

This document records collection paths declared by the audited `firestore.rules` snapshot. It is an inventory, not a full schema contract: field validation and per-operation authorization remain defined by the rules and application code, and some nested paths share names across parent collections.

## Root collections

- `users/{uid}` — account profile used during access resolution.
- `colonies/{colonyId}` — colony root; nested member and operational records are colony-scoped.

## Colony membership and residents

Representative paths:

- `colonies/{colonyId}/members/{uid}`
- `colonies/{colonyId}/households/{householdId}`
- `colonies/{colonyId}/residents/{residentId}`
- `colonies/{colonyId}/residentLoginRegistrations/{residentId}`
- `colonies/{colonyId}/householdMemberRequests/{requestId}`
- `colonies/{colonyId}/residentChangeRequests/{requestId}`
- `colonies/{colonyId}/residentServiceRequests/{requestId}`

## Complaints, cleanliness and housekeeping

- `complaints`, `cleanlinessWorkers`, `cleanlinessTasks`, `completionLogs`, `housekeepingRequests`.
- `workerAttendance` records worker attendance under a colony.

## Communication and community

- `announcements`, `acknowledgements`, `notifications`, `pushInstallations`.
- `communityPosts`, `communityDirectoryProfiles`, `comments`, `moderationEvents`, `communityEvents`, `communityPolls`, `rsvps`, `votes`.
- `colonyServiceDirectory`, `colonyServiceDirectoryAudit`, `colonyServiceDirectoryFeedback`.

## Maintenance, assets and finance

- `maintenanceJobs`, `maintenanceBills`, `maintenancePayments`, `maintenanceVendors`, `maintenanceSlaCases`, `maintenanceSlaEvents`, `maintenanceSlaPolicies`.
- `preventiveMaintenancePlans`, `assetAmcContracts`, `colonyAssets`, `inventoryItems`, `inventoryTransactions`.
- `colonyBudgets`, `colonyExpenses`, `accountingAccounts`, `accountingJournals`, `accountingBankStatements`, `accountingJournalMatches`, `accountingPeriods`, `accountingReconciliations`, `accountingAuditEvents`, `accountingImports`, `accountingSettings`.
- Procurement: `purchaseRequisitions`, `purchaseQuotations`, `purchaseOrders`, `purchaseGoodsReceipts`, `procurementApprovals`, `procurementAudit`, `supplierInvoices`, `supplierPayments`.
- Staff records include `colonyStaff`, `colonyPayrollRuns`, `salaryHistory`, `staffLeaveRequests` and nested payroll entries/payments.

## Water and gate / security operations

- Water: `waterSuppliers`, `waterDeliveries`, `waterDistributions`, `waterIncidents`, `waterMeters`, `waterMeterReadings`, `waterQualityChecks`, `waterStorageAssets`, `waterStorageMovements`.
- Gate and visitors: `visitors`, `gateOperators`, `gateShifts`, `gateDeliveries`, `gateHandovers`, `domesticHelpers`, `domesticHelpVisits`, `serviceProviders`, `serviceProviderVisits`.
- Security: `securityIncidents`, `lostFoundItems` and emergency records.

## Governance, documents and leases

- Governance: `rwaCommitteeMembers`, `rwaCommitteePermissions`, `rwaGovernanceActions`, `rwaGovernanceAudit`, `rwaGovernanceDocuments`, `rwaGovernanceMeetings`, `rwaMeetingMinutes`, `rwaResolutions`, `rwaComplianceRegister`.
- Documents: `residentDocuments`, `documentAuditEvents`, with nested `versions/{versionId}/chunks/{chunkId}` paths in the source.
- Tenancy: `tenantLeases`, `tenantLeaseRenewalRequests`, `moveRequests`.

## Emergency and reporting

- `emergencyAlerts`, `emergencyAssemblyPoints`, `emergencyCommandLogs`, `emergencyContacts`, `emergencyDrills`, `emergencyReadinessChecks`, `emergencyResponders`, `reports`.

## Relationships and invariants

- A Firebase Auth UID identifies the account in `users/{uid}` and the membership document ID in `colonies/{colonyId}/members/{uid}`.
- Membership records carry `uid`, `colonyId`, `role` and `status`; active status and role are used in access resolution.
- Memberships may link to `residentId`, `workerId`, `householdId` and `blockId` depending on role.
- Financial, maintenance, resident and operational documents should retain their `colonyId` through their path and validated references; cross-colony references must be rejected.
- Nested document chunking currently uses Firestore documents/bytes, not an audited Firebase Storage SDK.

## Rules/index caution

The maintainer-local Rules snapshot audited on 8 November 2026 measured 384,997 bytes and exceeds the documented Firestore Rules source-size limit; it is not included in the distributable repository. The separately included candidate is a QA artifact only and has not been deployed. The audited `firestore.indexes.json` contains zero composite indexes and one field override; this does not prove that no additional query indexes are required. Review Emulator and development-project index errors before preparing a separate, approved Firestore deployment configuration.
