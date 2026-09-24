from typing import Annotated

from fastapi import Depends, Header
from house_design.database import Session, get_db
from house_design.errors import AppError
from house_design.models import User
from house_design.security import decode_token


def get_current_user(
    db: Session = Depends(get_db),
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise AppError(401, "UNAUTHORIZED", "请先登录")
    user_id = decode_token(authorization.split(" ", 1)[1].strip())
    user = db.get(User, user_id)
    if user is None:
        raise AppError(401, "UNAUTHORIZED", "登录已失效")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
DbSession = Annotated[Session, Depends(get_db)]
