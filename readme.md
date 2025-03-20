# URL Shortener

A simple, self-hosted URL shortener application built with Python Flask and MongoDB.

## Features

- Create shortened URLs
- Track click statistics
- View and manage all your shortened URLs
- Simple, responsive UI
- API for programmatic access

## Prerequisites

- Python 3.8 or higher
- MongoDB (local or cloud instance)
- pip (Python package manager)

## Installation

### Local Development

1. Clone this repository
2. Create a virtual environment:
   ```
   python -m venv venv
   ```
3. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - macOS/Linux: `source venv/bin/activate`
4. Install dependencies:
   ```
   pip install -r requirements.txt
   ```
5. Create `.env` file by copying `.env.template`:
   ```
   cp .env.template .env
   ```
6. Edit the `.env` file with your configuration
7. Run the application:
   ```
   flask run
   ```

The application will be available at `http://localhost:5000`

## Production Deployment

For production deployment, follow these steps:

1. Set up a server (e.g., Ubuntu VPS)
2. Install Python, pip, and MongoDB
3. Clone this repository
4. Set up a virtual environment and install dependencies
5. Configure your `.env` file for production
6. Set up a process manager (e.g., Supervisor, systemd)
7. Configure a web server (e.g., Nginx) as a reverse proxy

See the deployment guide in `DEPLOYMENT.md` for detailed instructions.

## Usage

1. Access the application in your web browser
2. Enter a URL to shorten
3. Copy and share the shortened URL
4. View statistics in the dashboard

## API Documentation

The application provides a simple API:

### List all URLs
```
GET /api/urls
```

### Delete a URL
```
DELETE /api/urls/<short_code>
```

## Maintenance

For proper maintenance:

1. Regularly back up your MongoDB database
2. Monitor the application logs
3. Update dependencies periodically
4. Check disk space and server resources

## License

MIT License
