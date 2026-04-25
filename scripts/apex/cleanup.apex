// Delete approval logs (CAL-* records) first — try both possible API names
try {
    List<SObject> logs = Database.query('SELECT Id FROM ClaimApprovalLog');
    delete logs;
    System.debug('Deleted ClaimApprovalLog: ' + logs.size());
} catch(Exception e) { System.debug('ClaimApprovalLog skip: ' + e.getMessage().left(80)); }

try {
    List<SObject> logs = Database.query('SELECT Id FROM ClaimParticipant');
    delete logs;
    System.debug('Deleted ClaimParticipant: ' + logs.size());
} catch(Exception e) { System.debug('ClaimParticipant skip: ' + e.getMessage().left(80)); }

// Now delete Claims
try {
    List<Claim> claims = [SELECT Id FROM Claim];
    Database.delete(claims, false);
    System.debug('Deleted Claims: ' + claims.size());
} catch(Exception e) { System.debug('Claim: ' + e.getMessage().left(100)); }

try { delete [SELECT Id FROM AssetWarranty WHERE AssetId != null]; } catch(Exception e) { System.debug('AssetWarranty: ' + e.getMessage().left(80)); }
try { delete [SELECT Id FROM Vehicle WHERE VehicleIdentificationNumber = 'ELX10000000000001']; } catch(Exception e) { System.debug('Vehicle: ' + e.getMessage().left(80)); }
try { delete [SELECT Id FROM Asset WHERE Name LIKE '%ELX10000000000001%']; } catch(Exception e) { System.debug('Asset: ' + e.getMessage().left(80)); }
try { delete [SELECT Id FROM VehicleDefinition WHERE Name = '2024 Electra X5 Sport']; } catch(Exception e) { System.debug('VehicleDefinition: ' + e.getMessage().left(80)); }
try { delete [SELECT Id FROM Product2 WHERE StockKeepingUnit = 'EX5-2024']; } catch(Exception e) { System.debug('Product2: ' + e.getMessage().left(80)); }
try { delete [SELECT Id FROM Contact WHERE Email = 'demo.customer@electra.demo']; } catch(Exception e) { System.debug('Contact: ' + e.getMessage().left(80)); }
try { delete [SELECT Id FROM Account WHERE Name = 'Electra Flagship Store']; } catch(Exception e) { System.debug('Account: ' + e.getMessage().left(80)); }
System.debug('=== CLEANUP COMPLETE ===');
