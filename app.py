import os
from flask import Flask

# Import all modules in the correct order
from src.config import log
from src.database import init_database
from src.rag import init_rag_with_sqlite
from src.routes import setup_routes

# Initialize RAG system (global variable)
rag_qa_chain = None

def create_app():
    """Create and configure the Flask application"""
    # Flask app setup
    app = Flask(__name__, template_folder="templates", static_folder="static")
    
    # Initialize database on startup
    init_database()
    
    # Initialize RAG system
    global rag_qa_chain
    rag_qa_chain = init_rag_with_sqlite()
    
    # Setup all routes
    setup_routes(app)
    
    return app

# Create the app instance
app = create_app()

# Dev entry point
if __name__ == "__main__":
    debug_mode = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    app.run(debug=debug_mode, host="0.0.0.0", port=5000) 