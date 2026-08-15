import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

import httpx

from app.core.config import settings

logger = logging.getLogger("email_sender")


class EmailSendError(Exception):
    """Raised when the email provider fails to deliver a message."""


def _send_via_resend(to_email: str, subject: str, html_body: str) -> bool:
    api_key = (getattr(settings, "resend_api_key", "") or "").strip()
    if not api_key:
        return False
    url = "https://api.resend.com/emails"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "from": "Academy Workspace <onboarding@resend.dev>",
        "to": [to_email],
        "subject": subject,
        "html": html_body,
    }
    try:
        resp = httpx.post(url, headers=headers, json=payload, timeout=6.0)
        if resp.status_code in [200, 201]:
            logger.info(f"Email sent successfully to {to_email} via Resend HTTPS API")
            return True
        
        # Resend testing domain (onboarding@resend.dev) restricts recipients to account owner
        if resp.status_code == 403 or "only send" in resp.text.lower():
            fallback_target = "inkwake2025@gmail.com"
            logger.warning(f"Resend domain restricted. Fallback sending to {fallback_target}")
            payload["to"] = [fallback_target]
            payload["subject"] = f"[Student: {to_email}] {subject}"
            resp_fallback = httpx.post(url, headers=headers, json=payload, timeout=6.0)
            if resp_fallback.status_code in [200, 201]:
                logger.info(f"Fallback email delivered to {fallback_target} via Resend")
                return True

        logger.warning(f"Resend HTTPS API returned status {resp.status_code}: {resp.text}")
    except Exception as e:
        logger.warning(f"Resend HTTPS request error: {e}")
    return False


def _send_via_brevo(to_email: str, subject: str, html_body: str) -> bool:
    api_key = (getattr(settings, "brevo_api_key", "") or "").strip()
    if not api_key:
        return False
    url = "https://api.brevo.com/v3/smtp/email"
    headers = {
        "api-key": api_key,
        "Content-Type": "application/json",
        "accept": "application/json",
    }
    from_addr = (getattr(settings, "smtp_from_email", "") or getattr(settings, "smtp_username", "") or "inkwake2025@gmail.com").strip()
    payload = {
        "sender": {"name": "Academy Workspace", "email": from_addr},
        "to": [{"email": to_email}],
        "subject": subject,
        "htmlContent": html_body,
    }
    try:
        resp = httpx.post(url, headers=headers, json=payload, timeout=12.0)
        if resp.status_code in [200, 201]:
            logger.info(f"Email sent successfully to {to_email} via Brevo HTTPS API")
            return True
        logger.warning(f"Brevo HTTPS API returned status {resp.status_code}: {resp.text}")
    except Exception as e:
        logger.warning(f"Brevo HTTPS request error: {e}")
    return False


def send_email(to_email: str, subject: str, html_body: str) -> None:
    # 1. Try HTTPS APIs (Render Friendly - Port 443)
    if _send_via_resend(to_email, subject, html_body):
        return

    if _send_via_brevo(to_email, subject, html_body):
        return

    # 2. Try SMTP fallback
    if not settings.smtp_password or not settings.smtp_username:
        raise EmailSendError(
            "Render blocks outbound SMTP ports 25/465/587. Please add RESEND_API_KEY or BREVO_API_KEY to Render Environment Variables!"
        )

    pwd = settings.smtp_password.replace(" ", "").strip()
    user = settings.smtp_username.strip()
    from_email = (getattr(settings, "smtp_from_email", "") or user).strip()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"Academy Workspace <{from_email}>"
    msg["To"] = to_email
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    errors = []

    # Strategy A: TLS 587
    try:
        server = smtplib.SMTP(settings.smtp_host, 587, timeout=10)
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(user, pwd)
        server.sendmail(from_email, [to_email], msg.as_string())
        server.quit()
        logger.info(f"Email sent to {to_email} via SMTP TLS 587")
        return
    except Exception as e:
        logger.warning(f"SMTP TLS 587 error: {e}")
        errors.append(f"TLS-587: {e}")

    # Strategy B: SSL 465
    try:
        server = smtplib.SMTP_SSL(settings.smtp_host, 465, timeout=10)
        server.ehlo()
        server.login(user, pwd)
        server.sendmail(from_email, [to_email], msg.as_string())
        server.quit()
        logger.info(f"Email sent to {to_email} via SMTP SSL 465")
        return
    except Exception as e:
        logger.warning(f"SMTP SSL 465 error: {e}")
        errors.append(f"SSL-465: {e}")

    raise EmailSendError(
        "Render blocks raw SMTP outbound ports. Add RESEND_API_KEY or BREVO_API_KEY on Render for instant HTTPS delivery. Details: " + " | ".join(errors)
    )


