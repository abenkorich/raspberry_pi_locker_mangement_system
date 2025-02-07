from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
import RPi.GPIO as GPIO
from models import db, User, Locker, Configuration, GPIOConfig
import random
import string
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = os.urandom(24)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///locker_system.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize extensions
db.init_app(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# GPIO Setup
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

def setup_gpio():
    # Get all allocated GPIO pins
    allocated_configs = GPIOConfig.query.filter_by(is_allocated=True).all()
    for config in allocated_configs:
        try:
            GPIO.setup(config.pin_number, GPIO.OUT)
            GPIO.output(config.pin_number, GPIO.HIGH)  # Locks are typically active-low
        except Exception as e:
            print(f"Error setting up GPIO pin {config.pin_number}: {str(e)}")

def generate_unlock_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/admin')
@login_required
def admin():
    config = Configuration.query.first()
    lockers = Locker.query.all()
    locker_list = [{
        'id': locker.id,
        'row': locker.row,
        'column': locker.column,
        'gpio_pin': locker.gpio_config.pin_number if locker.gpio_config else None,
        'unlock_code': locker.unlock_code,
        'is_occupied': locker.is_occupied
    } for locker in lockers]
    return render_template('admin.html', config=config, lockers=locker_list)

@app.route('/api/configure', methods=['POST'])
@login_required
def configure():
    data = request.json
    config = Configuration.query.first()
    if not config:
        config = Configuration()
        db.session.add(config)
    
    config.rows = data['rows']
    config.columns = data['columns']
    db.session.commit()
    
    return jsonify({'success': True})

@app.route('/api/locker/configure', methods=['POST'])
@login_required
def configure_locker():
    data = request.json
    
    try:
        if data.get('id'):  # Update existing locker
            locker = Locker.query.get(data['id'])
            if not locker:
                return jsonify({'success': False, 'message': 'Locker not found'})
        else:  # Create new locker
            existing_locker = Locker.query.filter_by(
                row=data['row'],
                column=data['column']
            ).first()
            
            if existing_locker:
                locker = existing_locker
            else:
                locker = Locker(
                    row=data['row'],
                    column=data['column']
                )
                db.session.add(locker)
        
        # Handle GPIO configuration
        if 'gpio_pin' in data:
            # Remove old GPIO configuration if it exists
            if locker.gpio_config:
                old_config = locker.gpio_config
                old_config.is_allocated = False
                old_config.locker_id = None
                try:
                    GPIO.cleanup(old_config.pin_number)
                except:
                    pass
            
            if data['gpio_pin']:
                # Get and allocate new GPIO pin
                gpio_config = GPIOConfig.query.filter_by(pin_number=data['gpio_pin']).first()
                if not gpio_config:
                    return jsonify({'success': False, 'message': 'Invalid GPIO pin'})
                
                if gpio_config.is_allocated and gpio_config.locker_id != locker.id:
                    return jsonify({'success': False, 'message': 'GPIO pin already allocated'})
                
                gpio_config.is_allocated = True
                gpio_config.locker_id = locker.id
                
                try:
                    GPIO.setup(gpio_config.pin_number, GPIO.OUT)
                    GPIO.output(gpio_config.pin_number, GPIO.HIGH)
                except Exception as e:
                    return jsonify({'success': False, 'message': f'Failed to setup GPIO pin: {str(e)}'})
        
        if 'generate_code' in data and data['generate_code']:
            locker.unlock_code = generate_unlock_code()
        
        db.session.commit()
        return jsonify({
            'success': True,
            'unlock_code': locker.unlock_code,
            'id': locker.id
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)})

@app.route('/unlock', methods=['POST'])
def unlock():
    code = request.form.get('code')
    locker = Locker.query.filter_by(unlock_code=code).first()
    
    if not locker or not locker.gpio_config:
        return jsonify({'success': False, 'message': 'Invalid code'})
    
    try:
        GPIO.output(locker.gpio_config.pin_number, GPIO.LOW)  # Unlock
        import time
        time.sleep(5)  # Keep unlocked for 5 seconds
        GPIO.output(locker.gpio_config.pin_number, GPIO.HIGH)  # Lock
        return jsonify({'success': True, 'message': f'Locker {locker.row}-{locker.column} unlocked'})
    except Exception as e:
        return jsonify({'success': False, 'message': f'Failed to control locker: {str(e)}'})

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        user = User.query.filter_by(username=request.form['username']).first()
        if user and user.check_password(request.form['password']):
            login_user(user)
            return redirect(url_for('admin'))
        flash('Invalid username or password')
    return render_template('login.html')

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        # Initialize GPIO pin configurations
        GPIOConfig.initialize_pins()
        # Create default admin user if not exists
        if not User.query.filter_by(username='admin').first():
            admin = User(username='admin')
            admin.set_password('admin123')
            db.session.add(admin)
            db.session.commit()
    
    setup_gpio()
    app.run(host='0.0.0.0', port=5000, debug=True)
