-- ============================================================================
--  09_zapytania_demo.sql  —  Zaawansowane zapytania demonstracyjne
-- ----------------------------------------------------------------------------
--  Zbiór zapytań pokazujących: podzapytania (skorelowane i nieskorelowane),
--  wyrażenia CTE (w tym REKURENCYJNE), funkcje okna, agregacje z HAVING oraz
--  użycie widoków. Uruchamiać po załadowaniu danych testowych (08).
--  Każde zapytanie poprzedzone jest \echo z opisem.
-- ============================================================================

\echo ''
\echo '### 1. Podzapytanie NIESKORELOWANE — aukcje droższe niż średnia wszystkich aukcji'
SELECT a.id, p.nazwa AS produkt, a.cena_aktualna
FROM aukcje a
JOIN produkty p ON p.id = a.produkt_id
WHERE a.cena_aktualna > (SELECT avg(cena_aktualna) FROM aukcje)
ORDER BY a.cena_aktualna DESC;

\echo ''
\echo '### 2. Podzapytanie SKORELOWANE — aukcje z ceną powyżej średniej w SWOJEJ kategorii'
SELECT a.id, p.nazwa AS produkt, k.nazwa AS kategoria, a.cena_aktualna
FROM aukcje a
JOIN produkty  p ON p.id = a.produkt_id
JOIN kategorie k ON k.id = p.kategoria_id
WHERE a.cena_aktualna > (
        SELECT avg(a2.cena_aktualna)
        FROM aukcje a2
        JOIN produkty p2 ON p2.id = a2.produkt_id
        WHERE p2.kategoria_id = p.kategoria_id   -- korelacja z zewnętrznym zapytaniem
      )
ORDER BY k.nazwa, a.cena_aktualna DESC;

\echo ''
\echo '### 3. NOT EXISTS — użytkownicy, którzy NIGDY nie wygrali żadnej aukcji'
SELECT u.id, u.nazwa_uzytkownika
FROM uzytkownicy u
WHERE NOT EXISTS (SELECT 1 FROM aukcje a WHERE a.zwyciezca_id = u.id)
ORDER BY u.id;

\echo ''
\echo '### 4. LEFT JOIN ... IS NULL — aukcje, w których nie złożono żadnej oferty'
SELECT a.id, p.nazwa AS produkt, a.status, a.cena_wywolawcza
FROM aukcje a
JOIN produkty p ON p.id = a.produkt_id
LEFT JOIN oferty o ON o.aukcja_id = a.id
WHERE o.id IS NULL
ORDER BY a.id;

\echo ''
\echo '### 5. CTE (WITH) — obroty i liczba sprzedaży per sprzedawca'
WITH obroty AS (
    SELECT sprzedajacy_id, sum(kwota) AS suma, count(*) AS liczba
    FROM transakcje
    GROUP BY sprzedajacy_id
)
SELECT u.nazwa_uzytkownika, o.liczba AS liczba_sprzedazy, o.suma AS obrot
FROM obroty o
JOIN uzytkownicy u ON u.id = o.sprzedajacy_id
ORDER BY o.suma DESC;

\echo ''
\echo '### 6. REKURENCYJNE CTE — pełna ścieżka w hierarchii kategorii'
WITH RECURSIVE drzewo AS (
    SELECT id, nazwa, kategoria_nadrzedna_id, 1 AS poziom, nazwa::text AS sciezka
    FROM kategorie
    WHERE kategoria_nadrzedna_id IS NULL
  UNION ALL
    SELECT k.id, k.nazwa, k.kategoria_nadrzedna_id,
           d.poziom + 1, d.sciezka || ' > ' || k.nazwa
    FROM kategorie k
    JOIN drzewo d ON k.kategoria_nadrzedna_id = d.id
)
SELECT poziom, sciezka
FROM drzewo
ORDER BY sciezka;

\echo ''
\echo '### 7. REKURENCYJNE CTE + agregacja — liczba aukcji w kategorii "Komputery" i jej podkategoriach'
WITH RECURSIVE potomkowie AS (
    SELECT id, nazwa FROM kategorie WHERE nazwa = 'Komputery'
  UNION ALL
    SELECT k.id, k.nazwa
    FROM kategorie k
    JOIN potomkowie p ON k.kategoria_nadrzedna_id = p.id
)
SELECT count(DISTINCT a.id) AS liczba_aukcji_w_komputerach
FROM potomkowie pt
JOIN produkty pr ON pr.kategoria_id = pt.id
JOIN aukcje   a  ON a.produkt_id   = pr.id;

