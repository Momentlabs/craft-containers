#!/bin/bash

function log {
  local mesg=$1
  local now=`date --rfc-3339=seconds`
  echo \{ \"serviceName\": \"craft-server\", \"operation\": \"startup\", \"file\": \"start-minecraft.sh\", \"logTime\": \"$now\", \"userName\": \"${SERVER_USER}\", \"serverName\": \"${SERVER_NAME}\", \"cluster\": \"${CLUSTER_NAME}\", \"serverType\": \"${TYPE}\", \"msg\": \"$mesg\" \}
}

#umask 002
export HOME=/data

if [ ! -e /data/eula.txt ]; then
  if [ "$EULA" != "" ]; then
    echo "# Generated via Docker on $(date)" > eula.txt
    echo "eula=$EULA" >> eula.txt
  else
    echo ""
    echo "Please accept the Minecraft EULA at"
    echo "  https://account.mojang.com/documents/minecraft_eula"
    echo "by adding the following immediately after 'docker run':"
    echo "  -e EULA=TRUE"
    echo ""
    exit 1
  fi
fi

VERSIONS_JSON=https://launchermeta.mojang.com/mc/game/version_manifest.json

log "Checking version information."
case "X$VERSION" in
  X|XLATEST|Xlatest)
    VANILLA_VERSION=`curl -sSL $VERSIONS_JSON | jq -r '.latest.release'`
  ;;
  XSNAPSHOT|Xsnapshot)
    VANILLA_VERSION=`curl -sSL $VERSIONS_JSON | jq -r '.latest.snapshot'`
  ;;
  X[1-9]*)
    VANILLA_VERSION=$VERSION
  ;;
  *)
    VANILLA_VERSION=`curl -sSL $VERSIONS_JSON | jq -r '.latest.release'`
  ;;
esac

cd /data

function buildSpigotFromSource {
  # echo "`date --rfc-3339=seconds` [INFO] Building Spigot $VANILLA_VERSION from source, might take a while, get some coffee"
  log "Building Spigot $VANILLA_VERSION from source, might take a while."  
  mkdir /data/temp
  cd /data/temp
  wget -q -P /data/temp https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar && \
    java -jar /data/temp/BuildTools.jar --rev $VANILLA_VERSION 2>&1 |tee /data/spigot_build.log| while read l; do echo -n .; done; echo "done"
  mv spigot-*.jar /data/spigot_server.jar
  mv craftbukkit-*.jar /data/craftbukkit_server.jar
  # echo "`date --rfc-3339=seconds` [INFO] Cleaning up"
  log "Cleaningup from Spigot build."
  rm -rf /data/temp
  cd /data
}

function downloadSpigot {
  local match
  case "$TYPE" in
    *BUKKIT|*bukkit)
      match="Craftbukkit"

      ;;
    *)
      match="Spigot"
      ;;
  esac
  # echo "[INFO] Looking for /tmp/$SERVER."
  log "Looking for /tmp/$SERVER"
  if [ -e /tmp/$SERVER ]; then
    # echo "[INFO] $SERVER already in place will not download."
    # echo "[INFO] Copying $SERVER"
    log "$SERVER already in place will not download."
    log "Copying $SERVER."
    cp /tmp/$SERVER $SERVER
    # echo "[INFO] Copying spigot.yml"
    log "Copying spigot.yml"
    cp /tmp/spigot.yml spigot.yml
    # echo "[INFO] Copying server.properties"
    # cp /tmp/server.properties server.properties
    # echo "[INFO] Copying bukkit.yml"
    log "Copying bukkit.yml"
    cp /tmp/bukkit.yml bukkit.yml
  else 
    # echo "[INFO] can't find server, so trying to download."
    log "Can't find server, so trying to download."
    downloadUrl=$(restify --class=jar-div https://mcadmin.net/ | \
      jq --arg version "$match $VANILLA_VERSION" -r -f /usr/share/mcadmin.jq)
    if [[ -n $downloadUrl ]]; then
      wget -q -O $SERVER "$downloadUrl"
      status=$?
      if [ $status != 0 ]; then
        # echo "`date --rfc-3339=seconds` [INFO] [ERROR]: failed to download from $downloadUrl due to (error code was $status)"
        log "[ERROR] failed to download from $downloadUrl: $status"
        exit 3
      fi      
    else
      # echo "`date --rfc-3339=seconds` [INFO] [ERROR]: Version $VANILLA_VERSION is not supported for $TYPE"
      # echo "`date --rfc-3339=seconds` [INFO]        Refer to https://mcadmin.net/ for supported versions"
      log "ERROR: Version $VANILLA_VERSION is not supported for $TYPE"
      exit 2
    fi
  fi
}

