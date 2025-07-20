# LLM Stage Demo

Three‑endpoint Flask app instrumented with Datadog **LLM Observability** for conference demos.

* `/play`  — Prompt playground; every request becomes an LLM span.  
* `/ctf`   — Guard‑rail CTF; leaks trigger a tagged incident.  
* `/chaos` — Toggle latency spikes; watch SLO & Watchdog react.

## Quick start

```bash
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

export OPENAI_API_KEY=<your key>
export DD_API_KEY=<your key>
export DD_SITE=datadoghq.com  # or datadoghq.eu, us3,...

ddtrace-run python app.py
```

## Container

```bash
docker build -t llm-demo .
docker run -p 8000:8000 \
  -e OPENAI_API_KEY=<key> \
  -e DD_API_KEY=<key> \
  llm-demo
```

## Cloud Run

```bash
gcloud run deploy llm-demo --source . --region asia-southeast1 --allow-unauthenticated
```

Or deploy to AWS App Runner / ECS Fargate analogously.