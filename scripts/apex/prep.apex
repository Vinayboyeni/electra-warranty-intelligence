// Run this in Developer Console (Execute Anonymous) OR via:
// sf apex run --file scripts/apex/prep.apex --target-org vscodeOrg
//
// Seeds: 1 dealer (Trust=85), 1 vehicle (VIN: ELX10000000000001),
//        3 warranties (standard / battery / expiring in 28 days)

HackathonDataPrep.prepareDemoData();
System.debug('✅ Demo data seeded. VIN: ELX10000000000001 | Dealer: Electra Flagship Store');
