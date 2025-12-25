import httpx
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from pydantic import EmailStr

from ..config import get_settings

settings = get_settings()

mail_conf = ConnectionConfig(
    MAIL_USERNAME=settings.mail_username,
    MAIL_PASSWORD=settings.mail_password,
    MAIL_FROM=settings.mail_from,
    MAIL_PORT=settings.mail_port,
    MAIL_SERVER=settings.mail_server,
    MAIL_STARTTLS=settings.mail_starttls,
    MAIL_SSL_TLS=settings.mail_ssl_tls,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True,
)


class NotificationService:
    def __init__(self):
        self.fast_mail = FastMail(mail_conf)
        self.smsapi_token = settings.smsapi_token
        self.smsapi_sender = settings.smsapi_sender

    async def send_email(
        self,
        to: EmailStr,
        subject: str,
        body: str,
    ) -> bool:
        """Send email notification."""
        try:
            message = MessageSchema(
                subject=subject,
                recipients=[to],
                body=body,
                subtype="html",
            )
            await self.fast_mail.send_message(message)
            return True
        except Exception as e:
            print(f"Failed to send email: {e}")
            return False

    async def send_sms(self, phone: str, message: str) -> bool:
        """Send SMS via SMSAPI.pl."""
        if not self.smsapi_token:
            print("SMSAPI token not configured")
            return False

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.smsapi.pl/sms.do",
                    headers={"Authorization": f"Bearer {self.smsapi_token}"},
                    data={
                        "to": phone,
                        "message": message,
                        "from": self.smsapi_sender,
                        "format": "json",
                    },
                )
                response.raise_for_status()
                return True
        except Exception as e:
            print(f"Failed to send SMS: {e}")
            return False

    async def send_order_confirmation(
        self,
        customer_email: EmailStr,
        customer_phone: str,
        customer_name: str,
        order_id: str,
        offer_title: str,
        pickup_date: str,
        pickup_time: str,
        total_price: str,
        payment_method: str,
        baker_phone: str | None = None,
    ):
        """Send order confirmation via email and SMS."""
        # Email
        email_body = f"""
        <h2>Potwierdzenie zamówienia - iBakery</h2>
        <p>Cześć {customer_name}!</p>
        <p>Dziękujemy za złożenie zamówienia.</p>

        <h3>Szczegóły zamówienia:</h3>
        <ul>
            <li><strong>Numer zamówienia:</strong> {order_id}</li>
            <li><strong>Oferta:</strong> {offer_title}</li>
            <li><strong>Data odbioru:</strong> {pickup_date}</li>
            <li><strong>Godziny odbioru:</strong> {pickup_time}</li>
            <li><strong>Suma:</strong> {total_price} PLN</li>
            <li><strong>Metoda płatności:</strong> {payment_method}</li>
        </ul>

        {"<p><strong>Płatność BLIK:</strong> Prześlij płatność na numer " + baker_phone + "</p>" if payment_method == "BLIK" and baker_phone else ""}

        <p>Do zobaczenia!</p>
        <p>Zespół iBakery</p>
        """
        await self.send_email(
            to=customer_email,
            subject=f"Potwierdzenie zamówienia #{order_id[:8]}",
            body=email_body,
        )

        # SMS
        sms_message = (
            f"iBakery: Zamowienie #{order_id[:8]} przyjete. "
            f"Odbior: {pickup_date} {pickup_time}. "
            f"Suma: {total_price} PLN."
        )
        if payment_method == "BLIK" and baker_phone:
            sms_message += f" BLIK na nr: {baker_phone}"

        await self.send_sms(phone=customer_phone, message=sms_message)

    async def notify_baker_new_order(
        self,
        baker_phone: str,
        order_id: str,
        customer_name: str,
        total_price: str,
    ):
        """Notify baker about new order via SMS."""
        sms_message = (
            f"Nowe zamowienie #{order_id[:8]} od {customer_name}. "
            f"Suma: {total_price} PLN."
        )
        await self.send_sms(phone=baker_phone, message=sms_message)
