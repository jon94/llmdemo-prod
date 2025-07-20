from flask import Flask, request, jsonify, render_template
import openai
import time
import random
import os

app = Flask(__name__, template_folder="templates", static_folder="static")

openai.api_key = os.getenv("OPENAI_API_KEY")
CHAOS_ON = os.getenv("CHAOS_ON", "false").lower() == "true"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/play")
def play():
    return render_template("play.html")

@app.route("/ctf")
def ctf():
    return render_template("ctf.html")

@app.route("/chaos")
def chaos():
    return render_template("chaos.html")

@app.route("/api/play", methods=["POST"])
def play_api():
    data = request.get_json(silent=True)
    prompt = (data or {}).get("prompt", "")

    if CHAOS_ON:
        time.sleep(2 + random.random())

    response = openai.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
    )
    answer = response.choices[0].message.content
    return jsonify(response=answer)

@app.route("/api/ctf", methods=["POST"])
def ctf_api():
    data = request.get_json(silent=True)
    msg = (data or {}).get("msg", "")
    if "pizza" in msg.lower():
        return jsonify(answer="🚨 Guardrail triggered! 🍕 recipe leaked.")
    return jsonify(answer="✅ Safe message.")

@app.route("/api/chaos", methods=["POST"])
def toggle_chaos():
    global CHAOS_ON
    CHAOS_ON = not CHAOS_ON
    return jsonify(chaos=CHAOS_ON)

if __name__ == "__main__":
    debug_mode = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    app.run(debug=debug_mode, host="0.0.0.0", port=5000)
