#!/bin/bash

# Exit on error
set -e

echo "Starting Raspberry Pi Locker Management System Setup..."

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get install -y \
    python3-pip \
    python3-venv \
    chromium-browser \
    unclutter \
    git \
    sqlite3 \
    python3-lgpio

# Create project directory
echo "Setting up project directory..."
USER_HOME="$(eval echo ~$USER)"
PROJECT_DIR="$USER_HOME/raspberry_pi_locker_mangement_system"
if [ ! -d "$PROJECT_DIR" ]; then
    sudo mkdir -p $PROJECT_DIR
fi
cd $PROJECT_DIR

# Clone repository if not exists
if [ ! -d "raspberry_pi_locker_mangement_system" ]; then
    echo "Cloning project repository..."
    sudo git clone https://github.com/abenkorich/raspberry_pi_locker_mangement_system.git .
else
    echo "Project directory already exists, updating..."
    cd raspberry_pi_locker_mangement_system
    sudo git pull
fi

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Set up autostart
echo "Setting up autostart..."
mkdir -p $USER_HOME/.config/autostart
cp locker-kiosk.desktop $USER_HOME/.config/autostart/

# Make scripts executable
echo "Setting up executable permissions..."
chmod +x start_kiosk.sh

# Configure display settings
echo "Configuring display settings..."
# Disable screen blanking
sudo raspi-config nonint do_blanking 1

# Create systemd service for the Flask app
echo "Creating systemd service..."
sudo tee /etc/systemd/system/locker-system.service << EOF
[Unit]
Description=Locker Management System
After=network.target

[Service]
User=pi
WorkingDirectory=$USER_HOME/raspberry_pi_locker_mangement_system/raspberry_pi_locker_mangement_system
Environment="PATH=$USER_HOME/raspberry_pi_locker_mangement_system/raspberry_pi_locker_mangement_system/venv/bin"
ExecStart=$USER_HOME/raspberry_pi_locker_mangement_system/raspberry_pi_locker_mangement_system/venv/bin/python -m flask run --host=0.0.0.0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
echo "Enabling and starting services..."
sudo systemctl enable locker-system
sudo systemctl start locker-system

# Configure auto-login
echo "Configuring auto-login..."
sudo raspi-config nonint do_boot_behaviour B4

# Set up database
echo "Setting up database..."
cd raspberry_pi_locker_mangement_system
export FLASK_APP=app.py
flask shell << EOF
from app import db
db.create_all()
exit()
EOF

# Final setup
echo "Performing final setup..."
# Set correct permissions
sudo chown -R pi:pi $USER_HOME/raspberry_pi_locker_mangement_system

echo "Setup complete! Please reboot your Raspberry Pi."
echo "After reboot, the system will automatically start in kiosk mode."
echo "To reboot now, type: sudo reboot"

# Optional: Uncomment the following line to reboot automatically
# sudo reboot
