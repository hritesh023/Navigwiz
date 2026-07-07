from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from app.config.settings import settings

security = HTTPBearer()


def validate_application_tags(tag_key: str, tag_value: str) -> dict | None:
    if tag_key == settings.application_tag_key and tag_value == settings.application_tag_value:
        return {
            "id": "navigwiz-app",
            "email": "app@navigwiz.acronous.com",
            "tag_key": tag_key,
            "tag_value": tag_value,
        }
    return None


async def verify_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm]
        )
        tag_key: str = payload.get("tag_key", "")
        tag_value: str = payload.get("tag_value", "")
        if tag_key == settings.application_tag_key and tag_value == settings.application_tag_value:
            return {
                "id": payload.get("sub", "navigwiz-app"),
                "email": payload.get("email", "app@navigwiz.acronous.com"),
                "tag_key": tag_key,
                "tag_value": tag_value,
            }
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict | None:
    try:
        return await verify_token(credentials)
    except HTTPException:
        return None


def create_access_token(tag_key: str, tag_value: str) -> str:
    from datetime import datetime, timedelta
    expire = datetime.utcnow() + timedelta(hours=settings.jwt_expiry_hours)
    payload = {
        "sub": "navigwiz-app",
        "email": "app@navigwiz.acronous.com",
        "tag_key": tag_key,
        "tag_value": tag_value,
        "exp": expire,
        "iat": datetime.utcnow()
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
