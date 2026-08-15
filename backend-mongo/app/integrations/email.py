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


def send_email(to_email: str, subject: str, html_body: str) -> None:
    message = MIMEMultipart("alternative")
    message["Subject"] = subject
    message["From"] = settings.smtp_from_email
    message["To"] = to_email
    message.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
            server.starttls()
            server.login(settings.smtp_username, settings.smtp_password)
            server.sendmail(settings.smtp_from_email, to_email, message.as_string())
    except smtplib.SMTPException as e:
        raise EmailSendError(str(e))


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
) -> str:
    """One template, fully dynamic content - see module docstring. Field
    layout mirrors the invoice King Chess Academy's original app already
    emails out (logo/name/tagline header, invoice number, student/batch/
    coach info, itemized amount, footer with contact details), so
    parents see something consistent with what they're used to. Tone is
    adjusted to a payment *receipt* since this fires on mark-paid, not a
    pre-due reminder."""
    logo_html = (
        f'<img src="{academy_logo_url}" alt="{academy_name}" '
        f'style="height:56px;border-radius:8px;" />'
        if academy_logo_url
        else ""
    )
    return f"""
    <div style="font-family:Arial,Helvetica,sans-serif;max-width:600px;margin:0 auto;border:1px solid #e0e0e0;">
      <div style="background:#1e2142;color:#ffffff;padding:24px;">
        <table width="100%"><tr>
          <td>
            {logo_html}
            <div style="font-size:20px;font-weight:bold;margin-top:8px;">{academy_name}</div>
            <div style="font-size:12px;opacity:0.8;">{academy_tagline or ""}</div>
          </td>
          <td align="right" style="vertical-align:top;">
            <div style="font-size:11px;opacity:0.8;">INVOICE</div>
            <div style="font-size:16px;font-weight:bold;">{invoice_number}</div>
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

        <div style="font-weight:bold;color:#1e2142;margin:20px 0 8px;">Invoice Details</div>
        <table width="100%" style="border-collapse:collapse;font-size:13px;">
          <tr style="background:#1e2142;color:#ffffff;">
            <td style="padding:8px;">DESCRIPTION</td>
            <td style="padding:8px;">DURATION</td>
            <td style="padding:8px;" align="right">AMOUNT</td>
          </tr>
          <tr>
            <td style="padding:8px;border-bottom:1px solid #eee;">Monthly Plan</td>
            <td style="padding:8px;border-bottom:1px solid #eee;">1 Month</td>
            <td style="padding:8px;border-bottom:1px solid #eee;" align="right">Rs. {amount}</td>
          </tr>
          <tr>
            <td colspan="2" style="padding:8px;" align="right">Total Amount Due</td>
            <td style="padding:8px;font-weight:bold;" align="right">Rs. {amount}</td>
          </tr>
        </table>

        <div style="background:#eaf1fb;border-radius:8px;padding:12px;margin-top:20px;font-size:12px;color:#333;">
          Payment received - thank you! This receipt confirms your account is up to date for {billing_period}.
        </div>
      </div>

      <div style="background:#1e2142;color:#ffffff;padding:16px 24px;font-size:12px;">
        {academy_phone or ""} &nbsp; {academy_email or ""}<br/>
        {academy_address or ""}<br/>
        <div style="margin-top:8px;opacity:0.8;">Thank you for being part of our Chess Academy family!</div>
      </div>
    </div>
    """
