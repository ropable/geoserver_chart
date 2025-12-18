{{- define "geoserver.can_restart" }}#!/bin/bash
{{- $log_levels := dict "DISABLE" 0 "ERROR" 100 "WARNING" 200 "INFO" 300 "DEBUG" 400 }}
{{- $log_levelname := upper ($.Values.geoserver.livenesslog | default "DISABLE") }}
{{- if not (hasKey $log_levels $log_levelname) }}
{{- $log_levelname = "DISABLE" }}
{{- end }}
{{- $log_level := (get $log_levels $log_levelname) | int }}

if [[ -f ${GEOSERVER_DATA_DIR}/www/server/restartenabled ]]; then
  nextRestartSeconds=$(cat ${GEOSERVER_DATA_DIR}/www/server/nextrestarttime)
  now=$(date '+%Y-%m-%d %H:%M:%S')
  hour=$(date -d "${now}" '+%H')
  hour="${hour#0*}"
  seconds=$(date -d "${now}" '+%s')

  if [[ ${seconds} -ge ${nextRestartSeconds} ]]; then
    #need to restart
    {{- if ge $log_level ((get $log_levels "ERROR") | int) }}
    echo "$(date '+%Y-%m-%d %H:%M:%S.%N') Liveness: Geoserver is scheduled to restart at $(date -d @${nextRestartSeconds} '+%Y-%m-%d %H:%M:%S')." >> ${livenesslogfile}
    {{- end }}

    declare -a restartPeriods
    {{- if get $.Values.geoserver.restartPolicy "restartPeriods" }}
      {{- $index := 0}}
      {{- range $i,$config := $.Values.geoserver.restartPolicy.restartPeriods }}
    restartPeriods[{{mul $i  2}}]={{ $config.startHour }}
    restartPeriods[{{add (mul $i  2)  1}}]={{ $config.endHour }}
      {{- end }}
    {{- else }}
    restartPeriods[0]=0
    restartPeriods[1]=24
    {{- end }}
    i=0
    while [[ $i -lt ${#restartPeriods[@]} ]]; do
      if [[ ${hour} -ge ${restartPeriods[${i}]} ]] && [[ ${hour} -lt ${restartPeriods[$((${i} + 1))]} ]]; then
         #in restart period
         canRestart=1
         break
      else
        i=$(($i + 2))
      fi
    done
  fi
fi
{{- end }}
