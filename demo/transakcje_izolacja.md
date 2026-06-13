# Demonstracja transakcji i poziomów izolacji

Scenariusz pokazuje, jak poziom izolacji transakcji wpływa na **współbieżne
licytowanie** tej samej aukcji. Dwóch kupujących próbuje jednocześnie złożyć
ofertę o tej samej (minimalnej dopuszczalnej) kwocie. W zależności od poziomu
izolacji baza albo wykrywa konflikt i wymusza ponowienie (`SERIALIZABLE`), albo
dopuszcza **anomalię** (`READ COMMITTED`).

## Punkt serializacji

Walidacja oferty (`trg_walidacja_oferty`) czyta stan aukcji **bez blokady**
(`FOR UPDATE`) — celowo, aby bezpieczeństwo współbieżne zależało od poziomu
izolacji. Naturalnym punktem konfliktu jest współdzielona aktualizacja kolumny
`aukcje.cena_aktualna` w wyzwalaczu `trg_aktualizuj_cene` (AFTER INSERT). Dwie
równoczesne oferty modyfikują ten sam wiersz aukcji:

- pod `SERIALIZABLE`/`REPEATABLE READ` druga transakcja dostaje błąd
  serializacji (`SQLSTATE 40001`),
- pod `READ COMMITTED` druga transakcja nadpisuje cenę i obie oferty zostają
  przyjęte.

## Przygotowanie

1. Załaduj komplet skryptów `01`–`08` na świeżą bazę (patrz `README.md`).
   Stan początkowy aukcji nr 11:

   | pole | wartość |
   |---|---|
   | `cena_aktualna` | 1900,00 |
   | `krok_przebicia` | 50,00 |
   | `fn_min_kolejna_oferta(11)` | **1950,00** |

2. Otwórz **dwa** okna `psql` połączone z bazą `platforma_aukcyjna`:

   ```bash
   psql -d platforma_aukcyjna   # okno 1 = SESJA A
   psql -d platforma_aukcyjna   # okno 2 = SESJA B
   ```

3. Wykonuj polecenia z `sesja_A.sql` i `sesja_B.sql` **naprzemiennie**, dokładnie
   w kolejności z tabeli poniżej.

## Przebieg (kolejność kroków)

| # | Sesja | Polecenie | Co się dzieje |
|---|---|---|---|
| 1 | A | `BEGIN TRANSACTION ISOLATION LEVEL …;` | start transakcji A |
| 2 | A | `INSERT ... VALUES (11,14,1950);` | A wstawia ofertę 1950; wyzwalacz blokuje wiersz aukcji 11 (brak COMMIT) |
| 3 | B | `BEGIN TRANSACTION ISOLATION LEVEL …;` | start transakcji B (ten sam poziom!) |
| 4 | B | `INSERT ... VALUES (11,16,1950);` | **instrukcja się blokuje** — czeka na zwolnienie wiersza aukcji |
| 5 | A | `COMMIT;` | A zatwierdza; blokada zwolniona |
| 6 | B | *(odblokowanie)* | wynik zależny od poziomu izolacji (poniżej) |

## Wynik wg poziomu izolacji

### `SERIALIZABLE` (lub `REPEATABLE READ`) — konflikt wykryty

Po `COMMIT` sesji A, zablokowana instrukcja sesji B kończy się błędem:

```
ERROR:  could not serialize access due to concurrent update
CONTEXT:  SQL statement "UPDATE aukcje
       SET cena_aktualna = NEW.kwota
     WHERE id = NEW.aukcja_id"
PL/pgSQL function fn_trg_aktualizuj_cene() line 3 at SQL statement
```

Sesja B musi wykonać `ROLLBACK` i **ponowić** transakcję. Po ponowieniu bieżąca
cena to już 1950, więc `fn_min_kolejna_oferta(11)` = **2000** — próba ponownego
1950 zostałaby słusznie odrzucona przez walidację jako zbyt niska. To poprawne,
spójne zachowanie: tylko jedna oferta 1950 została przyjęta.

> Obsługa po stronie aplikacji: błąd `40001` jest sygnałem do automatycznego
> powtórzenia całej transakcji (typowy wzorzec *retry loop* przy `SERIALIZABLE`).

### `READ COMMITTED` (domyślny) — anomalia

Po `COMMIT` sesji A instrukcja sesji B wykonuje się **bez błędu** i przyjmuje
drugą ofertę 1950. Po `COMMIT` obu sesji stan jest następujący:

```
 cena_aktualna
---------------
       1950.00

 ofert_1950
------------
          2        <-- DWIE równe „najwyższe" oferty 1950 zł
```

Druga oferta nie przebiła pierwszej, a mimo to została zaakceptowana — to
anomalia typu *lost update*. Reguła „każda kolejna oferta musi przebić
poprzednią" została naruszona przez współbieżność, mimo poprawnego wyzwalacza
walidującego. Dopiero `SERIALIZABLE` gwarantuje tu spójność.

## Wniosek

| Poziom izolacji | Zachowanie sesji B | Spójność reguły licytacji |
|---|---|---|
| `READ COMMITTED` | przyjmuje 2. ofertę 1950 (brak błędu) | **naruszona** (dwie równe oferty) |
| `REPEATABLE READ` | `ERROR 40001` → ponów | zachowana |
| `SERIALIZABLE` | `ERROR 40001` → ponów | zachowana |

Rozliczenie aukcji (`zakoncz_aukcje`) korzysta dodatkowo z jawnej blokady
`SELECT ... FOR UPDATE` i jest wykonywane jako transakcja atomowa — zalecany
poziom izolacji wołającego to `SERIALIZABLE`.
