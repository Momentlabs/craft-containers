#!/bin/bash

#only build if jar file does not exist
echo "`date --rfc-3339=seconds`:[INFO] Bungeecoord_init.sh: configuring enviornment."

if [ ! -f /$BUNGEECORD_HOME/BungeeCord.jar ]; then
  echo "[INFO] Downloading bungeecord jar file, be patient"
  mkdir -p /$BUNGEECORD_HOME/
  cd /$BUNGEECORD_HOME/
  wget http://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar

  #accept eola
  echo "eula=true" > /$BUNGEECORD_HOME/eula.txt

fi

# chance owner to minecraft
chown -R bungeecord.bungeecord /$BUNGEECORD_HOME/

cd /$BUNGEECORD_HOME/
echo "`date --rfc-3339=seconds`:[INFO] Starging BungeeCord server."
su - bungeecord -c 'java -Xms512M -Xmx1536M -jar BungeeCord.jar'

# 
# Do this all over again, simulating a restart.
# This enables a restart for rconfig purposes, and is
# not intended at all as a form of fault-tolerance.
# Alerts in the form of logs messags going out are a small,
# if insufficient step towards dealing with actual failure.
# TODO: split this into a the onetime setup that the Dockerfile calls
# and the restart the server command.
echo "`date --rfc-3339=seconds`:[INFO] Bungeecord STOPPED."
echo "`date --rfc-3339=seconds`:[INFO] Restarting bungee environment."
exec ./bungeecord_init.sh 