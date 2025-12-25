# iBakery - Aplikacja Piekarni Internetowej

System do zamawiania pieczywa online składający się z:
- **Backend API** (Python + FastAPI)
- **Panel Piekarza** (Flutter Web/Mobile)
- **Aplikacja Klienta** (Flutter Web/Mobile)

## Wymagania

- Python 3.11+
- Flutter 3.x
- PostgreSQL 15+
- Docker (opcjonalnie)

## Uruchomienie z Docker

```bash
# Uruchom bazę danych i backend
docker-compose up -d

# Backend dostępny pod: http://localhost:8000
# Dokumentacja API: http://localhost:8000/docs
```

## Uruchomienie lokalne

### 1. Backend

```bash
cd backend

# Utwórz środowisko wirtualne
python -m venv venv
source venv/bin/activate  # Linux/Mac
# lub: venv\Scripts\activate  # Windows

# Zainstaluj zależności
pip install -r requirements.txt

# Skonfiguruj zmienne środowiskowe
cp .env.example .env
# Edytuj .env i ustaw DATABASE_URL oraz inne zmienne

# Uruchom migracje
alembic upgrade head

# Uruchom serwer
uvicorn app.main:app --reload
```

### 2. Panel Piekarza (Flutter)

```bash
cd baker

# Pobierz zależności
flutter pub get

# Uruchom aplikację web
flutter run -d chrome

# Lub uruchom na urządzeniu mobilnym
flutter run
```

### 3. Aplikacja Klienta (Flutter)

```bash
cd client

# Pobierz zależności
flutter pub get

# Uruchom aplikację web
flutter run -d chrome

# Lub uruchom na urządzeniu mobilnym
flutter run
```

## Konfiguracja

### Backend (.env)

```env
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/ibakery
SECRET_KEY=your-secret-key
MAIL_SERVER=smtp.example.com
MAIL_USERNAME=your-email@example.com
MAIL_PASSWORD=your-password
SMSAPI_TOKEN=your-smsapi-token
```

### Flutter (lib/services/api_service.dart)

Zmień `baseUrl` na adres swojego backendu:
```dart
const String baseUrl = 'http://localhost:8000/api';
```

## Funkcjonalności

### Panel Piekarza
- Zarządzanie jednostkami miary (g, l, szt, itp.)
- Zarządzanie składnikami z cenami
- Tworzenie produktów z recepturami
- Tworzenie ofert z datą odbioru i deadline zamówień
- Przeglądanie zamówień i zmiana statusu płatności
- Podsumowanie składników potrzebnych na ofertę

### Aplikacja Klienta
- Przeglądanie aktywnych ofert
- Koszyk zakupowy
- Składanie zamówień bez rejestracji
- Wybór metody płatności (gotówka/BLIK)
- Potwierdzenie zamówienia

## API Endpoints

### Publiczne
- `GET /api/offers/active` - Aktywne oferty
- `GET /api/offers/{id}` - Szczegóły oferty
- `POST /api/orders` - Złóż zamówienie
- `GET /api/orders/{id}` - Status zamówienia

### Dla piekarza (wymagają autoryzacji)
- `POST /api/auth/login` - Logowanie
- `GET /api/auth/me` - Dane zalogowanego użytkownika
- CRUD: `/api/units`, `/api/ingredients`, `/api/products`, `/api/offers`
- `GET /api/offers/{id}/summary` - Podsumowanie składników
- `GET /api/orders` - Lista zamówień
- `PATCH /api/orders/{id}` - Aktualizacja statusu

## Tworzenie konta piekarza

Po uruchomieniu backendu, utwórz konto piekarza:

```bash
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "piekarz@ibakery.pl",
    "password": "twoje-haslo",
    "name": "Jan Piekarz",
    "phone": "+48123456789"
  }'
```

## Licencja

MIT
