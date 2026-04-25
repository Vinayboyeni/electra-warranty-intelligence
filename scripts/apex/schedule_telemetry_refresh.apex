// Schedule the Data Cloud → Platform Event refresh to run every hour.
// Run once; it persists as a CronTrigger.
String jobName = 'Telemetry Signal Hourly Refresh';
String cronExp = '0 0 * * * ?';  // Top of every hour
try {
    Id jobId = System.schedule(jobName, cronExp, new RefreshTelemetrySignals());
    System.debug('Scheduled job id: ' + jobId);
} catch (Exception e) {
    System.debug('Schedule failed (maybe already exists): ' + e.getMessage());
    // Find and display the existing one
    List<CronTrigger> existing = [SELECT Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :jobName];
    for (CronTrigger ct : existing) {
        System.debug('  existing job: ' + ct.Id + ' next fire: ' + ct.NextFireTime);
    }
}
