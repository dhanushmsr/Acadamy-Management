"""
Transactional email: a plain SMTP sender, plus one shared HTML template
for payment receipts.

The template itself (layout, structure, styling) is the same Python
function for every academy - there is exactly one render_invoice_html()
in this codebase. What makes each email look like it belongs to that
specific academy is that every academy-identifying value (name, logo,
address, phone, tagline) is passed in as a parameter at send-time, read
fresh from that academy's own row/document. Nothing about branding is
hardcoded here or duplicated per academy - change an academy's logo in
its profile and the very next receipt uses the new one automatically.

Uses plain SMTP (works with a Gmail App Password) rather than a
dedicated transactional-email API so it needs zero extra signups beyond
what the team already has. Swap smtp_host/port for a different
provider's SMTP relay later without touching any calling code - same
swap-the-provider pattern as integrations/whatsapp.py.
"""
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

from app.core.config import settings


class EmailSendError(Exception):
    """Raised when the SMTP server rejects or fails to send a message."""


def _connect_smtp_ssl_ipv4(host: str, port: int = 465, timeout: int = 20):
    """Create SMTP_SSL connection forcing IPv4 to avoid Render IPv6 issues."""
    import socket as _socket
    addr_info = _socket.getaddrinfo(host, port, _socket.AF_INET)
    if not addr_info:
        raise EmailSendError(f"Cannot resolve {host} to IPv4")
    ipv4_addr = addr_info[0][4][0]
    return smtplib.SMTP_SSL(ipv4_addr, port, timeout=timeout)


def _connect_smtp_tls_ipv4(host: str, port: int = 587, timeout: int = 20):
    """Create SMTP connection forcing IPv4, then STARTTLS."""
    import socket as _socket
    addr_info = _socket.getaddrinfo(host, port, _socket.AF_INET)
    if not addr_info:
        raise EmailSendError(f"Cannot resolve {host} to IPv4")
    ipv4_addr = addr_info[0][4][0]
    server = smtplib.SMTP(ipv4_addr, port, timeout=timeout)
    server.starttls()
    return server


def send_email(to_email: str, subject: str, html_body: str) -> None:
    if not settings.smtp_password or not settings.smtp_username:
        raise EmailSendError("SMTP credentials are not configured")

    pwd = settings.smtp_password.replace(" ", "").strip()
    user = settings.smtp_username.strip()
    from_email = (settings.smtp_from_email or user).strip()

    message = MIMEMultipart("alternative")
    message["Subject"] = subject
    message["From"] = from_email
    message["To"] = to_email
    message.attach(MIMEText(html_body, "html"))

    # Render blocks IPv6 outbound SMTP. Force IPv4 connections.
    errors = []

    # Attempt 1: SSL on port 465 (forced IPv4)
    try:
        server = _connect_smtp_ssl_ipv4(settings.smtp_host, 465)
        server.login(user, pwd)
        server.sendmail(from_email, to_email, message.as_string())
        server.quit()
        return
    except Exception as e:
        errors.append(f"SSL-465-IPv4: {e}")

    # Attempt 2: STARTTLS on port 587 (forced IPv4)
    try:
        server = _connect_smtp_tls_ipv4(settings.smtp_host, settings.smtp_port)
        server.login(user, pwd)
        server.sendmail(from_email, to_email, message.as_string())
        server.quit()
        return
    except Exception as e:
        errors.append(f"TLS-587-IPv4: {e}")

    # Attempt 3: Standard SMTP_SSL (let OS choose)
    try:
        with smtplib.SMTP_SSL(settings.smtp_host, 465, timeout=20) as server:
            server.login(user, pwd)
            server.sendmail(from_email, to_email, message.as_string())
            return
    except Exception as e:
        errors.append(f"SSL-465-default: {e}")

    raise EmailSendError(" | ".join(errors))


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
