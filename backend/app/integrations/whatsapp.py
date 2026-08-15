"""
Thin wrapper around Meta's WhatsApp Cloud API.

Why a template, not plain text: WhatsApp only allows a business to send
free-form text to someone who messaged *them* in the last 24 hours (the
"customer service window"). Anything the academy sends first - which is
the whole point of this feature - has to go through a template Meta has
pre-approved. The workaround used here: register ONE generic template
(see README) with a single body variable, and put the trainer's actual
custom text into that variable. That satisfies WhatsApp's rule while
still letting the trainer type anything they want.

This lands in Meta's "Utility" template category (informational message
to an existing, enrolled customer) rather than "Marketing" - utility
templates are both easier to get approved and cheaper per message than
marketing ones. Since July 2025 Meta bills per delivered template
message rather than per 24-hour window, so cost scales with how many
parents you message, not how often.

Swap the internals of send_whatsapp_text_via_template() for Twilio,
Gupshup, AiSensy, Interakt, WATI, etc. if you'd rather go through a
Business Solution Provider instead of calling Meta directly - nothing
else in the app needs to change, it only depends on this function's
signature.
"""
import httpx

from app.core.config import settings


class WhatsAppSendError(Exception):
    """Raised when the WhatsApp API rejects or fails to deliver a message."""


def send_whatsapp_text_via_template(to_phone: str, body_text: str) -> str:
    """Sends `body_text` as the single variable of the pre-approved
    template named in settings.whatsapp_template_name.

    `to_phone` must be E.164 format (e.g. +919876543210) - no spaces,
    no leading zeros, country code included.

    Returns the provider's message id (useful for later delivery-status
    lookups via webhooks, not wired up in this scaffold).
    Raises WhatsAppSendError on any non-2xx response.
    """
    url = (
        f"https://graph.facebook.com/{settings.whatsapp_api_version}"
        f"/{settings.whatsapp_phone_number_id}/messages"
    )
    headers = {"Authorization": f"Bearer {settings.whatsapp_access_token}"}
    payload = {
        "messaging_product": "whatsapp",
        "to": to_phone,
        "type": "template",
        "template": {
            "name": settings.whatsapp_template_name,
            "language": {"code": "en_US"},
            "components": [
                {"type": "body", "parameters": [{"type": "text", "text": body_text}]}
            ],
        },
    }

    response = httpx.post(url, headers=headers, json=payload, timeout=10)
    data = response.json()

    if response.status_code >= 400:
        message = data.get("error", {}).get("message", "Unknown WhatsApp API error")
        raise WhatsAppSendError(message)

    return data["messages"][0]["id"]
