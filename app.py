from flask import Flask, request, redirect, render_template_string
import os
import redis

app = Flask(__name__)

# Connect to Redis. Notice: host comes from environment variable,
# defaulting to "redis" (the Docker Compose service name)
cache = redis.Redis(
    host=os.environ.get("REDIS_HOST", "redis"),
    port=int(os.environ.get("REDIS_PORT", 6379)),
    decode_responses=True,
)

PAGE = """
<!doctype html>
<title>TechRise Guestbook</title>
<h1>TechRise Guestbook</h1>
<form method="post" action="/sign">
  <input name="name" placeholder="Your name" required>
  <input name="message" placeholder="Your message" required>
  <button type="submit">Sign</button>
</form>
<p>Entries: {{ count }}</p>
<ul>{% for entry in entries %}<li>{{ entry }}</li>{% endfor %}</ul>
"""

@app.route("/")
def home():
    entries = cache.lrange("guestbook", 0, 19)   # get last 20 entries
    count = cache.llen("guestbook")               # total count
    return render_template_string(PAGE, entries=entries, count=count)

@app.route("/sign", methods=["POST"])
def sign():
    entry = request.form["name"] + ": " + request.form["message"]
    cache.lpush("guestbook", entry)   # push to front of the list
    return redirect("/")

@app.route("/health")
def health():
    try:
        cache.ping()            # literally pings Redis
        return {"status": "ok"}, 200
    except Exception:
        return {"status": "degraded"}, 503

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)