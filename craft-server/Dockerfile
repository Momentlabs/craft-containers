FROM 033441544097.dkr.ecr.us-east-1.amazonaws.com/craft-controller

MAINTAINER David Rivas david@momentlabs.io

EXPOSE 25565 25575

COPY artifacts/start.sh /start
COPY artifacts/start-minecraft.sh /start-minecraft
COPY artifacts/mcadmin.jq /usr/share
RUN chmod +x /usr/local/bin/*

VOLUME ["/data","/mods","/config","/plugins","/home/minecraft"]

COPY artifacts/server.properties /tmp/server.properties
COPY artifacts/jars/spigot_server.jar /tmp/spigot_server.jar
COPY artifacts/spigot.yml /tmp/spigot.yml
COPY artifacts/bukkit.yml /tmp/bukkit.yml
COPY artifacts/log4j2.xml /tmp/log4j2.xml
# Can't seem to get this to work right, so back to XML.
# COPY artifacts/log4j2.yml /tmp/log4j2.yml 

WORKDIR /data

ENTRYPOINT [ "/start" ]

ENV UID=1000 GID=1000 \
    MOTD="A Minecraft Server Powered by Docker" \
    JVM_OPTS="-Xmx1024M -Xms1024M -Dlog4j.configurationFile=log4j2.xml" \
    TYPE=VANILLA VERSION=LATEST FORGEVERSION=RECOMMENDED LEVEL=world PVP=false DIFFICULTY=easy \
    LEVEL_TYPE=DEFAULT GENERATOR_SETTINGS= WORLD= MODPACK= ONLINE_MODE=TRUE
