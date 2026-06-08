# Platforma aukcyjna produktów elektronicznych — projekt bazy danych

Projekt zaliczeniowy z przedmiotu **Bazy Danych** (AGH). System bazodanowy
(bez warstwy aplikacji) obsługujący platformę aukcyjną sprzętu elektronicznego,
zrealizowany w **PostgreSQL 18**. Interakcja z bazą odbywa się przez `psql`
lub pgAdmin.

> **Zakres oceny:** projekt celuje w ocenę **4.5**. Świadomie pomijamy wymagania
> na 5.0 (optymalizacja przez `EXPLAIN`, studium przypadku, obowiązkowa
> prezentacja). Szczegółowe mapowanie kryteriów na artefakty znajduje się
> w [`docs/dokumentacja_techniczna.md`](docs/dokumentacja_techniczna.md).

## Co realizuje projekt

| Kryterium (ocena) | Artefakt |
|---|---|
| 3.0 – podstawowe funkcje | rejestracja, wystawienie aukcji, licytacja, rozliczenie |
| 3.0 – schemat min. 2NF | schemat od razu w **3NF** (`sql/01_schema.sql`) |
| 3.0/4.0 – dokumentacja | `docs/dokumentacja_uzytkowa.md`, `docs/dokumentacja_techniczna.md` |
| 3.5–4.0 – zaawansowane SQL | widoki + podzapytania + CTE rekurencyjne + funkcje okna (`sql/06`, `sql/09`) |
| 3.5–4.0 – wyzwalacze + procedury | `sql/03`, `sql/04`, `sql/05` (PL/pgSQL) |
| 3.5–4.0 – ERD i dok. techniczna | `docs/erd.md` (Mermaid) + `docs/slownik_danych.md` |
| 4.5 – schemat 3NF | projekt logiczny w 3NF + uzasadnienie w dokumentacji |
| 4.5 – transakcje + poziomy izolacji | `sql/05_procedury.sql` + `demo/` (scenariusze dwu-sesyjne) |
| 4.5 – bezpieczeństwo (role) | `sql/07_role_uprawnienia.sql` + hashowanie haseł (`pgcrypto`) |

## Struktura repozytorium

```
auction_platform/
├── README.md                       # ten plik
├── sql/
│   ├── 00_reset.sql                # czyszczenie schematu (DEV)
│   ├── 01_schema.sql               # DDL: tabele, klucze, ograniczenia (3NF), ENUM/domeny
│   ├── 02_indeksy.sql              # indeksy wspierające FK i typowe zapytania
│   ├── 03_funkcje.sql              # funkcje PL/pgSQL
│   ├── 04_triggery.sql             # funkcje wyzwalaczy + wyzwalacze (walidacja, cena, audyt)
│   ├── 05_procedury.sql            # procedury (transakcje, poziomy izolacji, pgcrypto)
│   ├── 06_widoki.sql               # widoki raportowe
│   ├── 07_role_uprawnienia.sql     # role + GRANT/REVOKE + pgcrypto
│   ├── 08_dane_testowe.sql         # realistyczny zestaw danych testowych
│   └── 09_zapytania_demo.sql       # zaawansowane zapytania (podzapytania, CTE, okna)
├── demo/
│   ├── transakcje_izolacja.md      # opis scenariuszy dwu-sesyjnych
│   ├── sesja_A.sql                 # sesja A (okno psql nr 1)
│   └── sesja_B.sql                 # sesja B (okno psql nr 2)
└── docs/
    ├── dokumentacja_techniczna.md  # architektura, decyzje, 3NF, opis logiki
    ├── dokumentacja_uzytkowa.md    # instalacja, uruchomienie, scenariusze użycia
    ├── erd.md                      # diagram ERD (Mermaid)
    └── slownik_danych.md           # słownik danych (opis tabel i kolumn)
```

## Wymagania

- **PostgreSQL 18** (działa również na 14+; wykorzystujemy `GENERATED ... AS IDENTITY`,
  `MERGE` nie jest używany, więc kompatybilność jest szeroka).
- Rozszerzenie **`pgcrypto`** (standardowy pakiet `contrib`, instalowane przez skrypt 07).
- Klient `psql` lub pgAdmin.

## Szybki start

1. Utwórz bazę danych i połącz się z nią:

   ```bash
   createdb platforma_aukcyjna
   psql -d platforma_aukcyjna
   ```

2. Uruchom skrypty **w kolejności** (każdy zatrzymuje się na pierwszym błędzie):

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

   W systemie Windows (PowerShell):

   ```powershell
   $pliki = 0..9 | ForEach-Object { Get-ChildItem "sql\0$_*.sql" }
   foreach ($f in $pliki) {
     Write-Host ">>> $($f.Name)"
     psql -d platforma_aukcyjna -v ON_ERROR_STOP=1 -f $f.FullName
   }
   ```

   > **Uwaga o kolejności:** `08_dane_testowe.sql` uruchamiamy **po** `04_triggery.sql`,
   > więc dane wstawiane są z włączonymi wyzwalaczami — `aukcje.cena_aktualna`
   > i `dziennik_zmian` wypełniają się automatycznie, dokładnie jak w działającym systemie.

3. Zapytania demonstracyjne (`09_zapytania_demo.sql`) wypisują wyniki na ekran —
   warto je też uruchamiać pojedynczo w pgAdmin/`psql`, by obejrzeć rezultaty.

## Demonstracja transakcji i poziomów izolacji

Otwórz **dwa** okna `psql` i postępuj zgodnie z
[`demo/transakcje_izolacja.md`](demo/transakcje_izolacja.md), wykonując naprzemiennie
polecenia z `demo/sesja_A.sql` i `demo/sesja_B.sql`. Scenariusz pokazuje różnicę
zachowania między `READ COMMITTED`, `REPEATABLE READ` i `SERIALIZABLE`
(błąd `could not serialize access` i konieczność ponowienia transakcji).

## Bezpieczeństwo

- Hasła przechowywane jako skróty **bcrypt** (`pgcrypto`: `crypt` + `gen_salt('bf')`).
- Role: `rola_admin`, `rola_sprzedajacy`, `rola_kupujacy`, `rola_gosc`.
- Dostęp do danych wrażliwych (`uzytkownicy.haslo_hash`) wyłącznie dla administratora;
  pozostałe role korzystają z widoków bez kolumn wrażliwych.
- Szczegóły i scenariusze testowe: `sql/07_role_uprawnienia.sql`.