function downloadPaper {
  local build
  case "$VERSION" in
    latest|LATEST|1.10)
      build="lastSuccessfulBuild";;
    1.9.4)
      build="773";;
    1.9.2)
      build="727";;
    1.9)
      build="612";;
    1.8.8)
      build="443";;
    *)
      build="nosupp";;
  esac

  if [ $build != "nosupp" ]; then
    downloadUrl="https://ci.destroystokyo.com/job/PaperSpigot/$build/artifact/paperclip.jar"
    wget -q -O $SERVER "$downloadUrl"
    status=$?
    if [ $status != 0 ]; then
      # echo "`date --rfc-3339=seconds` [INFO] ERROR: failed to download from $downloadUrl due to (error code was $status)"
      log "ERROR: failed to download from $downloadUrl: $status"
      exit 3
    fi
  else
    # echo "`date --rfc-3339=seconds` [INFO] ERROR: Version $VERSION is not supported for $TYPE"
    # echo "`date --rfc-3339=seconds` [INFO]        Refer to https://ci.destroystokyo.com/job/PaperSpigot/"
    # echo "`date --rfc-3339=seconds` [INFO]        for supported versions"
    log "ERROR Version $VERSION is not supported for $TYPE"
    exit 2
  fi
}

function installForge {
  TYPE=FORGE
  norm=$VANILLA_VERSION

  # echo "`date --rfc-3339=seconds` [INFO] Checking Forge version information."
  log "Checking Forge for version infomration."
  case $FORGEVERSION in
    RECOMMENDED)
      curl -o /tmp/forge.json -sSL http://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json
      FORGE_VERSION=$(cat /tmp/forge.json | jq -r ".promos[\"$norm-recommended\"]")
      if [ $FORGE_VERSION = null ]; then
        FORGE_VERSION=$(cat /tmp/forge.json | jq -r ".promos[\"$norm-latest\"]")
        if [ $FORGE_VERSION = null ]; then
          echo "`date --rfc-3339=seconds` [INFO] ERROR: Version $FORGE_VERSION is not supported by Forge"
          echo "`date --rfc-3339=seconds` [INFO]        Refer to http://files.minecraftforge.net/ for supported versions"
          exit 2
        fi
      fi
      ;;

    *)
      FORGE_VERSION=$FORGEVERSION
      ;;
  esac

  # URL format changed for 1.7.10 from 10.13.2.1300
  sorted=$((echo $FORGE_VERSION; echo 10.13.2.1300) | sort -V | head -1)
  if [[ $norm == '1.7.10' && $sorted == '10.13.2.1300' ]]; then
      # if $FORGEVERSION >= 10.13.2.1300
      normForgeVersion="$norm-$FORGE_VERSION-$norm"
  else
      normForgeVersion="$norm-$FORGE_VERSION"
  fi

  FORGE_INSTALLER="forge-$normForgeVersion-installer.jar"
  SERVER="forge-$normForgeVersion-universal.jar"

  if [ ! -e "$SERVER" ]; then
    # echo "`date --rfc-3339=seconds` [INFO] Downloading $FORGE_INSTALLER ..."
    log "Downloading $FORGE_INSTALLER"
    wget -q http://files.minecraftforge.net/maven/net/minecraftforge/forge/$normForgeVersion/$FORGE_INSTALLER
    # echo "`date --rfc-3339=seconds` [INFO] Installing $SERVER"
    log "Installing $SERVER"
    java -jar $FORGE_INSTALLER --installServer
  fi
}

function installVanilla {
  SERVER="minecraft_server.$VANILLA_VERSION.jar"

  if [ ! -e $SERVER ]; then
    # echo "`date --rfc-3339=seconds` [INFO] Downloading $SERVER ..."
    log "Downloading $SERVER"
    wget -q https://s3.amazonaws.com/Minecraft.Download/versions/$VANILLA_VERSION/$SERVER
  fi
}

