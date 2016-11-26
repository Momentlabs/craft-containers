#!/bin/sh

echo "`date --rfc-3339=seconds` [INFO] CRAFT SERVER START UP."

set -e
`usermod --uid $UID minecraft`
groupmod --gid $GID minecraft

chown -R minecraft:minecraft /data /start-minecraft /home/minecraft
chmod -R g+wX /data /start-minecraft

while lsof -- /start-minecraft; do
  echo -n "."
  sleep 1
done

mkdir -p /home/minecraft
chown minecraft: /home/minecraft

echo "`date --rfc-3339=seconds` [INFO] USER = ${SERVER_USER} { \"userName\": \"${SERVER_USER}\" }"
echo "`date --rfc-3339=seconds` [INFO] SERVER = ${SERVER_NAME} { \"serverName\": \"${SERVER_NAME}\" }"
echo "`date --rfc-3339=seconds` [INFO] Switching to user 'minecraft' and starting."
exec sudo -E -u minecraft /start-minecraft "$@"
