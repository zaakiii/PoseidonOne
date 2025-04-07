#!/system/bin/sh

# ==== CONFIGURATION ====
DURATION=1800                  # 30 minutes (adjustable)
LOCK_FILE="/data/local/poseidon.lock"
END_TIME_FILE="/data/local/poseidon_end_time"
HTML_TEMPLATE="/data/local/poseidon.html"
OVERLAY_HTML="/data/local/overlay.html"
LAUNCHER_PKG="com.android.launcher3"  # Replace with your launcher
USB_OTG_PATH="/sys/devices/virtual/host_notify/usb_otg/uevent"

# ==== FUNCTIONS ====
disable_components() {
  pm disable "$LAUNCHER_PKG" >/dev/null 2>&1  # Block launcher
  input keyevent POWER                        # Turn screen off
}

enable_components() {
  pm enable "$LAUNCHER_PKG" >/dev/null 2>&1   # Restore launcher
}

show_overlay() {
  END_TIME=$(cat "$END_TIME_FILE")
  sed "s/<%=END_TIME%>/$END_TIME/" "$HTML_TEMPLATE" > "$OVERLAY_HTML"
  su -c "am start -n com.android.htmlviewer/.HTMLViewerActivity -d file://$OVERLAY_HTML --ez fullscreen true --activity-clear-task"
  su -c "am broadcast -a android.speech.tts.ENGINE_CHANGE --es text 'Poseidon One Initialized. Lockdown active.'"
}

intercept_power() {
  while true; do
    getevent -l /dev/input/event1 | while read line; do
      if echo "$line" | grep -q "KEY_POWER"; then
        input keyevent POWER  # Toggle screen
        show_overlay          # Force overlay
      fi
    done
    sleep 0.1
  done
}

cleanup() {
  enable_components
  rm -f "$LOCK_FILE" "$END_TIME_FILE" "$OVERLAY_HTML"
  su -c "am force-stop com.android.htmlviewer"  # Close overlay
  killall getevent 2>/dev/null                  # Stop interception
  exit 0
}

# ==== MAIN LOGIC ====
if [ -f "$LOCK_FILE" ]; then
  CURRENT_TIME=$(date +%s)
  END_TIME=$(cat "$END_TIME_FILE" 2>/dev/null || echo 0)
  if [ "$CURRENT_TIME" -ge "$END_TIME" ] || grep -q "STATE=ADD" "$USB_OTG_PATH"; then
    cleanup
  fi
  exit 0
fi

touch "$LOCK_FILE"
echo $(($(date +%s) + DURATION)) > "$END_TIME_FILE"
disable_components
show_overlay
intercept_power &

# Block shutdown menu
while true; do
  su -c "service call statusbar 2"                # Collapse status bar
  su -c "settings put global policy_control immersive.full=*"  # Hide system UI
  sleep 0.5
done