# echo "`date --rfc-3339=seconds` [INFO] Checking type information."
log "Checking type information."
case "$TYPE" in
  *BUKKIT|*bukkit|SPIGOT|spigot)
    case "$TYPE" in
      *BUKKIT|*bukkit)
        SERVER=craftbukkit_server.jar
        ;;
      *)
        SERVER=spigot_server.jar
        ;;
    esac

    if [ ! -f $SERVER ]; then
       if [[ "$BUILD_SPIGOT_FROM_SOURCE" = TRUE || "$BUILD_SPIGOT_FROM_SOURCE" = true || "$BUILD_FROM_SOURCE" = TRUE || "$BUILD_FROM_SOURCE" = true ]]; then
         buildSpigotFromSource
       else
         downloadSpigot
       fi
    fi
    # normalize on Spigot for operations below
    TYPE=SPIGOT
  ;;

  PAPER|paper)
    SERVER=paper_server.jar
    if [ ! -f $SERVER ]; then
      downloadPaper
    fi
    # normalize on Spigot for operations below
    TYPE=SPIGOT
  ;;
  
  FORGE|forge)
    TYPE=FORGE
    installForge
  ;;

  VANILLA|vanilla)
    installVanilla
  ;;

  *)
      # echo "`date --rfc-3339=seconds` [INFO] Invalid type: '$TYPE'"
      log "Invalide type: $TYPE. Must be one of: VANNILLA, FORGE SPIGOT"
      # echo "`date --rfc-3339=seconds` [INFO] Must be: VANILLA, FORGE, SPIGOT"
      exit 1
  ;;

esac

# echo "`date --rfc-3339=seconds` [INFO] Using $TYPE"
log "Using $TYPE"

