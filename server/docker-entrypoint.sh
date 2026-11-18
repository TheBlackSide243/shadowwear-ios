#!/bin/sh
# Started as root (the default): the data folder goes to the "node" user, who then runs the server.
# Started with another user (docker run --user, TrueNAS "user:"): that user must own the folder.
set -e
data="${DATA_DIR:-/data}"
if [ "$(id -u)" = "0" ]; then
  mkdir -p "$data"
  if [ "$(stat -c %u "$data")" != "$(id -u node)" ]; then
    chown -R node:node "$data"
  fi
  exec su-exec node "$@"
fi
exec "$@"
