<img width="1154" height="649" alt="image" src="https://github.com/user-attachments/assets/fc9f669a-4714-4c8b-9a42-e7918998cef0" />

# 🚀 GodoTask
> A lightweight, fast, and Jira-style task management application built entirely with the **Godot Engine**!

`GodoTask` is designed to provide a smooth, modern, and distraction-free interface for managing projects and tickets. It can be run in **Standalone** mode (saving data locally) or connected to a **remote database on Home Assistant**, leveraging your home automation ecosystem for centralized data persistence.

---

## ✨ Key Features
- **Jira-Inspired Interface**: Visual organization of tickets, project management, and status tracking.
- **Dual Operating Modes**:
  - *Standalone*: Ready to use right out of the box with zero configuration.
  - *Home Assistant Remote DB*: Synchronization and storage of data using an SQLite database via Home Assistant.
- **Lightweight & Fast**: Built with Godot, ensuring exceptional performance and minimal resource usage.

---

## 🛠️️ Installation & Setup Guide

### 1. Home Assistant Prerequisites (Remote Mode)
If you want to use `GodoTask` with the remote database on Home Assistant, make sure you have the following components installed (via [HACS](https://hacs.xyz/)):
1. **HACS** (Home Assistant Community Store)
2. **Pyscript** (for executing advanced Python scripts inside Home Assistant)
3. **SQLite** (for file-based database management)

---

### 2. Home Assistant Configuration

#### Modifying `configuration.yaml`
Add or verify that the `pyscript` settings are present in your `/config/configuration.yaml` file:

```yaml
# configuration.yaml

# Loads default set of integrations. Do not remove.
default_config:

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml

pyscript:
  allow_all_imports: true
  hass_is_global: true
  legacy_decorators: true
```

#### Creating the Pyscript Script
Create a file named `godotask_db.py` inside your Home Assistant pyscript folder (the exact path is `/homeassistant/pyscript/godotask_db.py`).

Paste the following code into the file:

```python
# /homeassistant/pyscript/godotask_db.py
import logging
import sqlite3
import json

log = logging.getLogger(__name__)
DB_PATH = "/config/godotask.db"

@pyscript_executor
def _db_sync_and_get_all(projects, tickets):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                key TEXT,
                name TEXT,
                updated_at REAL,
                data TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tickets (
                id TEXT PRIMARY KEY,
                project_id TEXT,
                title TEXT,
                status INTEGER,
                updated_at REAL,
                data TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS attachments (
                id TEXT PRIMARY KEY,
                ticket_id TEXT,
                file_name TEXT,
                file_data TEXT
            )
        ''')
        
        valid_project_ids = []
        for p in projects:
            if isinstance(p, dict):
                p_id = str(p.get('id', ''))
                if not p_id:
                    continue
                valid_project_ids.append(p_id)
                p_key = str(p.get('key', ''))
                p_name = str(p.get('name', ''))
                p_updated = float(p.get('updated_at', 0.0))
                
                cursor.execute('''
                    INSERT INTO projects (id, key, name, updated_at, data)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        key = excluded.key,
                        name = excluded.name,
                        updated_at = excluded.updated_at,
                        data = excluded.data
                    WHERE excluded.updated_at >= projects.updated_at
                ''', (p_id, p_key, p_name, p_updated, json.dumps(p)))
            
        valid_ticket_ids = []
        for t in tickets:
            if isinstance(t, dict):
                t_id = str(t.get('id', ''))
                if not t_id:
                    continue
                valid_ticket_ids.append(t_id)
                t_proj_id = str(t.get('project_id', ''))
                t_title = str(t.get('title', ''))
                t_status = int(t.get('status', 0))
                t_updated = float(t.get('updated_at', 0.0))
                
                atts = t.get('attachments', [])
                if isinstance(atts, list):
                    for att in atts:
                        if isinstance(att, dict):
                            att_id = str(att.get('id', ''))
                            att_name = str(att.get('file_name', att.get('name', '')))
                            att_data = str(att.get('file_data', att.get('data', '')))
                            if att_id and att_data:
                                cursor.execute('''
                                    INSERT INTO attachments (id, ticket_id, file_name, file_data)
                                    VALUES (?, ?, ?, ?)
                                    ON CONFLICT(id) DO UPDATE SET
                                        ticket_id = excluded.ticket_id,
                                        file_name = excluded.file_name,
                                        file_data = excluded.file_data
                                ''', (att_id, t_id, att_name, att_data))

                if 'attachments' in t and isinstance(t['attachments'], list):
                    for att in t['attachments']:
                        if isinstance(att, dict) and 'file_data' in att:
                            att['file_data'] = ""

                cursor.execute('''
                    INSERT INTO tickets (id, project_id, title, status, updated_at, data)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        project_id = excluded.project_id,
                        title = excluded.title,
                        status = excluded.status,
                        updated_at = excluded.updated_at,
                        data = excluded.data
                    WHERE excluded.updated_at >= tickets.updated_at
                ''', (t_id, t_proj_id, t_title, t_status, t_updated, json.dumps(t)))

        if valid_project_ids:
            placeholders = ','.join(['?'] * len(valid_project_ids))
            cursor.execute(f"DELETE FROM projects WHERE id NOT IN ({placeholders})", valid_project_ids)
        else:
            cursor.execute("DELETE FROM projects")

        if valid_ticket_ids:
            placeholders = ','.join(['?'] * len(valid_ticket_ids))
            cursor.execute(f"DELETE FROM tickets WHERE id NOT IN ({placeholders})", valid_ticket_ids)
            cursor.execute(f"DELETE FROM attachments WHERE ticket_id NOT IN ({placeholders})", valid_ticket_ids)
        else:
            cursor.execute("DELETE FROM tickets")
            cursor.execute("DELETE FROM attachments")

        conn.commit()

        cursor.execute("SELECT data FROM projects")
        all_projects = [json.loads(row[0]) for row in cursor.fetchall()]

        cursor.execute("SELECT data FROM tickets")
        all_tickets = [json.loads(row[0]) for row in cursor.fetchall()]

        return all_projects, all_tickets

    except Exception as e:
        if 'conn' in locals() and conn:
            conn.rollback()
        log.error(f"godotask SQLite Execution Error: {e}")
        raise e
    finally:
        if 'conn' in locals() and conn:
            conn.close()

@pyscript_executor
def _db_get_attachment(attachment_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT file_name, file_data FROM attachments WHERE id = ?", (str(attachment_id),))
        row = cursor.fetchone()
        if row:
            return {"file_name": row[0], "file_data": row[1]}
        return {}
    except Exception as e:
        log.error(f"godotask Attachment Fetch Error: {e}")
        return {}
    finally:
        if 'conn' in locals() and conn:
            conn.close()

@service
def godotask_save_data(projects=None, tickets=None):
    try:
        if projects is None: projects = []
        if tickets is None: tickets = []

        db_projects, db_tickets = _db_sync_and_get_all(projects, tickets)

        state.set(
            "sensor.godotask_database",
            value="OK",
            new_attributes={
                "projects": db_projects,
                "tickets": db_tickets,
                "friendly_name": "GodoTask Database"
            }
        )
    except Exception as e:
        log.error(f"godotask PyScript Handler Error: {e}")
```

Restart Home Assistant or reload the Pyscript integration to activate the script.

---

### 3. Launching GodoTask
1. Clone or download this repository to your computer.
2. Open the project with the **Godot Engine** (Godot 4.x recommended) and run it. (or download the pre-built version)
3. In the application settings, you can choose between **Standalone** mode or enter your Home Assistant server details (IP address and Long-Lived Access Token) to sync your projects in real time with the remote SQLite database.
