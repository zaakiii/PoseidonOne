#!/system/bin/sh
if [ -f "/data/local/poseidon.lock" ]; then
  /data/local/lockdown.sh &
fi