# If supplied with a URL for a world, download it and unpack
if [[ "$WORLD" ]]; then
case "X$WORLD" in
  X[Hh][Tt][Tt][Pp]*)
    # echo "`date --rfc-3339=seconds` [INFO] Downloading world via HTTP"
    # echo "`date --rfc-3339=seconds` [INFO] $WORLD"
    log "Downloading $WORLD via HTTP"
    wget -q -O - "$WORLD" > /data/world.zip
    # echo "`date --rfc-3339=seconds` [INFO] Unzipping word"
    log "Unzipping world: $WORLD"
    unzip -q /data/world.zip
    rm -f /data/world.zip
    if [ ! -d /data/world ]; then
      # echo `date --rfc-3339=seconds` [INFO] World directory not found
      log "World directory not found."
      for i in /data/*/level.dat; do
        if [ -f "$i" ]; then
          d=`dirname "$i"`
          # echo [INFO] Renaming world directory from $d
          log "Renaming world directory from $d to /data/world"
          mv -f "$d" /data/world
        fi
      done
    fi
    if [ "$TYPE" = "SPIGOT" ]; then
      # Reorganise if a Spigot server
      # echo "[INFO] Moving End and Nether maps to Spigot location"
      log "Moving End and Nether maps to Spigot location."
      [ -d "/data/world/DIM1" ] && mv -f "/data/world/DIM1" "/data/world_the_end"
      [ -d "/data/world/DIM-1" ] && mv -f "/data/world/DIM-1" "/data/world_nether"
    fi
    ;;
  *)
    # echo "`date --rfc-3339=seconds` [INFO] Invalid URL given for world: Must be HTTP or HTTPS and a ZIP file"
    log "Invalid URL given for world: Must be HTTP or HTTPS and a ZIP file."
    ;;
esac
fi

# If supplied with a URL for a modpack (simple zip of jars), download it and unpack
if [[ "$MODPACK" ]]; then
case "X$MODPACK" in
  X[Hh][Tt][Tt][Pp]*[Zz][iI][pP])
    # echo "`date --rfc-3339=seconds` [INFO] Downloading mod/plugin pack via HTTP"
    # echo "`date --rfc-3339=seconds` [INFO] $MODPACK"
    log "Downloading mod/plugin pack via HTTP: $MODPACK"
    wget -q -O /tmp/modpack.zip "$MODPACK"
    if [ "$TYPE" = "SPIGOT" ]; then
      mkdir -p /data/plugins
      unzip -o -d /data/plugins /tmp/modpack.zip
    else
      mkdir -p /data/mods
      unzip -o -d /data/mods /tmp/modpack.zip
    fi
    rm -f /tmp/modpack.zip
    ;;
  *)
    # echo "`date --rfc-3339=seconds` [INFO] Invalid URL given for modpack: Must be HTTP or HTTPS and a ZIP file"
    log "Invalid URL given for modpack: Must be HTTP or HTTPS and a ZIP file."
    ;;
esac
fi


function setServerProp {
  local prop=$1
  local var=$2
  if [ -n "$var" ]; then
    # echo "`date --rfc-3339=seconds` [INFO] Setting $prop to $var"
    log "Setting $prop to $var"
    sed -i "/$prop\s*=/ c $prop=$var" /data/server.properties
  fi

}

if [ ! -e server.properties ]; then
  # echo "`date --rfc-3339=seconds` [INFO] Creating server.properties"
  log "Creating server.properties."
  cp /tmp/server.properties .

  if [ -n "$WHITELIST" ]; then
    # echo "`date --rfc-3339=seconds` [INFO] Creating whitelist"
    log "Creating whitelist."
    sed -i "/whitelist\s*=/ c whitelist=true" /data/server.properties
    sed -i "/white-list\s*=/ c white-list=true" /data/server.properties
  fi

  setServerProp "motd" "$MOTD"
  setServerProp "allow-nether" "$ALLOW_NETHER"
  setServerProp "announce-player-achievements" "$ANNOUNCE_PLAYER_ACHIEVEMENTS"
  setServerProp "enable-command-block" "$ENABLE_COMMAND_BLOCK"
  setServerProp "spawn-animals" "$SPAWN_ANIMAILS"
  setServerProp "spawn-monsters" "$SPAWN_MONSTERS"
  setServerProp "spawn-npcs" "$SPAWN_NPCS"
  setServerProp "generate-structures" "$GENERATE_STRUCTURES"
  setServerProp "spawn-npcs" "$SPAWN_NPCS"
  setServerProp "view-distance" "$VIEW_DISTANCE"
  setServerProp "hardcore" "$HARDCORE"
  setServerProp "max-build-height" "$MAX_BUILD_HEIGHT"
  setServerProp "force-gamemode" "$FORCE_GAMEMODE"
  setServerProp "hardmax-tick-timecore" "$MAX_TICK_TIME"
  setServerProp "enable-query" "$ENABLE_QUERY"
  setServerProp "query.port" "$QUERY_PORT"
  setServerProp "enable-rcon" "$ENABLE_RCON"
  setServerProp "rcon.password" "$RCON_PASSWORD"
  setServerProp "rcon.port" "$RCON_PORT"
  setServerProp "max-players" "$MAX_PLAYERS"
  setServerProp "max-world-size" "$MAX_WORLD_SIZE"
  setServerProp "level-name" "$LEVEL"
  setServerProp "level-seed" "$SEED"
  setServerProp "pvp" "$PVP"
  setServerProp "generator-settings" "$GENERATOR_SETTINGS"
  setServerProp "online-mode" "$ONLINE_MODE"
  setServerProp "server-ip" ""

  if [ -n "$LEVEL_TYPE" ]; then
    # normalize to uppercase
    LEVEL_TYPE=${LEVEL_TYPE^^}
    # echo "`date --rfc-3339=seconds` [INFO] Setting level type to $LEVEL_TYPE"
    log "Setting level type to $LEVEL_TYPE"
    # check for valid values and only then set
    case $LEVEL_TYPE in
      DEFAULT|FLAT|LARGEBIOMES|AMPLIFIED|CUSTOMIZED)
        sed -i "/level-type\s*=/ c level-type=$LEVEL_TYPE" /data/server.properties
        ;;
      *)
        # echo "`date --rfc-3339=seconds` [INFO] Invalid LEVEL_TYPE: $LEVEL_TYPE"
        log "Invalid LEVEL_TYPE: $LEVEL_TYPE"
	exit 1
	;;
    esac
  fi

  if [ -n "$DIFFICULTY" ]; then
    case $DIFFICULTY in
      peaceful|0)
        DIFFICULTY=0
        ;;
      easy|1)
        DIFFICULTY=1
        ;;
      normal|2)
        DIFFICULTY=2
        ;;
      hard|3)
        DIFFICULTY=3
        ;;
      *)
        # echo "`date --rfc-3339=seconds` [INFO] DIFFICULTY must be peaceful, easy, normal, or hard."
        log "DIFFICULTY must be peacful, easy, normal or hard: $DIFFICULTY"
        exit 1
        ;;
    esac
    # echo "`date --rfc-3339=seconds` [INFO] Setting difficulty to $DIFFICULTY"
    log "Setting difficulty to $DIFFICULTY"
    sed -i "/difficulty\s*=/ c difficulty=$DIFFICULTY" /data/server.properties
  fi

  if [ -n "$MODE" ]; then
    # echo "`date --rfc-3339=seconds` [INFO] Setting mode"
    log "Setting gamemode to $MODE"
    case ${MODE,,?} in
      0|1|2|3)
        ;;
      s*)
        MODE=0
        ;;
      c*)
        MODE=1
        ;;
      a*)
        MODE=2
        ;;
      s*)
        MODE=3
        ;;
      *)
        # echo "`date --rfc-3339=seconds` [INFO] ERROR: Invalid game mode: $MODE"
        log "ERROR Invalid game mode: $MODE"
        exit 1
        ;;
    esac

    sed -i "/gamemode\s*=/ c gamemode=$MODE" /data/server.properties
  fi
fi


if [ -n "$OPS" -a ! -e ops.txt.converted ]; then
  # echo "`date --rfc-3339=seconds` [INFO] Setting ops"
  log "Setting ops: $OPS"
  echo $OPS | awk -v RS=, '{print}' >> ops.txt
fi

if [ -n "$WHITELIST" -a ! -e white-list.txt.converted ]; then
  # echo "`date --rfc-3339=seconds` [INFO] Setting whitelist"
  log "Setting whitelist: $WHITLIST"
  echo $WHITELIST | awk -v RS=, '{print}' >> white-list.txt
fi

if [ -n "$ICON" -a ! -e server-icon.png ]; then
  # echo "`date --rfc-3339=seconds` [INFO] Using server icon from $ICON..."
  log "Setting server icon from: $ICON"
  # Not sure what it is yet...call it "img"
  wget -q -O /tmp/icon.img $ICON
  specs=$(identify /tmp/icon.img | awk '{print $2,$3}')
  if [ "$specs" = "PNG 64x64" ]; then
    mv /tmp/icon.img /data/server-icon.png
  else
    # echo "`date --rfc-3339=seconds` [INFO] Converting image to 64x64 PNG..."
    log "Converting icon iamge to 64x64"
    convert /tmp/icon.img -resize 64x64! /data/server-icon.png
  fi
fi

# Make sure files exist to avoid errors
if [ ! -e banned-players.json ]; then
	echo '' > banned-players.json
fi
if [ ! -e banned-ips.json ]; then
	echo '' > banned-ips.json
fi

# If any modules have been provided, copy them over
[ -d /data/mods ] || mkdir /data/mods
for m in /mods/*.jar
do
  if [ -f "$m" ]; then
    # echo `date --rfc-3339=seconds` [INFO] Copying mod `basename "$m"`
    cp -f "$m" /data/mods
  fi
done
[ -d /data/config ] || mkdir /data/config
for c in /config/*
do
  if [ -f "$c" ]; then
    # echo `date --rfc-3339=seconds` [INFO] Copying configuration `basename "$c"`
    cp -rf "$c" /data/config
  fi
done

if [ "$TYPE" = "SPIGOT" ]; then
  if [ -d /plugins ]; then
    # echo `date --rfc-3339=seconds` [INFO] Copying any Bukkit plugins over
    log Copying any Bukkit plugins over.
    cp -r /plugins /data
  fi
fi


# Get the log configuration file in place.
if [ -e /tmp/log4j2.xml ]; then
  # echo `date --rfc-3339=seconds` [INFO] Copying log configuration file log4j2.xml
  log "Copying log configuration to file log4j2.xml"
  cp /tmp/log4j2.xml /data
  # echo `date --rfc-3339=seconds` [INFO] adding log4j2.xml to $SERVER
  log "adding log4j2.xml to $SERVER"
  jar -uf $SERVER log4j2.xml
fi

# If we have a bootstrap.txt file... feed that in to the server stdin
if [ -f /data/bootstrap.txt ];
then
    echo "`date --rfc-3339=seconds` [INFO] Starting server: java $JVM_OPTS -jar $SERVER $@ < /data/bootstrap.txt"
    exec java $JVM_OPTS -jar $SERVER "$@" < /data/bootstrap.txt
else
    # echo "`date --rfc-3339=seconds` [INFO] Starting server: java $JVM_OPTS -jar $SERVER $@"
    log "Starting server: java $JVM_OPTS $SERVER $@"
    exec java $JVM_OPTS -jar $SERVER "$@"
fi
