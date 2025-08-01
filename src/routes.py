import time
import random
from flask import request, jsonify, render_template
from .config import client, CHAOS_ON, log
from .workflows import (
    process_user_prompt, 
    process_security_request, 
    process_ctf_request, 
    toggle_chaos_mode
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

    @app.route("/play")
    def play_ui(): 
        return render_template("play.html")

    @app.route("/ctf")
    def ctf_ui(): 
        return render_template("ctf.html")

    @app.route("/security")
    def security_ui(): 
        return render_template("security.html")

    # API routes
    @app.route("/api/play", methods=["POST"])
    def play_api():
        data = request.get_json(silent=True) or {}
        messages = data.get("messages", [])

        # Check chaos mode - import here to get current value
        import src.config as config
        if config.CHAOS_ON:
            time.sleep(2 + random.random())

        # auto‐traced LLM span still applies
        resp = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=messages,
            temperature=0.7,
        )
        answer = resp.choices[0].message.content
        return jsonify(response=answer)

    @app.route("/api/security", methods=["POST"])
    def security_api():
        data = request.get_json(silent=True) or {}
        prompt = data.get("prompt", "").strip()
        result = process_security_request(prompt)
        return jsonify(result)

    @app.route("/api/ctf", methods=["POST"])
    def ctf_api():
        msg = request.get_data(as_text=True).strip()
        answer = process_ctf_request(msg)
        return jsonify(answer=answer)

    @app.route("/api/chaos", methods=["POST"])
    def toggle_chaos():
        chaos_state = toggle_chaos_mode()
        log.info("Chaos mode toggled → %s", chaos_state)
        return jsonify(chaos=chaos_state) 