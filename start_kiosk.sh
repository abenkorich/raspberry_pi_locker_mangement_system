#!/bin/bash

# Wait for network
sleep 10

# Start Flask app in background
cd /home/pi/rpi-locker-mgmt/raspberry_pi_locker_mangement_system
export FLASK_APP=app.py
python3 -m flask run --host=0.0.0.0 &

# Wait for Flask to start
sleep 5

# Start Chromium in kiosk mode
chromium-browser --kiosk --start-fullscreen --start-maximized --disable-infobars --noerrdialogs --disable-translate --no-first-run --fast --fast-start --disable-features=TranslateUI --disk-cache-dir=/dev/null  http://localhost:5000
