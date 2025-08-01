import sqlite3
from ddtrace.llmobs import LLMObs
from ddtrace.llmobs.decorators import retrieval
from .config import DB_PATH, log


def init_database():
    """Initialize the SQLite database with the secret token"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create secrets table if it doesn't exist
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS secrets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            value TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Insert the secret token (using INSERT OR REPLACE to handle restarts)
    secret_value = "JON IS AWESOMEAWESOMEAWESOME"
    cursor.execute('''
        INSERT OR REPLACE INTO secrets (name, value) 
        VALUES (?, ?)
    ''', ("SECRET_TOKEN", secret_value))
    
    conn.commit()
    conn.close()
    log.info("Database initialized with secret token")


@retrieval
def query_secret_token():
    """Query and return the secret token from database"""
    log.info("@retrieval query_secret_token() called")
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("SELECT value FROM secrets WHERE name = ?", ("SECRET_TOKEN",))
        result = cursor.fetchone()
        conn.close()
        
        if result:
            log.info("Secret token retrieved from database")
            output_data = [{"id": "secret_token", "text": str(result[0]), "name": "SECRET_TOKEN", "score": 1.0}]
            log.info(f"Annotating with output_data: {output_data}")
            LLMObs.annotate(
                input_data="SELECT value FROM secrets WHERE name = 'SECRET_TOKEN'",
                output_data=output_data
            )
            return result[0]
        else:
            log.error("Secret token not found in database")
            output_data = []  # Empty array when no results
            log.info(f"Annotating with output_data: {output_data}")
            LLMObs.annotate(
                input_data="SELECT value FROM secrets WHERE name = 'SECRET_TOKEN'",
                output_data=output_data
            )
            return None
    except Exception as e:
        log.error(f"Database query error: {e}")
        output_data = []  # Empty array on error
        log.info(f"Annotating with output_data: {output_data}")
        LLMObs.annotate(
            input_data="SELECT value FROM secrets WHERE name = 'SECRET_TOKEN'",
            output_data=output_data
        )
        return None 