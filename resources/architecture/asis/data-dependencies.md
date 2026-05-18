# Judicial Itineraries (JI) - Data Dependencies

This document catalogues the external data dependencies of the Judicial Itineraries (JI) system, identifying what data flows in and out, the source or destination system, and the mechanism of exchange.

## Summary

JI is largely a standalone system with **limited direct integrations**. Most data exchange is file-based (Excel exports) or email-based rather than API-driven. The system both consumes and produces data critical to HMCTS judicial operations.

## At a Glance

| # | Direction | External System | Data | Mechanism | Criticality |
|---|-----------|----------------|------|-----------|-------------|
| 1 | Inbound | HR / Admin Records | Working patterns, contractual sitting days | Manual entry by RSU users | High |
| 2 | Inbound | eLinks (Judicial Database) | Judge profiles, roles, base locations | Manual (automated import is a stated NFR, not yet implemented) | High |
| 3 | Inbound | Court Listing Systems | Planned judicial activity (how judges spend the day) | Manual copy / data entry | Medium |
| 4 | Inbound | Court Staff | Sitting confirmations, actual work types, absence requests | Manual entry via JI UI | High |
| 5 | Outbound | JFEPS / Finance System | Fee-paid judge payment files | JFEPS-compatible Excel export, emailed to Payment Authoriser | Critical |
| 6 | Outbound | Liberata | Payment schedules | Email (forwarded by Payment Authoriser) | Critical |
| 7 | Outbound | DA&I (Data, Analysis & Insight) | Sitting days, utilisation, vacancy & absence analysis | Excel / PDF report exports | High |
| 8 | Outbound | HMCTS Email Infrastructure | Itineraries, booking confirmations, absence notifications, payment files | Automated email (some overnight batch) | High |
| 9 | Both | JFEPS (Reconciliation) | Payment status, discrepancies between bookings and payments | Manual flagging in JI after finance confirmation | Medium |
| 10 | Platform | OPT / Oracle APEX | Runtime, authentication, shared assets, session management | Tightly coupled platform dependency | Critical |

For detailed descriptions of each dependency, see the sections below.

---

## Inbound Data Dependencies

These are external systems or sources from which JI receives or imports data.

### 1. HR / Administrative Records

| Attribute | Detail |
|-----------|--------|
| **Source system** | HR systems / administrative records (specific system not named in documentation) |
| **Data consumed** | Judge working patterns, contractual sitting days, part-time arrangements, agreed working arrangements |
| **Data type** | Reference / configuration data |
| **Mechanism** | Manual entry by RSU users into JI. No automated integration. |
| **Frequency** | As changes occur (e.g. new judge, change to part-time, base court transfer) |
| **Criticality** | High - working patterns are the foundation for generating judge itineraries and sitting targets |

**Note:** JI is explicitly *not* the system of record for HR or employment contracts. It reflects working patterns that have already been agreed elsewhere.

### 2. eLinks (Judicial Database)

| Attribute | Detail |
|-----------|--------|
| **Source system** | eLinks - the Judicial Database |
| **Data consumed** | Judiciary data: judge names, details, roles, base locations, status |
| **Data type** | Master / reference data |
| **Mechanism** | The SRS states "The system shall support eLinks integration for importing judiciary data" (NFR-3). However, the current technical mechanism, frequency, and detailed data mapping are not described - it is a stated requirement, not a fully implemented integration. Currently data is manually copied. |
| **Frequency** | Unknown / manual |
| **Criticality** | High - judge profile data is foundational to all JI operations |

**Note:** The training documentation states that once the new Judicial Database replacement is complete, processes for updating JI from it will be examined. Currently all judge data maintenance is done manually and users must keep both systems updated.

### 3. Listing Systems (Courts)

