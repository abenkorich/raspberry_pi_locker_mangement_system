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

class Locker(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    row = db.Column(db.Integer, nullable=False)
    column = db.Column(db.Integer, nullable=False)
    gpio_pin = db.Column(db.Integer, nullable=True)
    unlock_code = db.Column(db.String(6), unique=True, nullable=True)
    is_occupied = db.Column(db.Boolean, default=False)
    
class Configuration(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    rows = db.Column(db.Integer, nullable=False, default=3)
    columns = db.Column(db.Integer, nullable=False, default=3)
