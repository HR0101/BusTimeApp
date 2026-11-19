"""Bounded, process-local request protection for the single-worker API."""
from collections import OrderedDict, deque
import math
import secrets
import threading
import time

from fastapi.responses import JSONResponse


ADMIN_CSP = ("default-src 'self'; script-src 'self'; style-src 'self'; "
             "connect-src 'self'; object-src 'none'; base-uri 'none'; "
             "form-action 'none'; frame-ancestors 'none'")


class SlidingWindow:
    def __init__(self, limit, window=60, max_clients=2048, clock=time.monotonic):
        self.limit = limit
        self.window = window
        self.max_clients = max_clients
        self.clock = clock
        self.visitors = OrderedDict()
        self.lock = threading.Lock()

    def retry_after(self, client):
        with self.lock:
            now = self.clock()
            visits = self.visitors.pop(client, deque())
            while visits and visits[0] <= now - self.window:
                visits.popleft()
            retry = max(1, math.ceil(visits[0] + self.window - now)) if len(visits) >= self.limit else 0
            if not retry:
                visits.append(now)
            self.visitors[client] = visits
            if len(self.visitors) > self.max_clients:
                self.visitors.popitem(last=False)
            return retry


class RequestProtection:
    def __init__(self, clock=time.monotonic, public_limit=300, admin_limit=60, failure_limit=10):
        self.public = SlidingWindow(public_limit, clock=clock)
        self.admin = SlidingWindow(admin_limit, clock=clock)
        self.failures = SlidingWindow(failure_limit, clock=clock)

    def guard(self, request, key):
        # Uvicorn trusts only the local proxy. Never trust raw client-supplied IP headers here.
        client = request.client.host if request.client else 'unknown'
        protected = (request.url.path.startswith('/api/v1/admin') or
                     request.method in ('POST', 'PUT', 'PATCH', 'DELETE'))
        if protected:
            if not key:
                return self.response('Administration is disabled until ADMIN_API_KEY is configured', 503)
            provided = request.headers.get('X-Admin-Key', '')
            if not secrets.compare_digest(provided.encode(), key.encode()):
                retry = self.failures.retry_after(client)
                if retry:
                    return self.response('Too many authentication attempts', 429, retry)
                return self.response('Invalid administrator key', 401)
        retry = (self.admin if protected else self.public).retry_after(client)
        if retry:
            return self.response('Too many requests', 429, retry)
        return None

    @staticmethod
    def response(detail, status, retry=0):
        headers = {'Cache-Control': 'no-store'}
        if retry:
            headers['Retry-After'] = str(retry)
        return JSONResponse({'detail': detail}, status_code=status, headers=headers)


def secure_response(response, path):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=()'
    if path == '/admin' or path.startswith('/admin-assets/'):
        response.headers['Content-Security-Policy'] = ADMIN_CSP
        response.headers['Cache-Control'] = 'no-store'
    return response