\echo ''
\echo '### 8. Funkcja okna RANK() — ranking ofert w wybranych aukcjach (1, 5)'
SELECT o.aukcja_id,
       u.nazwa_uzytkownika AS licytujacy,
       o.kwota,
       rank()       OVER (PARTITION BY o.aukcja_id ORDER BY o.kwota DESC) AS pozycja,
       row_number() OVER (PARTITION BY o.aukcja_id ORDER BY o.kwota DESC) AS lp
FROM oferty o
JOIN uzytkownicy u ON u.id = o.kupujacy_id
WHERE o.aukcja_id IN (1, 5)
ORDER BY o.aukcja_id, pozycja;

\echo ''
\echo '### 9. Funkcja okna — narastająca suma ofert i udział procentowy (aukcja 1)'
SELECT o.aukcja_id,
       u.nazwa_uzytkownika AS licytujacy,
       o.kwota,
       sum(o.kwota) OVER (PARTITION BY o.aukcja_id ORDER BY o.data_zlozenia) AS narastajaco,
       round(100 * o.kwota
             / sum(o.kwota) OVER (PARTITION BY o.aukcja_id), 1) AS udzial_proc
FROM oferty o
JOIN uzytkownicy u ON u.id = o.kupujacy_id
WHERE o.aukcja_id = 1
ORDER BY o.data_zlozenia;

\echo ''
\echo '### 10. DISTINCT ON — najwyższa (wygrywająca) oferta każdej aukcji'
SELECT DISTINCT ON (o.aukcja_id)
       o.aukcja_id, u.nazwa_uzytkownika AS najwyzszy_licytujacy, o.kwota
FROM oferty o
JOIN uzytkownicy u ON u.id = o.kupujacy_id
ORDER BY o.aukcja_id, o.kwota DESC;

\echo ''
\echo '### 11. Agregacja z HAVING — kategorie z co najmniej 2 produktami'
SELECT k.nazwa AS kategoria, count(p.id) AS liczba_produktow
FROM kategorie k
JOIN produkty p ON p.kategoria_id = k.id
GROUP BY k.nazwa
HAVING count(p.id) >= 2
ORDER BY liczba_produktow DESC, k.nazwa;

\echo ''
\echo '### 12. Agregacja z HAVING — sprzedawcy ze średnią oceną >= 4.5'
SELECT u.nazwa_uzytkownika, round(avg(r.ocena), 2) AS srednia_ocena, count(*) AS liczba_ocen
FROM recenzje r
JOIN uzytkownicy u ON u.id = r.oceniany_id
GROUP BY u.nazwa_uzytkownika
HAVING avg(r.ocena) >= 4.5
ORDER BY srednia_ocena DESC, liczba_ocen DESC;

\echo ''
\echo '### 13. EXISTS — sprzedawcy mający obecnie aktywną aukcję'
SELECT u.id, u.nazwa_uzytkownika
FROM uzytkownicy u
WHERE EXISTS (
        SELECT 1 FROM aukcje a
        WHERE a.sprzedajacy_id = u.id AND a.status = 'aktywna'
      )
ORDER BY u.id;

\echo ''
\echo '### 14. Podzapytanie w FROM — średnia liczba ofert przypadająca na aukcję'
SELECT round(avg(liczba_ofert), 2) AS srednia_liczba_ofert_na_aukcje
FROM (
    SELECT a.id, count(o.id) AS liczba_ofert
    FROM aukcje a
    LEFT JOIN oferty o ON o.aukcja_id = a.id
    GROUP BY a.id
) AS zestawienie;

\echo ''
\echo '### 15. Użycie widoków — TOP 5 trwających aukcji wg ceny bieżącej'
SELECT aukcja_id, produkt, kategoria, sprzedajacy, cena_biezaca_z_ofert, liczba_ofert
FROM widok_aktywne_aukcje
ORDER BY cena_biezaca_z_ofert DESC
LIMIT 5;

\echo ''
\echo '### 16. Użycie widoku — ranking sprzedawców'
SELECT * FROM widok_ranking_sprzedajacych;
