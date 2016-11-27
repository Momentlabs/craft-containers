#!/bin/bash

function log {
  local mesg=$1
  local now=`date --rfc-3339=seconds`
  echo \{ \"serviceName\": \"craft-server\", \"operation\": \"startup\", \"logTime\": \"$now\", \"userName\": \"${SERVER_USER}\", \"serverName\": \"${SERVER_NAME}\", \"cluster\": \"${CLUSTER_NAME}\", \"serverType\": \"${TYPE}\", \"msg\": \"$mesg\" \}
}

# echo "{\"log_time\":\"`date --rfc-3339=seconds`\", \"level\":\"INFO\", \"msg\":\"CRAFT SERVER START UP\"}"
log "CRAFT SERVER STARTING UP"

usermod --uid $UID minecraft
groupmod --gid $GID minecraft

chown -R minecraft:minecraft /data /start-minecraft /home/minecraft
chmod -R g+wX /data /start-minecraft

while lsof -- /start-minecraft; do
  echo -n "."
  sleep 1
done

mkdir -p /home/minecraft
chown minecraft: /home/minecraft

# echo "`date --rfc-3339=seconds` [INFO] Switching to user 'minecraft' and starting."
# echo "{\"log_time\":\"`date --rfc-3339=seconds`\", \"userName\":\"${SERVER_USER}\", \"serverName\":\"${SERVER_NAME}\"}"

exec sudo -E -u minecraft /start-minecraft "$@"
