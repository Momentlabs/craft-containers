FROM 033441544097.dkr.ecr.us-east-1.amazonaws.com/craft-base


MAINTAINER David Rivas david@momentlabs.io

# Provide the URL for the latest release version of cc.
# need a better way to compute env variables or something.
ARG craft_config_url

# ADD https://github.com/Momentlabs/craft-config/releases/download/v0.0.3/craft-config_linux_amd64 /usr/local/bin/craft-config
ADD ${craft_config_url} /usr/local/bin/craft-config
RUN chmod a+rx /usr/local/bin/craft-config

# This needs to be set to a username for things to work properly. 
# It's intended to be a valid minecraft user, but there is currently
# nothing that actually requires that, so any string will do. 
# It is currently used as the root of storage for worlds and backups.
ENV USER=


# This is what the parent expects.
WORKDIR /data