| Attribute | Detail |
|-----------|--------|
| **Source system** | Court listing systems (e.g. systems used by courts for case listing) |
| **Data consumed** | Planned judicial activity data - how judges plan to spend their working day |
| **Data type** | Operational / transactional data |
| **Mechanism** | Manual - data is copied from listing systems or entered manually by HMCTS staff, then confirmed after the fact ("recording the actual") |
| **Frequency** | Daily (courts are encouraged to confirm sittings daily) |
| **Criticality** | Medium - provides the "actuals" that drive utilisation reporting and payment processing |

**Note:** There is no direct system-to-system integration between JI and core case management systems (CaseMan, FamilyMan, Common Platform). This is explicitly stated in the documentation.

### 4. Court Staff (Manual Confirmation Data)

| Attribute | Detail |
|-----------|--------|
| **Source system** | Local court offices |
| **Data consumed** | Confirmation of sittings and bookings (did the sitting actually occur, session duration, actual work type), absence requests |
| **Data type** | Operational / transactional data |
| **Mechanism** | Manual entry via JI user interface |
| **Frequency** | Daily (recommended), at minimum before monthly verification deadline |
| **Criticality** | High - confirmed data drives payment exports and MI reporting |

---

## Outbound Data Dependencies

These are external systems or processes that consume data produced by JI.

### 5. JFEPS / Finance System (Judicial Fee Payments)

| Attribute | Detail |
|-----------|--------|
| **Destination system** | JFEPS (Judicial Fee Payment System) |
| **Data produced** | Payment data for fee-paid judges derived from confirmed bookings: judge details, court codes, dates, session types, booking IDs, fee amounts |
| **Data type** | Financial / transactional data |
| **Format** | JFEPS-compatible Excel export files |
| **Mechanism** | JI generates Excel files, validates data before export (dates, court codes, booking IDs), and emails the file to designated Payment Authorisers. The authoriser reviews, approves, and manually uploads to JFEPS. |
| **Frequency** | Typically weekly |
| **Criticality** | Critical - this is the primary mechanism for paying fee-paid judges in Crown Courts. Without JI, courts would need to manually create each payment. |

**Note:** JI does not process payments directly. It does not store or expose judge bank details or sensitive financial information - those remain in the finance system.

### 6. Liberata (L!BERATA) - Payment Processing

| Attribute | Detail |
|-----------|--------|
| **Destination system** | Liberata (payment processing partner) |
| **Data produced** | Payment schedules for fee-paid judicial sittings |
| **Data type** | Financial / transactional data |
| **Format** | Payment schedule (via email, forwarded by Payment Authoriser) |
| **Mechanism** | JI generates payment schedule -> sent to Payment Authoriser -> authoriser reviews and forwards to Liberata |
| **Frequency** | Weekly |
| **Criticality** | Critical - Liberata processes the actual fee payments |

### 7. DA&I (Data, Analysis & Insight) - Management Information

| Attribute | Detail |
|-----------|--------|
| **Destination system** | DA&I team systems / analytics platforms |
| **Data produced** | Sitting day data, judicial utilisation statistics, vacancy analysis, booking analysis, absence analysis |
| **Data type** | Aggregated management information |
| **Format** | Excel and PDF exports from JI report screens; manual extraction via spreadsheets |
| **Mechanism** | Export-based - DA&I extracts and transforms JI data into management information. Reports are exported via browser copy-paste to Excel or PDF download. |
| **Frequency** | As required for reporting cycles |
| **Criticality** | High - JI is currently the primary source of sitting day data for Civil, Family, and Crown Courts. DA&I aggregates this to produce MI on planned and actual sittings. |

### 8. Email Infrastructure (HMCTS)

| Attribute | Detail |
|-----------|--------|
| **Destination system** | HMCTS email infrastructure |
| **Data produced** | Itinerary emails to judges and staff, absence acknowledgement notifications, booking confirmation/cancellation notifications, payment export files to Payment Authorisers, alerts to court staff |
| **Data type** | Notifications and document distribution |
| **Mechanism** | Automated email sending from JI (some immediate, some via overnight batch process) |
| **Frequency** | Event-driven (on booking, absence, cancellation, payment export) |
| **Criticality** | High - operational communications depend on email delivery |

---

