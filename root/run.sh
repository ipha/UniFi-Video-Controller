#!/bin/bash

# Options fed into unifi-video script
unifi_video_opts=""

# Graceful shutdown, used by trapping SIGTERM
function graceful_shutdown {
  echo -n "Stopping unifi-video... " | ts '%Y-%m-%d %H:%M:%.S'
  if /usr/sbin/unifi-video --nodetach stop; then
    echo "done."
    exit 0
  else
    echo "failed."
    exit 1
  fi
}

# Trap SIGTERM for graceful exit
trap graceful_shutdown SIGTERM

# Create logs directory
mkdir -p /var/lib/unifi-video/logs

# check for presence of perms file, if it exists then skip setting
# permissions, otherwise recursively set on volume mappings for host
if [[ ! -f "/var/lib/unifi-video/perms.txt" ]]; then
  echo "[info] No perms.txt found, setting ownership and permissions recursively on videos." | ts '%Y-%m-%d %H:%M:%.S'

  volumes=( "/var/lib/unifi-video" )

  # Set user and group ownership of volumes.
  if ! chown -R unifi-video:unifi-video "${volumes[@]}"; then
    echo "[warn] Unable to chown ${volumes[*]}." | ts '%Y-%m-%d %H:%M:%.S'
  fi

  echo "This file prevents permissions from being applied/re-applied to /config, if you want to reset permissions then please delete this file and restart the container." > /var/lib/unifi-video/perms.txt
else
  echo "[info] File perms.txt blocks chown/chmod of videos." | ts '%Y-%m-%d %H:%M:%.S'
fi

# No debug mode set via env, default to off
if [[ -z ${DEBUG} ]]; then
  DEBUG=0
fi

# Run with --debug if DEBUG=1
if [[ ${DEBUG} -eq 1 ]]; then
  echo "[debug] Running unifi-video service with --debug." | ts '%Y-%m-%d %H:%M:%.S'
  unifi_video_opts="--debug"
fi

# Run the unifi-video daemon the unifi-video way
echo -n "Starting unifi-video... " | ts '%Y-%m-%d %H:%M:%.S'
if /usr/sbin/unifi-video "${unifi_video_opts}" start; then
  echo "done."
else
  echo "failed."
  exit 1
fi

# Wait for mongodb to come online.
echo -n "Waiting for mongodb to come online..." | ts '%Y-%m-%d %H:%M:%.S'
while ! mongo --quiet localhost:7441 --eval "{ ping: 1}" > /dev/null 2>&1; do
  sleep 2
  echo -n "."
done
echo " done."

# Get the current featureCompatibilityVersion
MONGO_FEATURE_COMPATIBILITY_VERSION=$( mongo --quiet --eval "db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )" localhost:7441 | jq -r .featureCompatibilityVersion.version )

# Update db to 3.4 features
if mongo --version 2>&1 | grep -q "v3.4"; then
  if [[ "${MONGO_FEATURE_COMPATIBILITY_VERSION}" != "3.4" ]]; then
    echo -n "Found FeatureCompatibilityVersion ${MONGO_FEATURE_COMPATIBILITY_VERSION}, setting to 3.4..." | ts '%Y-%m-%d %H:%M:%.S'
    if mongo --quiet --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "3.4" } )' localhost:7441 > /dev/null 2>&1; then
      echo " done."
    else
      echo " failed."
    fi
  fi
fi

# Update db to 3.6 features
if mongo --version 2>&1 | grep -q "v3.6"; then
  if [[ "${MONGO_FEATURE_COMPATIBILITY_VERSION}" != "3.6" ]]; then
    echo -n "Found FeatureCompatibilityVersion ${MONGO_FEATURE_COMPATIBILITY_VERSION}, setting to 3.6..." | ts '%Y-%m-%d %H:%M:%.S'
    if mongo --quiet --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "3.6" } )' localhost:7441 > /dev/null 2>&1; then
      echo " done."
    else
      echo " failed."
    fi
  fi
fi

# Update db to 4.0 features
if mongo --version 2>&1 | grep -q "v4.0"; then
  if [[ "${MONGO_FEATURE_COMPATIBILITY_VERSION}" != "4.0" ]]; then
    echo -n "Found FeatureCompatibilityVersion ${MONGO_FEATURE_COMPATIBILITY_VERSION}, setting to 4.0..." | ts '%Y-%m-%d %H:%M:%.S'
    if mongo --quiet --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "4.0" } )' localhost:7441 > /dev/null 2>&1; then
      echo " done."
    else
      echo " failed."
    fi
  fi
fi

# Loop while we wait for shutdown trap
while true; do
  # When --tmpfs is used, container restarts cause these folders to go missing.
  # See issue #178 for details.
  if [[ ! -d /var/cache/unifi-video/exports ]]; then
    echo -n "Re-creating and setting ownership/permissions on /var/cache/unifi-video/exports... "
    mkdir -p /var/cache/unifi-video/exports
    chown unifi-video:unifi-video /var/cache/unifi-video/exports
    chmod 700 /var/cache/unifi-video/exports
    echo "done."
  fi

  if [[ ! -d /var/cache/unifi-video/hls ]]; then
    echo -n "Re-creating and setting ownership/permissions on /var/cache/unifi-video/hls... "
    mkdir -p /var/cache/unifi-video/hls
    chown unifi-video:unifi-video /var/cache/unifi-video/hls
    chmod 775 /var/cache/unifi-video/hls
    echo "done."
  fi
  sleep 5
done
