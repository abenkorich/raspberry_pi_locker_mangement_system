#!/bin/bash

# Exit on error
set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get the actual user who called sudo
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)
echo "Setting up for user: $ACTUAL_USER"
echo "User home directory: $USER_HOME"

echo "Starting Raspberry Pi Locker Management System Setup..."

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install system dependencies
echo "Installing system dependencies..."
apt-get install -y \
    python3-pip \
    python3-venv \
    chromium-browser \
    unclutter \
    git \
    sqlite3 \
    python3-rpi.gpio

# Create project directory
echo "Setting up project directory..."
PROJECT_DIR="$USER_HOME/raspberry_pi_locker_mangement_system"
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p $PROJECT_DIR
    chown $ACTUAL_USER:$ACTUAL_USER $PROJECT_DIR
fi

# Switch to the actual user for git operations
echo "Cloning/updating repository..."
cd $PROJECT_DIR
if [ ! -d ".git" ]; then
    su - $ACTUAL_USER -c "git clone https://github.com/abenkorich/raspberry_pi_locker_mangement_system.git $PROJECT_DIR"
else
    su - $ACTUAL_USER -c "cd $PROJECT_DIR && git pull"
fi

# Set up Python virtual environment as the actual user
echo "Setting up Python virtual environment..."
su - $ACTUAL_USER -c "cd $PROJECT_DIR && python3 -m venv venv"
su - $ACTUAL_USER -c "cd $PROJECT_DIR && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

# Set up autostart directory
echo "Setting up autostart..."
AUTOSTART_DIR="$USER_HOME/.config/autostart"
mkdir -p $AUTOSTART_DIR
chown -R $ACTUAL_USER:$ACTUAL_USER $USER_HOME/.config

# Copy and configure autostart file
cp $PROJECT_DIR/locker-kiosk.desktop $AUTOSTART_DIR/
chown $ACTUAL_USER:$ACTUAL_USER $AUTOSTART_DIR/locker-kiosk.desktop
chmod 644 $AUTOSTART_DIR/locker-kiosk.desktop

# Make scripts executable
echo "Setting up executable permissions..."
chmod +x $PROJECT_DIR/start_kiosk.sh
chown $ACTUAL_USER:$ACTUAL_USER $PROJECT_DIR/start_kiosk.sh

# Configure display settings
echo "Configuring display settings..."
raspi-config nonint do_blanking 1

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/locker-system.service << EOF
[Unit]
Description=Locker Management System
After=network.target

[Service]
User=$ACTUAL_USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
ExecStart=$PROJECT_DIR/venv/bin/python -m flask run --host=0.0.0.0

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions for service file
chmod 644 /etc/systemd/system/locker-system.service

# Enable and start the service
echo "Enabling and starting services..."
systemctl enable locker-system
systemctl start locker-system

# Configure auto-login
echo "Configuring auto-login..."
raspi-config nonint do_boot_behaviour B4

# Set up database as the actual user
echo "Setting up database..."
su - $ACTUAL_USER -c "cd $PROJECT_DIR && \
    source venv/bin/activate && \
    export FLASK_APP=app.py && \
    flask shell << EOF
from app import db
db.create_all()
exit()
EOF"

# Final setup
echo "Performing final setup..."
# Set correct permissions for the entire project
chown -R $ACTUAL_USER:$ACTUAL_USER $PROJECT_DIR

echo "Setup complete! Please reboot your Raspberry Pi."
echo "After reboot, the system will automatically start in kiosk mode."
echo "To reboot now, type: sudo reboot"

# Optional: Uncomment the following line to reboot automatically
# sudo reboot