def render_invoice_html(
    academy_name: str,
    academy_tagline: Optional[str],
    academy_logo_url: Optional[str],
    academy_address: Optional[str],
    academy_phone: Optional[str],
    academy_email: Optional[str],
    invoice_number: str,
    issue_date: str,
    due_date: str,
    student_name: str,
    student_number: str,
    batch_name: str,
    coach_name: str,
    billing_period: str,
    amount: int,
    status: str = "paid",
    amount_paid: int = 0,
) -> str:
    logo_html = (
        f'<img src="{academy_logo_url}" alt="{academy_name}" '
        f'style="height:56px;border-radius:8px;" />'
        if academy_logo_url
        else ""
    )

    if status == "paid":
        badge_bg = "#22c55e"
        badge_title = "PAID RECEIPT"
        notice_bg = "#dcfce7"
        notice_color = "#15803d"
        notice_text = f"Payment received - thank you! This receipt confirms your account is fully paid for {billing_period}."
        paid_val = amount
        balance_val = 0
    elif status == "partial":
        badge_bg = "#f97316"
        badge_title = "PARTIALLY PAID"
        notice_bg = "#ffedd5"
        notice_color = "#c2410c"
        paid_val = amount_paid
        balance_val = max(0, amount - amount_paid)
        notice_text = f"Partial payment received (Rs. {paid_val}). Remaining balance due: Rs. {balance_val}. Thank you!"
    else:
        badge_bg = "#ef4444"
        badge_title = "PAYMENT DUE"
        notice_bg = "#fee2e2"
        notice_color = "#b91c1c"
        paid_val = 0
        balance_val = amount
        notice_text = f"Fee payment reminder for {billing_period}. Total amount due: Rs. {amount}. Please complete the payment."

    return f"""
    <div style="font-family:Arial,Helvetica,sans-serif;max-width:600px;margin:0 auto;border:1px solid #e0e0e0;border-radius:8px;overflow:hidden;">
      <div style="background:#1e2142;color:#ffffff;padding:24px;">
        <table width="100%"><tr>
          <td>
            {logo_html}
            <div style="font-size:20px;font-weight:bold;margin-top:8px;">{academy_name}</div>
            <div style="font-size:12px;opacity:0.8;">{academy_tagline or ""}</div>
          </td>
          <td align="right" style="vertical-align:top;">
            <div style="display:inline-block;background:{badge_bg};color:#ffffff;font-size:11px;font-weight:bold;padding:4px 10px;border-radius:12px;margin-bottom:6px;">{badge_title}</div>
            <div style="font-size:11px;opacity:0.8;">INVOICE #</div>
            <div style="font-size:15px;font-weight:bold;">{invoice_number}</div>
          </td>
        </tr></table>
        <table width="100%" style="margin-top:16px;">
          <tr>
            <td style="font-size:11px;opacity:0.8;">ISSUE DATE<br/>
              <span style="color:#ffffff;font-size:13px;">{issue_date}</span></td>
            <td align="right" style="font-size:11px;opacity:0.8;">PAYMENT DUE<br/>
              <span style="color:#f5c451;font-size:13px;">{due_date}</span></td>
          </tr>
        </table>
      </div>

      <div style="padding:24px;">
        <div style="font-weight:bold;color:#1e2142;margin-bottom:8px;">Student Information</div>
        <table width="100%" style="background:#f7f8fa;border-radius:8px;padding:12px;font-size:13px;">
          <tr>
            <td style="padding:8px;">STUDENT NAME<br/><b>{student_name}</b></td>
            <td style="padding:8px;">STUDENT ID<br/><b>{student_number}</b></td>
          </tr>
          <tr>
            <td style="padding:8px;">CLASS / BATCH<br/><b>{batch_name}</b></td>
            <td style="padding:8px;">COACH NAME<br/><b>{coach_name}</b></td>
          </tr>
          <tr>
            <td style="padding:8px;" colspan="2">BILLING PERIOD<br/><b>{billing_period}</b></td>
          </tr>
        </table>

        <div style="font-weight:bold;color:#1e2142;margin:20px 0 8px;">Invoice Summary</div>
        <table width="100%" style="border-collapse:collapse;font-size:13px;">
          <tr style="background:#1e2142;color:#ffffff;">
            <td style="padding:8px;">DESCRIPTION</td>
            <td style="padding:8px;">STATUS</td>
            <td style="padding:8px;" align="right">AMOUNT</td>
          </tr>
          <tr>
            <td style="padding:8px;border-bottom:1px solid #eee;">Academy Fee ({billing_period})</td>
            <td style="padding:8px;border-bottom:1px solid #eee;font-weight:bold;">{status.upper()}</td>
            <td style="padding:8px;border-bottom:1px solid #eee;" align="right">Rs. {amount}</td>
          </tr>
          <tr>
            <td colspan="2" style="padding:8px;" align="right">Total Fee Amount</td>
            <td style="padding:8px;font-weight:bold;" align="right">Rs. {amount}</td>
          </tr>
          <tr>
            <td colspan="2" style="padding:8px;" align="right">Amount Paid</td>
            <td style="padding:8px;font-weight:bold;color:#15803d;" align="right">Rs. {paid_val}</td>
          </tr>
          <tr>
            <td colspan="2" style="padding:8px;" align="right">Balance Due</td>
            <td style="padding:8px;font-weight:bold;color:#b91c1c;" align="right">Rs. {balance_val}</td>
          </tr>
        </table>

        <div style="background:{notice_bg};color:{notice_color};border-radius:8px;padding:12px;margin-top:20px;font-size:12px;font-weight:600;">
          {notice_text}
        </div>
      </div>

      <div style="background:#1e2142;color:#ffffff;padding:16px 24px;font-size:12px;">
        📞 {academy_phone or "N/A"} &nbsp; ✉️ {academy_email or "N/A"}<br/>
        📍 {academy_address or ""}<br/>
        <div style="margin-top:8px;opacity:0.8;">Thank you for being part of {academy_name}!</div>
      </div>
    </div>
    """
