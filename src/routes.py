import time
import random
import json
from flask import request, jsonify, render_template, Response, g
from .config import client, CHAOS_ON, log
from .workflows import (
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
        
        # Add security evaluation header for Datadog WAF
        if hasattr(g, 'security_evaluation'):
            resp.headers['X-Security-Evaluation'] = g.security_evaluation
            log.info(f"Added security header: X-Security-Evaluation: {g.security_evaluation}")
        
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
        stream = data.get("stream", False)  # Check if streaming is requested
        log.info(f"Security API called for user: {user_name}, stream: {stream}")
        
        if stream:
            # Handle streaming response
            def generate():
                try:
                    result = process_security_request(prompt, user_name, stream=True)
                    if isinstance(result, dict) and "stream" in result:
                        stream_resp = result["stream"]
                        collected_content = ""
                        
                        for chunk in stream_resp:
                            if chunk.choices[0].delta.content is not None:
                                content = chunk.choices[0].delta.content
                                collected_content += content
                                yield f"data: {json.dumps({'content': content, 'done': False})}\n\n"
                        
                        # Send final message with complete response
                        yield f"data: {json.dumps({'content': '', 'done': True, 'full_response': collected_content})}\n\n"
                    else:
                        # Fallback to non-streaming
                        yield f"data: {json.dumps({'content': str(result), 'done': True})}\n\n"
                except Exception as e:
                    log.error(f"Streaming error: {e}")
                    yield f"data: {json.dumps({'error': str(e), 'done': True})}\n\n"
            
            return Response(generate(), mimetype='text/plain')
        else:
            # Regular non-streaming response
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
        # Handle both JSON and raw text data
        try:
            data = request.get_json(silent=True)
            if data and 'msg' in data:
                msg = data['msg']
            else:
                msg = request.get_data(as_text=True).strip()
        except:
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