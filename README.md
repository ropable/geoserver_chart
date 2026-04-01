# Geoserver cluster Helm chart (DBCA)

This is a custom Helm chart to deploy Geoserver in a clustered arrangement on a Kubernetes cluster.
It consists of the Helm chart, shell scripts to deploy clusters, encrypted values configuration values,
and customised HTML templates deployed with each cluster to assist with service health monitoring.

## Geoserver values YAML file reference

### Variables

- activemqJmxUser: &activemqJmxUser "\*\*\*" : Deprecated
- activemqJmxPassword: &activemqJmxPassword "\*\*\*" : Deprecated
- activemqWebUser: &activemqWebUser "\*\*\*" : Deprecated
- activemqWebPassword: &activemqWebPassword "\*\*\*" : Deprecated
- messagequeueReleaseTime: &messagequeueReleaseTime "2025-04-08T13:00:00" : Deprecated
- geoserverAdminPassword: &geoserverAdminPassword "\*\*\*" : password for geoserver admin
- geoserverAdminUser: &geoserverAdminUser "\*\*\*" : geoserver admin user
- geoserverCatalogDBHost: &geoserverCatalogDBHost "\*\*\*" : jdbc catalog database host
- geoserverCatalogDBPort: &geoserverCatalogDBPort 5432 : jdbc catalog database port
- geoserverCatalogDBName: &geoserverCatalogDBName "\*\*\*" : jdbc catalog database name
- geoserverCatalogDBUser: &geoserverCatalogDBUser "\*\*\*" : jdbc catalog database user
- geoserverCatalogDBPassword: &geoserverCatalogDBPassword "\*\*\*" : jdbc catalog database password
- ghcrImagePullUser: &ghcrImagePullUser "\*\*\*" : Image pull user
- ghcrImagePullPassword: &ghcrImagePullPassword "\*\*\*" : Image pull password
- geoserverReleaseTime: &geoserverReleaseTime "2025-11-21T12:00:00" : if changed, will always redeploy geoserver cluster workload
- adminGeoserverReleaseTime: &adminGeoserverReleaseTime "2025-11-21T12:00:00" : if changed, will always redploy geoserver cluster admin workload, only used if clustering is True and adminServerIsWorker if False
- geoserverHealthcheckReleaseTime: &geoserverHealthcheckReleaseTime "2025-10-20T10:00:00": if changed, will always redeploy geoserver healthcheck

### MessageQueue

The workload messagequeue is deprecated by suffix messagequeue with "\_skipped"

### Geoserver

