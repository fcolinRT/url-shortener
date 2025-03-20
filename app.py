# app.py - Main application file
from flask import Flask, render_template, request, redirect, jsonify, abort
from flask_pymongo import PyMongo
import shortuuid
import os
import datetime
import logging
from logging.handlers import RotatingFileHandler
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Configure logging
if not os.path.exists('logs'):
    os.mkdir('logs')

file_handler = RotatingFileHandler('logs/url_shortener.log', maxBytes=10240, backupCount=10)
file_handler.setFormatter(logging.Formatter(
    '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
))
file_handler.setLevel(logging.INFO)

app.logger.addHandler(file_handler)
app.logger.setLevel(logging.INFO)
app.logger.info('URL Shortener startup')

# Configure MongoDB
app.config["MONGO_URI"] = os.environ.get("MONGODB_URI", "mongodb://localhost:27017/url_shortener")
mongo = PyMongo(app)

# Home route
@app.route('/')
def index():
    return render_template('index.html')

# Create short URL
@app.route('/shorten', methods=['POST'])
def shorten():
    original_url = request.form.get('original_url')
    
    if not original_url:
        return render_template('index.html', error="URL is required")
    
    # Basic URL validation
    if not original_url.startswith(('http://', 'https://')):
        original_url = 'https://' + original_url
    
    # Check if URL already exists in database
    existing_url = mongo.db.urls.find_one({"original_url": original_url})
    
    if existing_url:
        short_code = existing_url['short_code']
        app.logger.info(f"Found existing URL: {original_url} -> {short_code}")
    else:
        # Generate a short code
        short_code = shortuuid.uuid()[:8]
        
        # Store in database
        mongo.db.urls.insert_one({
            "original_url": original_url,
            "short_code": short_code,
            "created_at": datetime.datetime.utcnow(),
            "clicks": 0
        })
        app.logger.info(f"Created new URL: {original_url} -> {short_code}")
    
    # Get the host
    host = request.host
    short_url = f"{request.scheme}://{host}/{short_code}"
    
    return render_template('index.html', original_url=original_url, short_url=short_url)

# Redirect to original URL
@app.route('/<short_code>')
def redirect_to_url(short_code):
    url = mongo.db.urls.find_one({"short_code": short_code})
    
    if url:
        # Increment click count
        mongo.db.urls.update_one(
            {"_id": url["_id"]},
            {"$inc": {"clicks": 1}}
        )
        app.logger.info(f"Redirecting {short_code} -> {url['original_url']}")
        return redirect(url['original_url'])
    
    app.logger.warning(f"URL not found: {short_code}")
    return render_template('404.html'), 404

# API to get all URLs
@app.route('/api/urls')
def get_urls():
    urls = list(mongo.db.urls.find({}, {"_id": 0}))
    for url in urls:
        # Convert datetime to string for JSON serialization
        url['created_at'] = url['created_at'].isoformat()
    return jsonify(urls)

# API to delete URL
@app.route('/api/urls/<short_code>', methods=['DELETE'])
def delete_url(short_code):
    result = mongo.db.urls.delete_one({"short_code": short_code})
    
    if result.deleted_count > 0:
        app.logger.info(f"Deleted URL with code: {short_code}")
        return jsonify({"success": True})
    
    app.logger.warning(f"URL not found for deletion: {short_code}")
    return jsonify({"success": False, "error": "URL not found"}), 404

# Health check endpoint
@app.route('/health')
def health_check():
    try:
        # Check MongoDB connection
        mongo.db.command('ping')
        return jsonify({"status": "ok", "mongo": "connected"})
    except Exception as e:
        app.logger.error(f"Health check failed: {str(e)}")
        return jsonify({"status": "error", "mongo": "disconnected"}), 500

# 404 handler
@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

# 500 handler
@app.errorhandler(500)
def server_error(e):
    app.logger.error(f"Server error: {str(e)}")
    return render_template('error.html', error="Internal server error"), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    debug = os.environ.get("FLASK_ENV") == "development"
    app.run(host='0.0.0.0', port=port, debug=debug)
