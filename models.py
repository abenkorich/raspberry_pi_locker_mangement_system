from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class GPIOConfig(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    pin_number = db.Column(db.Integer, unique=True, nullable=False)
    is_allocated = db.Column(db.Boolean, default=False)
    locker_id = db.Column(db.Integer, db.ForeignKey('locker.id'), unique=True, nullable=True)
    
    @staticmethod
    def initialize_pins():
        # Initialize GPIO pins 2-27 if they don't exist
        existing_pins = {config.pin_number for config in GPIOConfig.query.all()}
        for pin in range(2, 28):
            if pin not in existing_pins:
                config = GPIOConfig(pin_number=pin, is_allocated=False)
                db.session.add(config)
        db.session.commit()
    
    @staticmethod
    def get_available_pins():
        return GPIOConfig.query.filter_by(is_allocated=False).all()

class Locker(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    row = db.Column(db.Integer, nullable=False)
    column = db.Column(db.Integer, nullable=False)
    gpio_config = db.relationship('GPIOConfig', backref='locker', uselist=False)
    unlock_code = db.Column(db.String(6), unique=True, nullable=True)
    is_occupied = db.Column(db.Boolean, default=False)

class Configuration(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    rows = db.Column(db.Integer, nullable=False, default=3)
    columns = db.Column(db.Integer, nullable=False, default=3)
