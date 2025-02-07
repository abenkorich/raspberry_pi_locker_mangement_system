# Raspberry Pi Locker Management System

A smart locker management system built for Raspberry Pi 5, featuring an admin interface for configuration and a user interface for package retrieval.

## Features

- User Interface for package retrieval using unlock codes
- Admin Interface for locker configuration
- GPIO pin control for electronic locks
- SQLite database for persistent storage
- Dynamic locker matrix configuration
- Secure admin authentication

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Initialize the database:
```bash
python init_db.py
```

3. Run the application:
```bash
python app.py
```

## Default Admin Credentials
- Username: admin
- Password: admin123

Please change these credentials after first login.

## Hardware Requirements
- Raspberry Pi 5
- Electronic locks compatible with GPIO control
- Power supply for locks

## GPIO Pin Usage
The system allows configuration of GPIO pins through the admin interface. Make sure to use valid GPIO pins according to your Raspberry Pi 5 setup.
