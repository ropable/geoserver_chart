{{- define "geoserver.restart" }}#!/bin/bash
{{- $adminServerIsWorker :=  true }}
{{- if hasKey $.Values.geoserver "adminServerIsWorker" }}
  {{- $adminServerIsWorker =  $.Values.geoserver.adminServerIsWorker }}
{{- end }}
{{- $log_levels := dict "DISABLE" 0 "ERROR" 100 "WARNING" 200 "INFO" 300 "DEBUG" 400 }}
{{- $log_levelname := upper ($.Values.geoserver.livenesslog | default "DISABLE") }}
{{- if not (hasKey $log_levels $log_levelname) }}
{{- $log_levelname = "DISABLE" }}
{{- end }}
{{- $log_level := (get $log_levels $log_levelname) | int }}
{{- $livenessProbe :=  $.Values.geoserver.livenessProbe | default dict }}

{{- if or (not ($.Values.geoserver.clustering | default false)) (eq ($.Values.geoserver.replicas | default 1 | int) 1) }}
#not geoserver cluster or replicas is 1, restart now 
    {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
      {{- if gt ($.Values.geoserver.memoryMonitorInterval | default 0 | int) 0  }}
{{ $.Files.Get "static/resourceusage.sh" | indent 4 }}
      {{- else }}
resourceusage=""
      {{- end }}
echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Try to restart the geocluster admin server. ${resourceusage}" >> ${livenesslogfile}
    {{- end }}

if [[ "${resourceusage}" != "" ]]; then
    sed -i -e "s/<span id=\"monitortime\">[^<]*<\/span>/<span id=\"monitortime\">$(date '+%Y-%m-%d %H:%M:%S')<\/span>/" -e "s/<span id=\"resourceusage\">[^<]*<\/span>/<span id=\"resourceusage\">${resourceusage}<\/span>/g" ${GEOSERVER_DATA_DIR}/www/server/serverinfo.html
fi
exit 1
{{- else }}
if [[ "${GEOSERVER_ROLE}" == "admin" ]]; then
    #geocluster admin server, not a worker, restart now
    {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
      {{- if gt ($.Values.geoserver.memoryMonitorInterval | default 0 | int) 0  }}
{{ $.Files.Get "static/resourceusage.sh" | indent 4 }}
      {{- else }}
    resourceusage=""
      {{- end }}
    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Try to restart the geocluster admin server. ${resourceusage}" >> ${livenesslogfile}
    {{- end }}

    if [[ "${resourceusage}" != "" ]]; then
        sed -i -e "s/<span id=\"monitortime\">[^<]*<\/span>/<span id=\"monitortime\">$(date '+%Y-%m-%d %H:%M:%S')<\/span>/" -e "s/<span id=\"resourceusage\">[^<]*<\/span>/<span id=\"resourceusage\">${resourceusage}<\/span>/g" ${GEOSERVER_DATA_DIR}/www/server/serverinfo.html
    fi
    exit 1
else
#check whether the other servers are online and also it has the earliest restart time
{{- if ge $log_level ((get $log_levels "INFO") | int) }}
    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness : check whether it is safe to restart the geoserver." >> ${livenesslogfile}
{{- end }}
    status=0

{{- range $i,$index := until ($.Values.geoserver.replicas | default 1 | int) }}
    if [[ "{{ $.Release.Name}}-geocluster-{{$i}}" != "${HOSTNAME}" ]] && [[ ${status} -eq 0 ]]; then

  {{- if and $adminServerIsWorker (eq $i 0) }}
        server="{{$.Release.Name}}-geoclusteradmin"
  {{- else }}
        server="{{$.Release.Name}}-geoclusterslave{{$i}}"
  {{- end }}

        wget --tries=1 -nv --timeout={{$.Values.geoserver.liveCheckTimeout | default 0.5 }} http://${server}:8080/geoserver/www/server/nextrestarttime -o /dev/null -O /tmp/remotegeoserver_nextrestarttime
        status=$((${status} + $?))
        if [[ $status -eq 0 ]]; then
            remoteGeoserverNextRestartTime=$(cat /tmp/remotegeoserver_nextrestarttime)
            if [[ "${remoteGeoserverNextRestartTime}" == "Disabled" ]]; then
      {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
                echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: The remote geoserver (http://${server}:8080/geoserver) is online and its restart feature is disabled, can restart before the remote geoserver." >> ${livenesslogfile}
      {{- else }}
                :
      {{- end }}
            elif [[ ${remoteGeoserverNextRestartTime} -lt ${nextRestartSeconds} ]]; then
      #remote geoserver should be restarted before this geoserver
      #can't restart this geoserver now
                status=99
      {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
                echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: The remote geoserver (http://${server}:8080/geoserver) is online and its next restart time is $(date -d @${remoteGeoserverNextRestartTime} '+%Y-%m-%d %H:%M:%S') which is earlier than the current geoserver's next restart time ($(date -d @${nextRestartSeconds} '+%Y-%m-%d %H:%M:%S')), Can't restart." >> ${livenesslogfile}
      {{- end }}
            elif [[ ${remoteGeoserverNextRestartTime} -eq ${nextRestartSeconds} ]]; then
                index="${HOSTNAME#{{ $.Release.Name }}-geocluster-*}"
                if [[ ${index} -gt {{$i}} ]]; then
                    status=99
        {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
                    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: The remote geoserver (http://${server}:8080/geoserver) is online and its next restart time is $(date -d @${remoteGeoserverNextRestartTime} '+%Y-%m-%d %H:%M:%S') which is equal with the current geoserver's next restart time ($(date -d @${nextRestartSeconds} '+%Y-%m-%d %H:%M:%S')), but the server index(${index}) is greater than the remote geoserver index ({{$i}}), can't restart." >> ${livenesslogfile}
        {{- end }}
      {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: The remote geoserver (http://${server}:8080/geoserver) is online and its next restart time is $(date -d @${remoteGeoserverNextRestartTime} '+%Y-%m-%d %H:%M:%S') which is equal with the current geoserver's next restart time ($(date -d @${nextRestartSeconds} '+%Y-%m-%d %H:%M:%S')), but the server index(${index}) is less than the remote geoserver index ({{$i}}), can restart before the remote geoserver." >> ${livenesslogfile}
      {{- end }}
                fi
    {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: The remote geoserver (http://${server}:8080/geoserver) is online and its next restart time is $(date -d @${remoteGeoserverNextRestartTime} '+%Y-%m-%d %H:%M:%S') which is later than the current geoserver's next restart time ($(date -d @${nextRestartSeconds} '+%Y-%m-%d %H:%M:%S')), can restart before the remote geoserver." >> ${livenesslogfile}
    {{- end }}
            fi
  {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: The remote geoserver (http://${server}:8080/geoserver) is offline (status=${status}). Can't restart the current server." >> ${livenesslogfile}
  {{- end }}
        fi
    fi
{{- end }} #end for range

    if [[ $status -eq 0 ]]; then
  #try to restart this geoserver
  {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
    {{- if gt ($.Values.geoserver.memoryMonitorInterval | default 0 | int) 0  }}
{{ $.Files.Get "static/resourceusage.sh" | indent 2  }}
    {{- else }}
        resourceusage=""
    {{- end }}
        echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: All remote geoservers are online and their next restart time are later than the current geoserver's next restart time ($(date -d @${nextRestartSeconds} '+%Y-%m-%d %H:%M:%S')). Try to restart the current geoserver. ${resourceusage}" >> ${livenesslogfile}
  {{- end }}

        if [[ "${resourceusage}" != "" ]]; then
            sed -i -e "s/<span id=\"monitortime\">[^<]*<\/span>/<span id=\"monitortime\">$(date '+%Y-%m-%d %H:%M:%S')<\/span>/" -e "s/<span id=\"resourceusage\">[^<]*<\/span>/<span id=\"resourceusage\">${resourceusage}<\/span>/g" ${GEOSERVER_DATA_DIR}/www/server/serverinfo.html
        fi

        exit 1
{{- if ge $log_level ((get $log_levels "ERROR") | int) }}
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: It is not safe to restart the geoserver right now" >> ${livenesslogfile}
{{- end }}

    fi #end for  if $status -eq 0 

fi #end for  if "${GEOSERVER_ROLE}" == "admin" 
{{- end }} #end for  if eq ($.Values.geoserver.replicas | default 1 | int) 1 
{{- end }} #end for define