## Bidirectional / Reconciliation Dependencies

### 9. Payment Reconciliation (JFEPS -> JI)

| Attribute | Detail |
|-----------|--------|
| **Systems** | JFEPS / Finance System <-> JI |
| **Data exchanged** | Reconciliation data: which payments have been made, which remain pending, discrepancies between JI-generated payment requests and finance confirmations |
| **Data type** | Financial reconciliation |
| **Mechanism** | Finance users manually flag payments as reconciled in JI once confirmation is received from JFEPS. No automated data feed back into JI from finance. |
| **Frequency** | Ongoing as payments are processed |
| **Criticality** | Medium - ensures bookings are not double-paid and discrepancies are tracked |

---

## Platform Dependencies

### 10. OPT / Oracle APEX Platform

| Attribute | Detail |
|-----------|--------|
| **System** | One Performance Truth (OPT) platform |
| **Dependency type** | Runtime platform |
| **Services consumed** | Oracle APEX runtime and authentication, shared JavaScript/CSS assets (`opt.common.js`, `opt.ji.js`), session management and timeout controls, APEX page templates, session timeout plug-ins |
| **Criticality** | Critical - JI cannot operate without the OPT APEX platform |

**Note:** The OPT platform is unsupported legacy technology. There is an active initiative to transition OPT-based applications under DTS management, with the Board endorsing full replacement as the strategic direction.

---

## Data Dependency Diagram

