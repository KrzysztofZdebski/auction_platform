# Słownik danych

Opis wszystkich obiektów schematu bazy `platforma_aukcyjna`: typów
wyliczeniowych, domen oraz tabel wraz z kolumnami i ograniczeniami.

Skróty: **PK** — klucz główny, **FK** — klucz obcy, **UQ** — unikalność,
**NN** — NOT NULL, **DEF** — wartość domyślna.

---

## Typy wyliczeniowe (ENUM)

| Typ | Dopuszczalne wartości | Zastosowanie |
|---|---|---|
| `typ_adresu` | `rozliczeniowy`, `dostawy` | `adresy.typ` |
| `stan_produktu` | `nowy`, `uzywany`, `odnowiony` | `produkty.stan` |
| `status_aukcji` | `aktywna`, `zakonczona`, `anulowana` | `aukcje.status` |
| `status_platnosci` | `oczekujaca`, `oplacona`, `anulowana` | `transakcje.status_platnosci` |

## Domeny

| Domena | Typ bazowy | Ograniczenie | Zastosowanie |
|---|---|---|---|
| `kwota_dodatnia` | `NUMERIC(12,2)` | `CHECK (VALUE > 0)` | wszystkie kwoty pieniężne |

---

## Tabela: `uzytkownicy`
Konta użytkowników platformy.

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator konta |
| `nazwa_uzytkownika` | `varchar(50)` | NN, UQ | login |
| `email` | `varchar(255)` | NN, UQ, CHECK (format) | adres e-mail |
| `haslo_hash` | `text` | NN | skrót bcrypt hasła (pgcrypto) |
| `imie` | `varchar(100)` | | imię |
| `nazwisko` | `varchar(100)` | | nazwisko |
| `telefon` | `varchar(20)` | | numer telefonu |
| `data_rejestracji` | `timestamptz` | NN, DEF `now()` | data założenia konta |
| `aktywny` | `boolean` | NN, DEF `true` | czy konto aktywne |

## Tabela: `adresy`
Adresy użytkowników (rozliczeniowe i dostawy).

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator adresu |
| `uzytkownik_id` | `bigint` | NN, FK → `uzytkownicy(id)` ON DELETE CASCADE | właściciel adresu |
| `ulica` | `varchar(150)` | NN | ulica i numer |
| `miasto` | `varchar(100)` | NN | miasto |
| `kod_pocztowy` | `varchar(12)` | NN | kod pocztowy |
| `kraj` | `varchar(60)` | NN, DEF `'Polska'` | kraj |
| `typ` | `typ_adresu` | NN | rodzaj adresu |

## Tabela: `kategorie`
Hierarchiczny słownik kategorii produktów (samoodwołanie).

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator kategorii |
| `nazwa` | `varchar(100)` | NN, UQ | nazwa kategorii |
| `kategoria_nadrzedna_id` | `bigint` | FK → `kategorie(id)` ON DELETE SET NULL | kategoria nadrzędna (NULL = korzeń) |

Ograniczenie `chk_kategorie_nie_samo`: kategoria nie może być własnym rodzicem.

## Tabela: `producenci`
Słownik producentów sprzętu.

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator producenta |
| `nazwa` | `varchar(100)` | NN, UQ | nazwa producenta |
| `kraj` | `varchar(60)` | | kraj pochodzenia |

## Tabela: `produkty`
Produkty wystawiane na aukcjach.

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator produktu |
| `nazwa` | `varchar(200)` | NN | nazwa produktu |
| `opis` | `text` | | opis |
| `kategoria_id` | `bigint` | NN, FK → `kategorie(id)` ON DELETE RESTRICT | kategoria |
| `producent_id` | `bigint` | NN, FK → `producenci(id)` ON DELETE RESTRICT | producent |
| `stan` | `stan_produktu` | NN | stan techniczny |

## Tabela: `aukcje`
Aukcje produktów.

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator aukcji |
| `produkt_id` | `bigint` | NN, FK → `produkty(id)` ON DELETE RESTRICT | przedmiot aukcji |
| `sprzedajacy_id` | `bigint` | NN, FK → `uzytkownicy(id)` ON DELETE RESTRICT | sprzedający |
| `cena_wywolawcza` | `kwota_dodatnia` | NN | cena startowa |
| `cena_minimalna` | `kwota_dodatnia` | CHECK `>= cena_wywolawcza` | cena rezerwowa (opcjonalna) |
| `cena_aktualna` | `kwota_dodatnia` | NN | bieżąca cena (redundancja kontrolowana — trigger) |
| `krok_przebicia` | `kwota_dodatnia` | NN, DEF `1.00` | minimalny krok licytacji |
| `data_rozpoczecia` | `timestamptz` | NN, DEF `now()` | początek aukcji |
| `data_zakonczenia` | `timestamptz` | NN, CHECK `> data_rozpoczecia` | koniec aukcji |
| `status` | `status_aukcji` | NN, DEF `'aktywna'` | status |
| `zwyciezca_id` | `bigint` | FK → `uzytkownicy(id)` ON DELETE SET NULL, CHECK (tylko gdy `zakonczona`) | zwycięzca |

