# Dokumentacja użytkowa — platforma aukcyjna

Przewodnik instalacji, uruchomienia i typowych operacji w bazie
`platforma_aukcyjna`. Zakłada podstawową znajomość klienta `psql`.

## 1. Wymagania

- **PostgreSQL 18** (działa też na 14+),
- rozszerzenie **`pgcrypto`** (pakiet `postgresql-contrib`),
- klient `psql` lub **pgAdmin**.

## 2. Instalacja i pierwsze uruchomienie

### 2.1 Utworzenie bazy

```bash
createdb platforma_aukcyjna
```

(lub w `psql`: `CREATE DATABASE platforma_aukcyjna;`)

### 2.2 Załadowanie skryptów w kolejności

Linux/macOS:

```bash
cd auction_platform
for f in sql/00_reset.sql sql/01_schema.sql sql/02_indeksy.sql \
         sql/03_funkcje.sql sql/04_triggery.sql sql/05_procedury.sql \
         sql/06_widoki.sql sql/07_role_uprawnienia.sql \
         sql/08_dane_testowe.sql sql/09_zapytania_demo.sql; do
  echo ">>> $f"
  psql -d platforma_aukcyjna -v ON_ERROR_STOP=1 -f "$f" || break
done
```

Windows (PowerShell):

```powershell
Get-ChildItem sql\*.sql | Sort-Object Name | ForEach-Object {
  Write-Host ">>> $($_.Name)"
  psql -d platforma_aukcyjna -v ON_ERROR_STOP=1 -f $_.FullName
}
```

> Skrypt `00_reset.sql` czyści schemat — przy pierwszym uruchomieniu na pustej
> bazie po prostu nic nie usuwa. `09_zapytania_demo.sql` wypisuje wyniki
> przykładowych zapytań na ekran.

Po załadowaniu baza zawiera m.in. 30 użytkowników, 25 produktów, 16 aukcji
(zakończonych, wygasłych i trwających), oferty, transakcje i recenzje.

**Hasło wszystkich kont testowych:** `Haslo123!`

## 3. Typowe operacje

Wszystkie poniższe przykłady uruchamiamy w `psql -d platforma_aukcyjna`.

### 3.1 Rejestracja nowego użytkownika

```sql
CALL zarejestruj_uzytkownika('nowy_user', 'nowy@example.com', 'MojeHaslo!1',
                             'Jan', 'Testowy', '600999000');
```

Hasło zostaje automatycznie zahashowane (bcrypt). Identyfikator nowego konta
zwracany jest jako parametr wyjściowy.

### 3.2 Logowanie (weryfikacja hasła)

```sql
SELECT fn_weryfikuj_haslo('akowalski', 'Haslo123!');  -- t (true)
SELECT fn_weryfikuj_haslo('akowalski', 'bledne');     -- f (false)
```

### 3.3 Przeglądanie trwających aukcji

```sql
SELECT aukcja_id, produkt, kategoria, sprzedajacy,
       cena_biezaca_z_ofert, liczba_ofert, pozostaly_czas
FROM widok_aktywne_aukcje;
```

### 3.4 Składanie oferty

```sql
-- Minimalna dopuszczalna kwota następnej oferty:
SELECT fn_min_kolejna_oferta(11);

-- Złożenie oferty (użytkownik 14 licytuje w aukcji 11):
CALL zloz_oferte(11, 14, 2000);
```

Wyzwalacz odrzuci ofertę zbyt niską, ofertę na własną aukcję lub na aukcję
nieaktywną:

```sql
CALL zloz_oferte(11, 11, 5000);   -- BŁĄD: sprzedający nie może licytować własnej aukcji
CALL zloz_oferte(11, 14, 100);    -- BŁĄD: oferta za niska
```

### 3.5 Obserwowanie aukcji

```sql
INSERT INTO obserwowane (uzytkownik_id, aukcja_id) VALUES (14, 12);
DELETE FROM obserwowane WHERE uzytkownik_id = 14 AND aukcja_id = 12;
```

### 3.6 Rozliczenie aukcji (administrator)

```sql
-- Zamknięcie pojedynczej aukcji (wyłonienie zwycięzcy, utworzenie transakcji):
CALL zakoncz_aukcje(11);

-- Wsadowe zamknięcie wszystkich aukcji po terminie:
CALL zakoncz_wygasle_aukcje();
```

### 3.7 Wystawienie recenzji

```sql
-- Tylko strona zakończonej transakcji może wystawić recenzję:
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
VALUES (4, 22, 5, 5, 'Bardzo dobra współpraca.');
```

### 3.8 Raporty i statystyki

```sql
SELECT * FROM widok_ranking_sprzedajacych;
SELECT * FROM widok_statystyki_kategorii;
SELECT * FROM widok_historia_ofert WHERE aukcja_id = 1;
SELECT fn_srednia_ocena_sprzedajacego(2);
```

Bogatszy zestaw zapytań (podzapytania, CTE rekurencyjne, funkcje okna) znajduje
się w `sql/09_zapytania_demo.sql`.

## 4. Demonstracja poziomów izolacji

Otwórz dwa okna `psql` i wykonuj naprzemiennie polecenia z
`demo/sesja_A.sql` i `demo/sesja_B.sql` zgodnie z instrukcją w
[`demo/transakcje_izolacja.md`](../demo/transakcje_izolacja.md). Scenariusz
pokazuje różnicę między `READ COMMITTED` a `SERIALIZABLE` przy współbieżnym
licytowaniu.

## 5. Testowanie ról i uprawnień

```sql
-- Wcielenie się w gościa:
SET ROLE rola_gosc;
SELECT * FROM widok_aktywne_aukcje LIMIT 3;     -- OK
SELECT haslo_hash FROM uzytkownicy LIMIT 1;     -- BŁĄD: permission denied
RESET ROLE;

-- Kupujący nie może wystawić aukcji:
SET ROLE rola_kupujacy;
CALL zloz_oferte(11, 14, 2000);                 -- OK
INSERT INTO aukcje(produkt_id, sprzedajacy_id, cena_wywolawcza,
                   cena_aktualna, data_zakonczenia)
VALUES (1, 1, 100, 100, now() + interval '1 day');  -- BŁĄD: permission denied
RESET ROLE;
```

Utworzono też przykładowe konta logowania (`demo_admin`, `demo_sprzedajacy`,
`demo_kupujacy`, `demo_gosc`, hasło `demo`) jako członków odpowiednich ról —
rzeczywiste logowanie wymaga konfiguracji `pg_hba.conf`.

## 6. Ponowne uruchomienie od zera

Aby wyczyścić i odtworzyć bazę, wystarczy ponownie uruchomić skrypty od
`00_reset.sql` (usuwa wszystkie obiekty schematu) do `09`.

## 7. Najczęstsze problemy

| Problem | Przyczyna / rozwiązanie |
|---|---|
| `could not open extension control file ... pgcrypto` | brak pakietu `postgresql-contrib` |
| `permission denied for table ...` | aktywna rola o niższych uprawnieniach — wykonaj `RESET ROLE` |
| `ERROR: could not serialize access ... (40001)` | konflikt serializacji — **ponów** transakcję (zachowanie prawidłowe) |
| oferta odrzucona | zbyt niska kwota / własna aukcja / aukcja nieaktywna — komunikat wyjaśnia powód |
