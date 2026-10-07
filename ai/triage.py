#!/usr/bin/env python3
"""
Ask a local Ollama model to root-cause one crash. This is the whole AI-triage
idea in its simplest form: no scoring framework, no multiple runs, no modes.
One crash in, one structured answer out, which you then compare by hand to the
real CVE (CVE-2019-13218) to see if the model got it right.

Setup (one-time):
    curl -fsSL https://ollama.com/install.sh | sh
    ollama pull llama3.1
    pip3 install requests --break-system-packages

Usage:
    python3 ai/triage.py
"""
import json
import requests

SYSTEM_PROMPT = """You are a vulnerability researcher doing crash triage.
Given a sanitizer crash report and the relevant C source, identify the root
cause. Reply with ONLY a JSON object, no other text, with these keys:
  "bug_class": a short name, e.g. "stack buffer overflow"
  "cwe": the best-fitting CWE id, e.g. "CWE-787"
  "root_cause": 1-3 sentences on what's actually wrong in the code
"""

crash_report = open("crash_report.txt").read()
source = open("crash_source.txt").read()

user_prompt = f"""SANITIZER REPORT:
{crash_report}

RELEVANT SOURCE (vuln_stb_vorbis.c, around the crash):
{source}

Return the JSON object now."""

response = requests.post(
    "http://localhost:11434/api/chat",
    json={
        "model": "llama3.1",
        "stream": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
    },
    timeout=300,
)
answer = json.loads(response.json()["message"]["content"])

print(json.dumps(answer, indent=2))
print()
print("Compare this to the real answer:")
print("  CVE-2019-13218, stack buffer overflow, CWE-787,")
print("  in compute_codewords(): the 'available[32]' array is written at")
print("  index len[k], but len[k] is read straight from the file and is")
print("  never checked against 32 before this loop runs.")
