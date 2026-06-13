# Diagram ERD — platforma aukcyjna

Diagram związków encji (ERD) w notacji Mermaid (`erDiagram`). Na GitHubie oraz
w edytorach wspierających Mermaid renderuje się automatycznie. Można go też
wkleić do [mermaid.live](https://mermaid.live), aby wyeksportować do PNG/SVG.

## Schemat

```mermaid
erDiagram
    uzytkownicy ||--o{ adresy            : "posiada"
    uzytkownicy ||--o{ aukcje            : "wystawia (sprzedajacy)"
    uzytkownicy |o--o{ aukcje            : "wygrywa (zwyciezca)"
    uzytkownicy ||--o{ oferty            : "licytuje"
    uzytkownicy ||--o{ transakcje        : "kupuje"
    uzytkownicy ||--o{ transakcje        : "sprzedaje"
    uzytkownicy ||--o{ recenzje          : "wystawia (autor)"
    uzytkownicy ||--o{ recenzje          : "jest oceniany"
    uzytkownicy ||--o{ obserwowane       : "obserwuje"

    kategorie   |o--o{ kategorie         : "nadrzędna"
    kategorie   ||--o{ produkty          : "klasyfikuje"
    producenci  ||--o{ produkty          : "produkuje"
    produkty    ||--o{ aukcje            : "jest przedmiotem"

    aukcje      ||--o{ oferty            : "zbiera"
    aukcje      ||--o| transakcje        : "rozliczana jako (1:1)"
    aukcje      ||--o{ obserwowane       : "jest obserwowana"

    metody_platnosci ||--o{ transakcje   : "opłacana"
    transakcje  ||--o{ recenzje          : "umożliwia"

    uzytkownicy {
        bigint      id PK
        varchar     nazwa_uzytkownika UK
        varchar     email UK
        text        haslo_hash
        varchar     imie
        varchar     nazwisko
        varchar     telefon
        timestamptz data_rejestracji
        boolean     aktywny
    }

    adresy {
        bigint     id PK
        bigint     uzytkownik_id FK
        varchar    ulica
        varchar    miasto
        varchar    kod_pocztowy
        varchar    kraj
        typ_adresu typ
    }

    kategorie {
        bigint  id PK
        varchar nazwa UK
        bigint  kategoria_nadrzedna_id FK
    }

    producenci {
        bigint  id PK
        varchar nazwa UK
        varchar kraj
    }

    produkty {
        bigint        id PK
        varchar       nazwa
        text          opis
        bigint        kategoria_id FK
        bigint        producent_id FK
        stan_produktu stan
    }

    aukcje {
        bigint        id PK
        bigint        produkt_id FK
        bigint        sprzedajacy_id FK
        numeric       cena_wywolawcza
        numeric       cena_minimalna
        numeric       cena_aktualna
        numeric       krok_przebicia
        timestamptz   data_rozpoczecia
        timestamptz   data_zakonczenia
        status_aukcji status
        bigint        zwyciezca_id FK
    }

    oferty {
        bigint      id PK
        bigint      aukcja_id FK
        bigint      kupujacy_id FK
        numeric     kwota
        timestamptz data_zlozenia
    }

    metody_platnosci {
        bigint  id PK
        varchar nazwa UK
    }

    transakcje {
        bigint           id PK
        bigint           aukcja_id FK "UNIQUE 1:1"
        bigint           kupujacy_id FK
        bigint           sprzedajacy_id FK
        numeric          kwota
        bigint           metoda_platnosci_id FK
        status_platnosci status_platnosci
        timestamptz      data
    }

    recenzje {
        bigint      id PK
        bigint      transakcja_id FK
        bigint      autor_id FK
        bigint      oceniany_id FK
        smallint    ocena
        text        komentarz
        timestamptz data
    }

    obserwowane {
        bigint      uzytkownik_id PK "FK"
        bigint      aukcja_id PK "FK"
        timestamptz data
    }

    dziennik_zmian {
        bigint      id PK
        text        tabela
        text        operacja
        text        id_rekordu
        jsonb       dane
        text        uzytkownik_db
        timestamptz czas
    }
```

## Uwagi do diagramu

- `kategorie` zawiera **samoodwołanie** (`kategoria_nadrzedna_id → kategorie.id`),
  co tworzy hierarchię kategorii i umożliwia rekurencyjne CTE.
- `aukcje` ma **dwa** klucze obce do `uzytkownicy`: `sprzedajacy_id` (wymagany)
  oraz `zwyciezca_id` (opcjonalny, ustawiany przy rozliczeniu).
- `transakcje` ma dwa klucze obce do `uzytkownicy` (`kupujacy_id`,
  `sprzedajacy_id`) oraz relację **1:1** z `aukcje` (`aukcja_id` z więzem
  `UNIQUE`).
- `recenzje` wskazuje dwa konta (`autor_id`, `oceniany_id`) i powiązaną
  `transakcja_id`.
- `dziennik_zmian` to tabela audytowa bez kluczy obcych — przechowuje historię
  operacji w formacie JSONB (wypełniana triggerem `trg_audyt`).
- Oznaczenia liczności: `||` = dokładnie jeden, `o{` = zero lub wiele,
  `o|` = zero lub jeden.
