{{- define "geoserver.geoserver_liveness" }}#!/bin/bash
{{- $adminServerIsWorker :=  true }}
{{- if hasKey $.Values.geoserver "adminServerIsWorker" }}
  {{- $adminServerIsWorker =  $.Values.geoserver.adminServerIsWorker }}
{{- end }}

source /geoserver/bin/set_geoserverrole
geoserverpid=$(cat /tmp/geoserverpid)

LIVENESSLOG_EXPIREDAYS={{$.Values.geoserver.livenesslogExpiredays | default 30}}
{{- $log_levels := dict "DISABLE" 0 "ERROR" 100 "WARNING" 200 "INFO" 300 "DEBUG" 400 }}
{{- $log_levelname := upper ($.Values.geoserver.livenesslog | default "DISABLE") }}
{{- if not (hasKey $log_levels $log_levelname) }}
{{- $log_levelname = "DISABLE" }}
{{- end }}
{{- $log_level := (get $log_levels $log_levelname) | int }}
{{- $livenessProbe :=  $.Values.geoserver.livenessProbe | default dict }}

{{ $.Files.Get "static/manage_livenesslog.sh"  }}

{{- if and (get $.Values.geoserver "restartPolicy") (get $.Values.geoserver.restartPolicy "restartSchedule") }}
canRestart=0
source /geoserver/bin/geoserver_can_restart

if [[ ${canRestart} -eq 1 ]]; then
  source /geoserver/bin/geoserver_restart
fi
{{- end}}

starttime=$(date '+%s.%N')
wget --tries=1 -nv --timeout={{$.Values.geoserver.liveCheckTimeout | default 0.5 }} http://127.0.0.1:8080/geoserver/www/server/readytime -o /dev/null -O /dev/null
status=$?
endtime=$(date '+%s.%N')
pingtime=$(perl -e "print (${endtime} - ${starttime}) * 1000")
if [[ ${status} -eq 0 ]]; then
    pingstatus="Succeed"
else
    pingstatus="Failed"
fi
{{- if ge $log_level ((get $log_levels "ERROR") | int) }}
{{- if gt ($.Values.geoserver.memoryMonitorInterval | default 0 | int) 0  }}
nexttime=$(cat /tmp/memorymonitornexttime)
if [[ $(date '+%s') -ge ${nexttime} ]] ; then
{{ $.Files.Get "static/resourceusage.sh" | indent 2 }}
  echo "$((${nexttime} + {{- $.Values.geoserver.memoryMonitorInterval}}))" > /tmp/memorymonitornexttime
elif [[ ${status} -gt 0 ]]; then
{{ $.Files.Get "static/resourceusage.sh" | indent 2 }}
else
  resourceusage=""
fi
{{- else }}
resourceusage=""
{{- end }}
{{- end }}

if [[ "${resourceusage}" != "" ]]; then
  sed -i -e "s/<span id=\"monitortime\">[^<]*<\/span>/<span id=\"monitortime\">$(date '+%Y-%m-%d %H:%M:%S')<\/span>/" -e "s/<span id=\"resourceusage\">[^<]*<\/span>/<span id=\"resourceusage\">${resourceusage}<\/span>/" -e "s/<span id=\"heartbeat\">[^<]*<\/span>/<span id=\"heartbeat\">${now}<\/span>/" -e "s/<span id=\"heartbeat_status\">[^<]*<\/span>/<span id=\"heartbeat_status\">${pingstatus}<\/span>/" -e "s/<span id=\"heartbeat_processingtime\">[^<]*<\/span>/<span id=\"heartbeat_processingtime\">${pingtime}<\/span>/" ${GEOSERVER_DATA_DIR}/www/server/serverinfo.html
else
    sed -i -e "s/<span id=\"heartbeat\">[^<]*<\/span>/<span id=\"heartbeat\">${now}<\/span>/" -e "s/<span id=\"heartbeat_status\">[^<]*<\/span>/<span id=\"heartbeat_status\">${pingstatus}<\/span>/" -e "s/<span id=\"heartbeat_processingtime\">[^<]*<\/span>/<span id=\"heartbeat_processingtime\">${pingtime}<\/span>/" ${GEOSERVER_DATA_DIR}/www/server/serverinfo.html
fi

if [[ ${status} -eq 0 ]]; then
  if [[ -f /tmp/geoserver_failuretimes ]]; then
    #The file "failuretimes" exists, remove  it
    rm -f /tmp/geoserver_failuretimes
    {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Geoserver is back to online again. ${resourceusage}, ping: ${pingstatus}, pingtime: ${pingtime}" >> ${livenesslogfile}
    {{- end }}
  {{- if ge $log_level ((get $log_levels "DEBUG") | int) }}
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Geoserver is online. ${resourceusage}, ping: ${pingstatus}, pingtime: ${pingtime}" >> ${livenesslogfile}
  {{- else }}
  elif [[ "$resourceusage" != "" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Geoserver is online. ${resourceusage}, ping: ${pingstatus}, pingtime: ${pingtime}" >> ${livenesslogfile}
  {{- end }}
  fi
  exit 0
fi
{{- if eq ($livenessProbe.failureThreshold | default 2 | int) 1 }}
  {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
  echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Geoserver is offline, restart. ${resourceusage}, ping: ${pingstatus}, pingtime: ${pingtime}" >> ${livenesslogfile}
  {{- end }}
  exit ${status}
{{- else }}
if [[ -f /tmp/geoserver_failuretimes ]]; then
  failureTimes=$(cat /tmp/geoserver_failuretimes)
  failureTimes=$((${failureTimes} + 1))
else
  failureTimes=1
fi
echo ${failureTimes} > /tmp/geoserver_failuretimes
if [[ ${failureTimes} -ge {{ $livenessProbe.failureThreshold | default 2 }} ]]; then
  #geoserver is not available 
  {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
  echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Geoserver is offline on the ${failureTimes}th continous check, restart. ${resourceusage}, ping: ${pingstatus}, pingtime: ${pingtime}" >> ${livenesslogfile}
  {{- end }}
  exit ${status}
else
  {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
  echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Geoserver is offline on the ${failureTimes}th continous check, need to check again. ${resourceusage}, ping: ${pingstatus}, pingtime: ${pingtime}" >> ${livenesslogfile}
  {{- end }}
  exit 0
fi
{{- end }}

{{- end }}
