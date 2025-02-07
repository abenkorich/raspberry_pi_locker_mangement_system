from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
import lgpio
from models import db, User, Locker, Configuration
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

# Initialize GPIO
h = lgpio.gpiochip_open(0)
active_pins = []

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

def generate_unlock_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

def setup_gpio():
    for pin in active_pins:
        lgpio.gpio_claim_output(h, pin)
        lgpio.gpio_write(h, pin, 1)  # Initialize to locked state

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
        'gpio_pin': locker.gpio_pin,
        'unlock_code': locker.unlock_code,
        'is_occupied': locker.is_occupied
    } for locker in lockers]
    return render_template('admin.html', config=config, lockers=locker_list)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        user = User.query.filter_by(username=request.form['username']).first()
        if user and user.check_password(request.form['password']):
            login_user(user)
            return redirect(url_for('admin'))
        flash('Invalid username or password')
    return render_template('login.html')

@app.route('/unlock', methods=['POST'])
def unlock():
    code = request.form.get('code')
    if not code:
        return jsonify({'success': False, 'message': 'No code provided'})
    
    locker = Locker.query.filter_by(unlock_code=code).first()
    if not locker:
        return jsonify({'success': False, 'message': 'Invalid code'})
    
    if locker.gpio_pin:
        lgpio.gpio_claim_output(h, locker.gpio_pin)
        lgpio.gpio_write(h, locker.gpio_pin, 0)  # Unlock
        import time
        time.sleep(2)  # Keep unlocked for 2 seconds
        lgpio.gpio_write(h, locker.gpio_pin, 1)  # Lock
    
    return jsonify({'success': True, 'message': f'Locker {locker.row}-{locker.column} unlocked'})

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
            # Check if a locker already exists at this position
            existing_locker = Locker.query.filter_by(
                row=data['row'],
                column=data['column']
            ).first()
            
            if existing_locker:
                locker = existing_locker
            else:
                locker = Locker()
                
        # Update locker properties
        locker.row = data['row']
        locker.column = data['column']
        locker.gpio_pin = data['gpio_pin']
        locker.unlock_code = data['unlock_code']
        locker.is_occupied = bool(data['is_occupied'])
        
        db.session.add(locker)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'locker': {
                'id': locker.id,
                'row': locker.row,
                'column': locker.column,
                'gpio_pin': locker.gpio_pin,
                'unlock_code': locker.unlock_code,
                'is_occupied': locker.is_occupied
            }
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Error configuring locker: {str(e)}'})

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        # Create default admin user if not exists
        if not User.query.filter_by(username='admin').first():
            admin = User(username='admin')
            admin.set_password('admin123')
            db.session.add(admin)
            db.session.commit()
    
    setup_gpio()
    try:
        # Run in production mode
        app.run(host='0.0.0.0', port=5000)
    except KeyboardInterrupt:
        # Clean shutdown
        lgpio.gpiochip_close(h)
