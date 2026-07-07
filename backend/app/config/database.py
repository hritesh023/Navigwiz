import json
import os
import threading
from typing import Optional

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")
WORKSPACES_FILE = os.path.join(DATA_DIR, "workspaces.json")

_lock = threading.Lock()


def _ensure_data_dir():
    os.makedirs(DATA_DIR, exist_ok=True)


def _load_workspaces() -> dict:
    _ensure_data_dir()
    if not os.path.exists(WORKSPACES_FILE):
        return {}
    try:
        with open(WORKSPACES_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return {}


def _save_workspaces(data: dict):
    _ensure_data_dir()
    with open(WORKSPACES_FILE, "w") as f:
        json.dump(data, f, indent=2)


def create_workspace(workspace: dict) -> dict:
    with _lock:
        data = _load_workspaces()
        ws_id = workspace.get("id", workspace.get("id", ""))
        data[ws_id] = workspace
        _save_workspaces(data)
    return workspace


def get_workspaces(user_id: str) -> list:
    with _lock:
        data = _load_workspaces()
        return [ws for ws in data.values() if ws.get("user_id") == user_id]


def get_workspace(workspace_id: str, user_id: str) -> Optional[dict]:
    with _lock:
        data = _load_workspaces()
        ws = data.get(workspace_id)
        if ws and ws.get("user_id") == user_id:
            return ws
    return None


def delete_workspace(workspace_id: str, user_id: str) -> bool:
    with _lock:
        data = _load_workspaces()
        ws = data.get(workspace_id)
        if ws and ws.get("user_id") == user_id:
            del data[workspace_id]
            _save_workspaces(data)
            return True
    return False
