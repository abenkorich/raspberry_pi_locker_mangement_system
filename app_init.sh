#!/bin/bash

# Set project directory
PROJECT_DIR="locker-management"

# Create project directory structure
echo "Creating project directory structure..."
mkdir -p $PROJECT_DIR/{templates,static}

# Navigate to project directory
cd $PROJECT_DIR || exit

# Create Python backend file
echo "Creating app.py..."
cat << 'EOF' > app.py
from flask import Flask, render_template, request, redirect, url_for, session, jsonify
import RPi.GPIO as GPIO
import time
import sqlite3

app = Flask(__name__)
app.secret_key = 'your_secret_key'

# Initialize GPIO
GPIO.setmode(GPIO.BCM)

def setup_locker_pins():
    with sqlite3.connect('locker.db') as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT gpio_pin FROM lockers")
        pins = [row[0] for row in cursor.fetchall()]

    for pin in pins:
        GPIO.setup(pin, GPIO.OUT)
        GPIO.output(pin, GPIO.LOW)

def open_locker(locker_id):
    with sqlite3.connect('locker.db') as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT gpio_pin FROM lockers WHERE id = ?", (locker_id,))
        row = cursor.fetchone()
        if row:
            pin = row[0]
            GPIO.output(pin, GPIO.HIGH)
            time.sleep(3)
            GPIO.output(pin, GPIO.LOW)
            cursor.execute("UPDATE lockers SET status = 'unlocked' WHERE id = ?", (locker_id,))
            conn.commit()
            return True
    return False

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/admin', methods=['GET', 'POST'])
def admin():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        with sqlite3.connect('locker.db') as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM admin WHERE username = ? AND password = ?", (username, password))
            if cursor.fetchone():
                session['admin'] = True
                return redirect(url_for('admin_panel'))
        return render_template('admin.html', error="Invalid username or password.")
    return render_template('admin.html')

@app.route('/admin_panel')
def admin_panel():
    if 'admin' not in session:
        return redirect(url_for('admin'))
    with sqlite3.connect('locker.db') as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, gpio_pin, assigned_code, status FROM lockers")
        lockers = cursor.fetchall()
    return render_template('admin_panel.html', lockers=lockers)

@app.route('/open_locker', methods=['POST'])
def open_locker_api():
    locker_number = int(request.form.get('locker_number'))
    if open_locker(locker_number):
        return jsonify({'status': 'success', 'message': f'Locker {locker_number} opened.'})
    else:
        return jsonify({'status': 'error', 'message': 'Invalid locker number.'})

@app.route('/logout')
def logout():
    session.pop('admin', None)
    return redirect(url_for('home'))

if __name__ == '__main__':
    setup_locker_pins()
    app.run(host='0.0.0.0', port=5000)
EOF

# Create HTML templates
echo "Creating HTML templates..."
cat << 'EOF' > templates/index.html
<!DOCTYPE html>
<html>
<head>
  <title>Locker System - User</title>
</head>
<body>
  <h1>Locker Management System</h1>
  <form id="locker-form">
    <label for="locker-number">Enter Package Code:</label>
    <input type="number" id="locker-number" name="locker_number" required>
    <button type="submit">Open Locker</button>
  </form>
  <p id="message"></p>
  <script>
    document.getElementById('locker-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const lockerNumber = document.getElementById('locker-number').value;
      const response = await fetch('/open_locker', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `locker_number=${lockerNumber}`
      });
      const result = await response.json();
      document.getElementById('message').textContent = result.message;
    });
  </script>
</body>
</html>
EOF

cat << 'EOF' > templates/admin.html
<!DOCTYPE html>
<html>
<head>
  <title>Admin Login</title>
</head>
<body>
  <h1>Admin Login</h1>
  <form method="POST">
    <label for="username">Username:</label>
    <input type="text" id="username" name="username" required>
    <label for="password">Password:</label>
    <input type="password" id="password" name="password" required>
    <button type="submit">Login</button>
  </form>
  {% if error %}
  <p style="color: red;">{{ error }}</p>
  {% endif %}
</body>
</html>
EOF

cat << 'EOF' > templates/admin_panel.html
<!DOCTYPE html>
<html>
<head>
  <title>Admin Panel</title>
</head>
<body>
  <h1>Admin Panel</h1>
  <table>
    <tr>
      <th>ID</th>
      <th>GPIO Pin</th>
      <th>Assigned Code</th>
      <th>Status</th>
    </tr>
    {% for locker in lockers %}
    <tr>
      <td>{{ locker[0] }}</td>
      <td>{{ locker[1] }}</td>
      <td>{{ locker[2] }}</td>
      <td>{{ locker[3] }}</td>
    </tr>
    {% endfor %}
  </table>
  <a href="/logout">Logout</a>
</body>
</html>
EOF

# Create CSS file
echo "Creating styles.css..."
cat << 'EOF' > static/styles.css
body {
  font-family: Arial, sans-serif;
  text-align: center;
  padding: 20px;
}
EOF

# Create SQLite schema
echo "Creating database schema..."
cat << 'EOF' > schema.sql
CREATE TABLE lockers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    gpio_pin INTEGER NOT NULL,
    assigned_code TEXT NOT NULL,
    status TEXT DEFAULT 'locked'
);

CREATE TABLE admin (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
);

INSERT INTO admin (username, password) VALUES ('admin', 'admin123');
INSERT INTO lockers (gpio_pin, assigned_code) VALUES (5, 'ABC123');
INSERT INTO lockers (gpio_pin, assigned_code) VALUES (6, 'DEF456');
EOF

# Initialize SQLite database
echo "Initializing SQLite database..."
sqlite3 locker.db < schema.sql

echo "Project setup complete."
