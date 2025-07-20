from flask import Flask, request, jsonify
import openai
import time
import random
import os

app = Flask(__name__)

# Configure your OpenAI key via env var or directly (NOT recommended for prod)
openai.api_key = os.getenv("OPENAI_API_KEY")

# Optional: simulate chaos for testing latency or robustness
CHAOS_ON = os.getenv("CHAOS_ON", "false").lower() == "true"

@app.route("/api/play", methods=["POST"])
def play_api():
    prompt = request.get_json().get("prompt", "")

    if CHAOS_ON:
        time.sleep(2 + random.random())  # simulate latency

    # Just call OpenAI — Datadog will auto-instrument this
    response = openai.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
    )

    answer = response.choices[0].message.content
    return jsonify(response=answer)

if __name__ == "__main__":
    app.run(debug=debug_mode, host="0.0.0.0", port=5000)