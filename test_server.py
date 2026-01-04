"""
Unit tests for the backend service Flask application.
"""
import unittest
import os
from server import app


class TestServer(unittest.TestCase):
    """Test cases for the Flask application."""

    def setUp(self):
        """Set up test client."""
        self.app = app.test_client()
        self.app.testing = True

    def test_healthz_endpoint(self):
        """Test the /healthz endpoint."""
        response = self.app.get('/healthz')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('status', data)
        self.assertIn('role', data)
        self.assertEqual(data['status'], 'ok')

    def test_root_endpoint(self):
        """Test the root / endpoint."""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('message', data)
        self.assertIn('role', data)
        self.assertEqual(data['message'], 'backend-ingress-service running')

    def test_healthz_with_cluster_role(self):
        """Test healthz endpoint with CLUSTER_ROLE environment variable."""
        os.environ['CLUSTER_ROLE'] = 'hot'
        from importlib import reload
        import server
        reload(server)
        test_app = server.app.test_client()
        response = test_app.get('/healthz')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data['role'], 'hot')

    def test_cors_headers(self):
        """Test CORS headers are present."""
        response = self.app.get('/healthz')
        self.assertIn('Access-Control-Allow-Origin', response.headers)

    def test_options_request(self):
        """Test OPTIONS request for CORS preflight."""
        response = self.app.options('/healthz')
        self.assertEqual(response.status_code, 200)


if __name__ == '__main__':
    unittest.main()