```
 image: The image used by geoserver workload
 clustering: Deploy geoserver as geocluster if True; otherwise deploy a single geoserver
 adminServerIsWorker: The geocluster admin server is also a worker if True; otherwise, geocluster admin server is a dedicate admin server. Only useful if clustering is True.
 userid: The user id used by geoserver, DO NOT CHANGE
 groupid: The user group id used by geoserver, DO NOT CHANGE
 domain: the domain where ther user can get map services from.
 adminDomain: the domain to access geocluster admin server
 slaveDomain: the domain to access individual geocluster slave server
 otherDomains: list of other domains the user can get map services from
 port: the listening port of the geoserver
 replicas: the number of geoservers in the geocluster. Always redploy geocluster with Helm after replicas value is changed.
 maxstarttimes: the number of restart items will be kept in the log file
 livenesslog: liveness log level. Valid values: DEBUG, INFO, DISABLE
 livenesslogExpiredays: liveness log file expire days
 memoryMonitorInterval: the memory monitor interval in seconds.
 liveCheckTimeout: The timeout used to check whether geoserver is live.
 restartPolicy: geoserver restart policy
    restartPeriods: Configure the time frame to restart geoserver
    - startHour: 0 #included
      endHour: 7  #excluded
    - startHour: 20 #included
      endHour: 24  #excluded
    restartSchedule: Configure the restart time for each geoserver in geocluster
      adminServer: The configuration for admin server; only useful if clustering is True and adminServerIsWorker is False
        restartDays: Configure the list of weekdays to retart geoserver automatically
        - Monday
        - Tuesday
        restartTimes: Configure the list of time to restart geoserver automatically.
        - "21:00:00"
      server0-(replicas - 1): Configure the geocluster statefulset instance
        restartDays: Configure the list of weekdays to retart geoserver automatically
        - Monday
        - Sunday
        restartTimes: Configure the list of time to restart geoserver automatically.
        - "22:00:00"
  topologySpreadConstraints: Configure the list of topologySpreadConstraints for geocluster statefulset. comment out if no need
  - topologyKey: Required.
    maxSkew: Optional. Default is 1
    minDomains: Optional. Default is 1
    whenUnsatisfiable: Optional. Default is ScheduleAnyway
  resources: Configure the resources reserved for geocluster statefulset if exists
    requests:
      cpu: 300m
      memory: 4000Mi
  adminResources: Configure the resources reserved for geocluster admin geoserver if exists; otherwise use resoruces. only useful if clustering is True and adminServerIsWorker is False
    requests:
      cpu: 200m
      memory: 3000Mi
  nodeSelector: Configure the nodeSelector for geocluster statefulset if exists
    arch: "arm64"
  adminNodeSelector:Configure the nodeSelector for geocluster admin geoserver if exists.only useful if clustering is True and adminServerIsWorker is False
    arch: "arm64"
  tolerations: Configure the tolerations for geocluster statefulset if exists
    - effect: NoSchedule
      key: arch
      operator: Equal
      value: arm64
  adminTolerations: Configure the adminTolerations for geocluster admin geoserver if exists.only useful if clustering is True and adminServerIsWorker is False
    - effect: NoSchedule
      key: arch
      operator: Equal
      value: arm64
  affinity: Configure any required pod antiaffinity for worker pods (optional). Update the matchLabels value as needed.
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 1
          podAffinityTerm:
            labelSelector:
              matchLabels:
                workload.user.cattle.io/workloadselector: apps.statefulset-kmi-kb-uat-geocluster-workers
            topologyKey: kubernetes.io/hostname
  envs: Configure the envs for all geocluster geoservers
  secrets: Configure the secrets for all geocluster geoservers
    credential:
      GEOSERVER_ADMIN_PASSWORD: *geoserverAdminPassword
      GEOSERVER_ADMIN_USER: *geoserverAdminUser
  configmaps: Configure the secrets for all geocluster geoservers
    settings:
      TZ: "Australia/Perth"
      GEOSERVER_DATA_DIR: "/geoserver/data"
  adminConfigmaps:  Configure the secrets for geocluster admin geoserver. only useful if clustering is True and adminServerIsWorker is False.
    resources:
      INITIAL_MEMORY: "2000M"
      MAXIMUM_MEMORY: "3000M"
  slaveConfigmaps:  Configure the secrets for geocluster statefulset. only useful if clustering is True and adminServerIsWorker is False.
    resources:
      INITIAL_MEMORY: "3000M"
      MAXIMUM_MEMORY: "4000M"
  customsettings: Configure the customsettings of geoserver catalog.
    - name: "global.xml"
      path: "conf/geoserver/default/global.xml"
      mountPath: "global.xml"
  livenessProbe: Config the livenessProbe for all geocluster geoservers
    initialDelaySeconds: 10
    periodSeconds: 10
    successThreshold: 1
    failureThreshold: 6
  startupProbe: Config the startupProbe for all geocluster geoservers
    initialDelaySeconds: 30
    periodSeconds: 5
    successThreshold: 1
    failureThreshold: 120
  volumes: Declare the volumes for all geocluter goservers
    pvcs: Declare the persistent volumes
      catalog:
        storage: 1Gi
        storageClassName: "****"
        accessMode: "ReadWriteMany"
        volumeMode: "Filesystem"
        mounts:
        - mountPath: "/geoserver/data"
          subPath: "geoserver-data"
  adminVolumes:  Declare the volumes for geocluter admin geoserver.  only useful if clustering is True and adminServerIsWorker is False
    data:
      storage: 25Gi
      storageClassName: "***"
      accessMode: "ReadWriteOnce"
      volumeMode: "Filesystem"
      mounts:
      - mountPath: "/geoserver/data/logs/logging"
        subPath: "logging"
  existingVolumes: Reference the exisiting volumes for all geocluster geoservers
    cddp:
      claimName: kmi-cddp
      readOnly: "true"
      mounts:
      - mountPath: "/mnt/GIS-CALM"
  existingAdminVolumes: Reference the exisiting volumes for geocluster admin geoserver. only useful if clustering is True and adminServerIsWorker is False
    test:
      claimName: kmi-test
      readOnly: "true"
      mounts:
      - mountPath: "/test"
  volumeClaimTemplates: Declare the volumeClaimTemplates for geocluster statefulset.
    data:
      storage: 80Gi
      storageClassName: "***"
      accessMode: "ReadWriteOnce"
      volumeMode: "Filesystem"
      mounts:
      - mountPath: "/geoserver/data/logs/logging"
        subPath: "logging"
```

## Deployment

1. Pull the latest changes from the repository.

1. Find the related values yaml file:

   - KMI UAT: `values-geocluster-kmi-uat.yaml`
   - KMI PROD on az-aks-prod01: `values-geocluster-kmi-bushfireseason-prod.yaml`
   - KMI PROD on aks-coe-prod-02: `values-geocluster-kmi-bushfireseason-coe-prod-02.yaml`
   - KB DEV: `values-geocluster-kb-dev.yaml`
   - KB UAT: `values-geocluster-kb-uat.yaml`
   - KB PROD: `values-geocluster-kb-prod.yaml`

1. Run the command to get the values yaml file from corresponding encrypted yaml file.
   Get the decryption password from **1Password** with the name _KB/KMI Geoserver Helm chart values decryption/encryption password_.
   For example, use the following command to decrypt file `values-geocluster-kmi-bushfireseason-prod.yaml`: `./decrypt.sh values-geocluster-kmi-bushfireseason-prod.yaml`

1. Change the configurations if required, and also change the ReleaseTime to force the deployment.

1. Switch context to the target Kubernetes cluster:

   - KMI UAT: az-aks-oim03
   - KMI1 PROD: az-aks-prod01
   - KMI1 PROD: aks-coe-prod-02
   - KB DEV: az-aks-oim03
   - KB UAT: az-aks-oim03
   - KB PROD: az-aks-prod01

1. Use the related shell script to deploy changes:

   - KMI UAT: `./deploy-kmi-uat.sh`
   - KMI PROD on az-aks-prod01: `./deploy-kmi-bushfireseason-prod.sh`
   - KMI PROD on aks-coe-prod-02: `./deploy-kmi-bushfireseason-coe-prod-02.sh`
   - KB DEV: `./deploy-kb-dev.sh`
   - KB UAT: `./deploy-kb-uat.sh`
   - KB PROD: `./deploy-kb-prod.sh`

1. Encrypt the changed values file and commit: `encrypt.sh values-geocluster-kmi-bushfireseason-prod.yaml`
