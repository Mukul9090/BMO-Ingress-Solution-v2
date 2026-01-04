import os
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
# Enable CORS for all routes
CORS(app, resources={r"/*": {"origins": "*"}})

# Read CLUSTER_ROLE from environment variable, default to "unknown"
CLUSTER_ROLE = os.getenv('CLUSTER_ROLE', 'unknown')


@app.route('/healthz', methods=['GET', 'OPTIONS'])
def healthz():
    """Health check endpoint."""
    response = jsonify({
        "status": "ok",
        "role": CLUSTER_ROLE
    })
    return response, 200


@app.route('/', methods=['GET', 'OPTIONS'])
def root():
    """Root endpoint."""
    response = jsonify({
        "message": "backend-ingress-service running",
        "role": CLUSTER_ROLE
    })
    return response, 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)