The numbered badge in the top-right of each box matches the `#` column in the **At a Glance** table above, so the diagram can be walked through in sequence (1 → 10).

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 620" width="100%" font-family="Arial, sans-serif" role="img" aria-label="JI data dependency diagram with numbered badges 1 to 10"><defs><marker id="dd-arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#37474f"/></marker><marker id="dd-arr-recon" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#c0392b"/></marker></defs><text x="140" y="26" font-size="14" font-weight="700" text-anchor="middle" fill="#263238">INBOUND</text><text x="500" y="26" font-size="14" font-weight="700" text-anchor="middle" fill="#263238">JUDICIAL ITINERARIES</text><text x="860" y="26" font-size="14" font-weight="700" text-anchor="middle" fill="#263238">OUTBOUND</text><rect x="20" y="55" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="140" y="85" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">HR / Admin Records</text><text x="140" y="103" font-size="11" text-anchor="middle" fill="#555555">working patterns, contractual days</text><circle cx="258" cy="57" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="258" y="61" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">1</text><rect x="20" y="140" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="140" y="170" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">eLinks</text><text x="140" y="188" font-size="11" text-anchor="middle" fill="#555555">Judicial Database &#8212; judge profiles</text><circle cx="258" cy="142" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="258" y="146" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">2</text><rect x="20" y="225" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="140" y="255" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">Listing Systems</text><text x="140" y="273" font-size="11" text-anchor="middle" fill="#555555">planned judicial activity</text><circle cx="258" cy="227" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="258" y="231" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">3</text><rect x="20" y="310" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="140" y="340" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">Court Staff</text><text x="140" y="358" font-size="11" text-anchor="middle" fill="#555555">sitting confirmations, absences</text><circle cx="258" cy="312" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="258" y="316" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">4</text><rect x="380" y="150" width="240" height="230" rx="10" fill="#d6e6ff" stroke="#1a5490" stroke-width="2"/><text x="500" y="255" font-size="20" font-weight="700" text-anchor="middle" fill="#0d3a6b">Judicial Itineraries</text><text x="500" y="285" font-size="20" font-weight="700" text-anchor="middle" fill="#0d3a6b">(JI)</text><line x1="260" y1="87" x2="380" y2="190" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><line x1="260" y1="172" x2="380" y2="225" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><line x1="260" y1="257" x2="380" y2="275" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><line x1="260" y1="342" x2="380" y2="320" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><rect x="740" y="55" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="860" y="85" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">JFEPS / Finance</text><text x="860" y="103" font-size="11" text-anchor="middle" fill="#555555">payment files (Excel)</text><circle cx="978" cy="57" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="978" y="61" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">5</text><rect x="740" y="140" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="860" y="170" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">Liberata</text><text x="860" y="188" font-size="11" text-anchor="middle" fill="#555555">payment processing</text><circle cx="978" cy="142" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="978" y="146" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">6</text><rect x="740" y="225" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="860" y="255" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">DA&amp;I</text><text x="860" y="273" font-size="11" text-anchor="middle" fill="#555555">management information</text><circle cx="978" cy="227" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="978" y="231" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">7</text><rect x="740" y="310" width="240" height="64" rx="8" fill="#f5f7fa" stroke="#37474f" stroke-width="1.5"/><text x="860" y="340" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">HMCTS Email</text><text x="860" y="358" font-size="11" text-anchor="middle" fill="#555555">notifications, itineraries</text><circle cx="978" cy="312" r="14" fill="#1a5490" stroke="#ffffff" stroke-width="2"/><text x="978" y="316" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">8</text><line x1="620" y1="190" x2="740" y2="87" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><line x1="620" y1="225" x2="740" y2="172" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><line x1="620" y1="275" x2="740" y2="257" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><line x1="620" y1="320" x2="740" y2="342" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><path d="M 740 105 C 680 125 660 150 620 215" stroke="#c0392b" stroke-width="1.5" fill="none" stroke-dasharray="6,3" marker-end="url(#dd-arr-recon)"/><text x="678" y="135" font-size="11" text-anchor="middle" fill="#c0392b" font-style="italic">reconciliation</text><circle cx="690" cy="158" r="14" fill="#c0392b" stroke="#ffffff" stroke-width="2"/><text x="690" y="162" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">9</text><rect x="380" y="450" width="240" height="80" rx="8" fill="#fff4cc" stroke="#b8860b" stroke-width="2"/><text x="500" y="482" font-size="13" font-weight="700" text-anchor="middle" fill="#263238">OPT / Oracle APEX</text><text x="500" y="500" font-size="11" text-anchor="middle" fill="#555555">runtime, authentication, sessions</text><text x="500" y="518" font-size="11" text-anchor="middle" fill="#555555" font-style="italic">platform dependency</text><circle cx="618" cy="452" r="14" fill="#b8860b" stroke="#ffffff" stroke-width="2"/><text x="618" y="456" font-size="13" font-weight="700" text-anchor="middle" fill="#ffffff">10</text><line x1="500" y1="380" x2="500" y2="450" stroke="#37474f" stroke-width="1.5" fill="none" marker-end="url(#dd-arr)"/><text x="540" y="418" font-size="11" text-anchor="middle" fill="#455a64">runs on</text></svg>

---

## Key Observations

1. **Heavy reliance on manual data entry** - Most inbound data flows are manual. Judge details are manually maintained from HR records and eLinks. Sitting confirmations are manual. Working patterns are manually entered.

2. **No case management system integration** - JI explicitly does not integrate with CaseMan, FamilyMan, or Common Platform. It operates at the judicial scheduling level only, not at case/hearing level.

3. **Export-based outbound integration** - All outbound data flows are file-based (Excel, PDF) or email-based. There are no API integrations.

4. **JFEPS is the most critical integration** - The payment export to JFEPS is the most operationally critical data dependency. Crown Courts rely on this to pay fee-paid judges.

5. **Tribunals gap** - JI currently does not cover Tribunals, which is a significant data gap. Tribunal sitting data is collected manually via spreadsheets managed by different Chamber Presidents' Offices.

6. **Future integration needs** - The Actuals programme and Scheduling & Listing (S&L) reforms require JI data and integration, which the current export-based model cannot easily support.

---

## Source Documents

This analysis is based on the following input documents:

- High Level Capabilities JI.docx
- JI Functional and Non Functional Requirements.docx
- Judicial Itineraries High Level Requirements.docx
- Judicial Itinerary KB.docx
- OPT JI Training Brief DRAFT 02.doc
- UCD resource request.docx
