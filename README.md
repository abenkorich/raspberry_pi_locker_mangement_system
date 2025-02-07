# Raspberry Pi Locker Management System

A smart locker management system built for Raspberry Pi 5, featuring an admin interface for configuration and a user interface for package retrieval.

## Features

- User Interface for package retrieval using unlock codes
- Admin Interface for locker configuration
- GPIO pin control for electronic locks
- SQLite database for persistent storage
- Dynamic locker matrix configuration
- Secure admin authentication
- Auto-start in kiosk mode
- Touch-friendly interface

## Quick Setup

1. Download the setup script:
```bash
wget https://raw.githubusercontent.com/yourusername/rpi-locker-mgmt/main/raspberry_pi_locker_mangement_system/setup.sh
```

2. Make it executable:
```bash
chmod +x setup.sh
```

3. Run the setup script:
```bash
./setup.sh
```

The setup script will automatically:
- Install all required system dependencies
- Set up the Python virtual environment
- Configure the database
- Set up auto-start in kiosk mode
- Configure the display settings
- Create necessary system services

After the setup is complete, just reboot your Raspberry Pi and the system will start automatically.

## Manual Setup
If you prefer to set up manually, follow these steps:

1. Install system dependencies:
```bash
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv chromium-browser unclutter git sqlite3 python3-rpi.gpio
```

2. Clone the repository:
```bash
git clone https://github.com/yourusername/rpi-locker-mgmt.git
cd rpi-locker-mgmt
```

3. Create and activate virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

4. Install Python dependencies:
```bash
pip install -r requirements.txt
```

5. Initialize the database:
```bash
export FLASK_APP=app.py
flask shell
from app import db
db.create_all()
exit()
```

## Default Admin Credentials
- Username: admin
- Password: admin123

Please change these credentials after first login.

## Hardware Requirements
- Raspberry Pi 5
- Electronic locks compatible with GPIO control
- Power supply for locks
- Touch display (recommended)

## GPIO Pin Usage
The system allows configuration of GPIO pins through the admin interface. Make sure to use valid GPIO pins according to your Raspberry Pi 5 setup.

## Troubleshooting

If the system doesn't start automatically after reboot:
1. Check the service status:
```bash
sudo systemctl status locker-system
```

2. Check the logs:
```bash
journalctl -u locker-system
```

3. Make sure all permissions are correct:
```bash
sudo chown -R pi:pi /home/pi/rpi-locker-mgmt
