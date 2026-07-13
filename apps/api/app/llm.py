from __future__ import annotations

import logging
import re

import httpx

from app.config import Settings

log = logging.getLogger(__name__)

_SUMMARIZE_PROMPT = "Summarize the following text in one or two sentences:\n\n{text}"


def _stub_summarize(cleaned: str) -> str:
    sentence = re.split(r"(?<=[.!?])\s+", cleaned, maxsplit=1)[0]
    if len(sentence) > 160:
        sentence = sentence[:157].rstrip() + "..."
    return sentence


def _deepseek_summarize(text: str, settings: Settings) -> str:
    if not settings.deepseek_api_key:
        raise ValueError("DEEPSEEK_API_KEY is required when LLM_MODE=deepseek")

    url = f"{settings.deepseek_base_url.rstrip('/')}/chat/completions"
    payload = {
        "model": settings.deepseek_model,
        "messages": [{"role": "user", "content": _SUMMARIZE_PROMPT.format(text=text)}],
        "stream": False,
    }
    headers = {"Authorization": f"Bearer {settings.deepseek_api_key}"}
    with httpx.Client(timeout=120.0) as client:
        res = client.post(url, json=payload, headers=headers)
        res.raise_for_status()
        content = res.json()["choices"][0]["message"]["content"]
    return content.strip()


def summarize(text: str, settings: Settings) -> str:
    """Return a short summary. Stub for tests/CI; DeepSeek when LLM_MODE=deepseek."""
    cleaned = " ".join(text.split())
    if not cleaned:
        return ""

    if settings.llm_mode == "stub":
        return _stub_summarize(cleaned)

    if settings.llm_mode == "deepseek":
        return _deepseek_summarize(cleaned, settings)

    raise NotImplementedError(f"llm_mode={settings.llm_mode!r} not implemented yet")
