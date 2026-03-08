from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
import time
from cachetools import TTLCache

# Enforce 60 requests per minute per user/IP
rate_limit_cache = TTLCache(maxsize=10000, ttl=60)

class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Exempt health check paths from rate limiting
        if request.url.path in ["/", "/api/health"]:
            return await call_next(request)
            
        client_ip = request.client.host if request.client else "127.0.0.1"
        token = request.headers.get("Authorization")
        
        # Identify by token if present, otherwise by IP
        identifier = token if token else client_ip
        current_time = time.time()
        
        if identifier in rate_limit_cache:
            count, start_time = rate_limit_cache[identifier]
            if current_time - start_time > 60:
                rate_limit_cache[identifier] = (1, current_time)
            else:
                if count >= 60:
                    return JSONResponse(
                        status_code=429,
                        content={"success": False, "error": "Rate limit exceeded (60 req/min). Please try again later."}
                    )
                rate_limit_cache[identifier] = (count + 1, start_time)
        else:
            rate_limit_cache[identifier] = (1, current_time)
            
        return await call_next(request)

# Standardized Exception Handlers for consistency
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "error": str(exc.detail)}
    )

async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # Format detailed validation errors neatly
    errors = [".".join(str(l) for l in err["loc"]) + f": {err['msg']}" for err in exc.errors()]
    return JSONResponse(
        status_code=422,
        content={"success": False, "error": "Invalid payload", "details": errors}
    )

async def general_exception_handler(request: Request, exc: Exception):
    import logging
    logging.getLogger("cognify").error(f"Unhandled Exception: {exc}")
    # Do not leak internal stack traces to the client
    return JSONResponse(
        status_code=500,
        content={"success": False, "error": "Internal server error"}
    )
