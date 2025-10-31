# Azure Health Monitoring - Bicep Parameters (Development)

using './main.bicep'

param environment = 'dev'
param baseName = 'azurehealth'
param timerSchedule = '0 */15 * * * *'
param cacheContainerName = 'servicehealth-cache'
