import time
import random
from flask import request, jsonify, render_template
from .config import client, CHAOS_ON, log
from .workflows import (
    process_user_prompt, 
    process_security_request, 
    process_ctf_request
)


def setup_routes(app):
    """Setup all Flask routes"""
    
    # Logging middleware
    @app.before_request
    def _log_request():
        log.info("%s %s from %s", request.method, request.path, request.remote_addr)

    @app.after_request
    def _log_response(resp):
        log.info("%s %s %s", request.method, request.path, resp.status_code)
        return resp

    # UI routes
    @app.route("/menu")
    def menu_ui():
        return render_template("menu.html")

    @app.route("/")
    def index(): 
        return render_template("index.html")

    @app.route("/ctf")
    def ctf_ui(): 
        return render_template("ctf.html")

    @app.route("/business")
    def business_ui(): 
        return render_template("business.html")

    # API routes

    @app.route("/api/security", methods=["POST"])
    def security_api():
        data = request.get_json(silent=True) or {}
        prompt = data.get("prompt", "").strip()
        user_name = data.get("user_name", "anonymous")  # Extract user_name from request
        log.info(f"Security API called for user: {user_name}")
        result = process_security_request(prompt, user_name)
        return jsonify(result)





    @app.route("/api/rag-status", methods=["GET"])
    def get_rag_status():
        """Get RAG vs Direct LLM status for current user"""
        user_name = request.args.get("user_name", "anonymous")
        
        from .config import is_rag_enabled
        
        rag_enabled = is_rag_enabled(user_name)
        status = {
            "rag_enabled": rag_enabled,
            "mode": "RAG (Database)" if rag_enabled else "Direct LLM",
            "user": user_name,
            "description": "RAG uses database queries for personalized responses. Direct LLM provides general assistance without database access."
        }
        
        return jsonify(status)

    @app.route("/api/ctf", methods=["POST"])
    def ctf_api():
        msg = request.get_data(as_text=True).strip()
        result = process_ctf_request(msg)
        
        # Handle both old string format (fallback) and new dict format
        if isinstance(result, str):
            # Fallback for old format
            return jsonify(answer=result, challenge_completed=False)
        else:
            # New structured format with evaluation
            return jsonify(result)

    # Business functionality routes that naturally query the database
    @app.route("/api/profile/<username>", methods=["GET"])
    def get_profile(username):
        """Get user profile - legitimate business operation"""
        from .database import get_user_profile_raw
        profile = get_user_profile_raw(username)
        if profile:
            return jsonify({
                "username": profile[0],
                "email": profile[1], 
                "role": profile[2],
                "created_at": profile[3]
            })
        else:
            return jsonify({"error": "User not found"}), 404

    @app.route("/api/orders/<username>", methods=["GET"])
    def get_orders(username):
        """Get user orders - legitimate business operation"""
        from .database import get_user_orders_raw
        orders = get_user_orders_raw(username)
        order_list = []
        for order in orders:
            order_list.append({
                "id": order[0],
                "product_name": order[1],
                "amount": float(order[2]),
                "status": order[3],
                "created_at": order[4]
            })
        return jsonify({"orders": order_list}) 