## Tabela: `oferty`
Oferty (licytacje) składane w aukcjach.

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator oferty |
| `aukcja_id` | `bigint` | NN, FK → `aukcje(id)` ON DELETE CASCADE | aukcja |
| `kupujacy_id` | `bigint` | NN, FK → `uzytkownicy(id)` ON DELETE RESTRICT | licytujący |
| `kwota` | `kwota_dodatnia` | NN | kwota oferty |
| `data_zlozenia` | `timestamptz` | NN, DEF `now()` | czas złożenia |

Reguły walidacji w wyzwalaczu `trg_walidacja_oferty` (patrz dok. techniczna).

## Tabela: `metody_platnosci`
Słownik metod płatności.

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator |
| `nazwa` | `varchar(60)` | NN, UQ | nazwa metody |

## Tabela: `transakcje`
Rozliczenia zakończonych aukcji (relacja 1:1 z aukcją).

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator transakcji |
| `aukcja_id` | `bigint` | NN, **UQ**, FK → `aukcje(id)` ON DELETE RESTRICT | rozliczana aukcja (1:1) |
| `kupujacy_id` | `bigint` | NN, FK → `uzytkownicy(id)` ON DELETE RESTRICT | kupujący |
| `sprzedajacy_id` | `bigint` | NN, FK → `uzytkownicy(id)` ON DELETE RESTRICT | sprzedający |
| `kwota` | `kwota_dodatnia` | NN | kwota transakcji |
| `metoda_platnosci_id` | `bigint` | NN, FK → `metody_platnosci(id)` ON DELETE RESTRICT | metoda płatności |
| `status_platnosci` | `status_platnosci` | NN, DEF `'oczekujaca'` | status płatności |
| `data` | `timestamptz` | NN, DEF `now()` | data rozliczenia |

Ograniczenie `chk_transakcje_strony`: kupujący ≠ sprzedający.

## Tabela: `recenzje`
Wzajemne oceny stron transakcji.

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator recenzji |
| `transakcja_id` | `bigint` | NN, FK → `transakcje(id)` ON DELETE CASCADE | powiązana transakcja |
| `autor_id` | `bigint` | NN, FK → `uzytkownicy(id)` ON DELETE RESTRICT | autor recenzji |
| `oceniany_id` | `bigint` | NN, FK → `uzytkownicy(id)` ON DELETE RESTRICT | oceniany |
| `ocena` | `smallint` | NN, CHECK `BETWEEN 1 AND 5` | ocena 1–5 |
| `komentarz` | `text` | | treść recenzji |
| `data` | `timestamptz` | NN, DEF `now()` | data wystawienia |

Ograniczenia: `chk_recenzje_strony` (autor ≠ oceniany),
`uq_recenzje_autor` (jeden autor — jedna recenzja na transakcję).
Wyzwalacz `trg_walidacja_recenzji` sprawdza, że autor i oceniany to strony
danej transakcji.

## Tabela: `obserwowane`
Lista obserwowanych aukcji (relacja M:N, klucz złożony).

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `uzytkownik_id` | `bigint` | PK, FK → `uzytkownicy(id)` ON DELETE CASCADE | obserwujący |
| `aukcja_id` | `bigint` | PK, FK → `aukcje(id)` ON DELETE CASCADE | obserwowana aukcja |
| `data` | `timestamptz` | NN, DEF `now()` | data dodania |

Klucz główny złożony: `(uzytkownik_id, aukcja_id)`.

## Tabela: `dziennik_zmian`
Dziennik audytowy (wypełniany triggerem `trg_audyt`).

| Kolumna | Typ | Ograniczenia | Opis |
|---|---|---|---|
| `id` | `bigint` | PK, IDENTITY | identyfikator wpisu |
| `tabela` | `text` | NN | nazwa zmienionej tabeli |
| `operacja` | `text` | NN, CHECK (`INSERT`/`UPDATE`/`DELETE`) | rodzaj operacji |
| `id_rekordu` | `text` | | klucz zmienionego rekordu |
| `dane` | `jsonb` | | treść rekordu (dla UPDATE: `stare` i `nowe`) |
| `uzytkownik_db` | `text` | NN, DEF `current_user` | użytkownik DB (`session_user` z triggera) |
| `czas` | `timestamptz` | NN, DEF `now()` | czas operacji |

---

## Widoki

| Widok | Opis |
|---|---|
| `widok_aktywne_aukcje` | Trwające aukcje z produktem, kategorią, sprzedającym i ceną bieżącą (z ofert) |
| `widok_ranking_sprzedajacych` | Ranking sprzedawców wg obrotów i średniej oceny |
| `widok_historia_ofert` | Historia ofert z pozycją (`RANK`) w aukcji |
| `widok_statystyki_kategorii` | Agregaty produktów i aukcji per kategoria |
| `widok_profil_uzytkownika` | Publiczny profil użytkownika **bez** danych wrażliwych |
