-- ============================================================================
--  06_widoki.sql  —  Widoki raportowe
-- ----------------------------------------------------------------------------
--  Widoki upraszczają typowe zapytania i pełnią rolę warstwy bezpieczeństwa
--  (np. widok_profil_uzytkownika NIE ujawnia haslo_hash/e-mail/telefonu —
--  to przez nie role o niższych uprawnieniach czytają dane użytkowników).
-- ============================================================================

-- ----------------------------------------------------------------------------
--  widok_aktywne_aukcje
--  Trwające aukcje wraz z produktem, kategorią, producentem i sprzedającym.
--  Cena bieżąca wyprowadzana JEST z tabeli oferty (MAX(kwota)) — pokazujemy
--  tym samym świadomość, że aukcje.cena_aktualna to redundancja kontrolowana.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW widok_aktywne_aukcje AS
SELECT a.id                                   AS aukcja_id,
       p.nazwa                                AS produkt,
       k.nazwa                                AS kategoria,
       prod.nazwa                             AS producent,
       p.stan,
       u.nazwa_uzytkownika                    AS sprzedajacy,
       a.cena_wywolawcza,
       a.cena_aktualna,
       COALESCE((SELECT max(o.kwota) FROM oferty o WHERE o.aukcja_id = a.id),
                a.cena_wywolawcza)            AS cena_biezaca_z_ofert,
       (SELECT count(*) FROM oferty o WHERE o.aukcja_id = a.id) AS liczba_ofert,
       a.data_zakonczenia,
       (a.data_zakonczenia - now())           AS pozostaly_czas
FROM aukcje a
JOIN produkty    p    ON p.id   = a.produkt_id
JOIN kategorie   k    ON k.id   = p.kategoria_id
JOIN producenci  prod ON prod.id = p.producent_id
JOIN uzytkownicy u    ON u.id   = a.sprzedajacy_id
WHERE a.status = 'aktywna'
  AND a.data_zakonczenia > now()
ORDER BY a.data_zakonczenia;

COMMENT ON VIEW widok_aktywne_aukcje IS 'Trwające aukcje z ceną bieżącą wyliczaną z ofert';

-- ----------------------------------------------------------------------------
--  widok_ranking_sprzedajacych
--  Ranking sprzedawców: liczba sprzedaży, obroty i średnia ocena.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW widok_ranking_sprzedajacych AS
SELECT u.id                                        AS sprzedajacy_id,
       u.nazwa_uzytkownika,
       count(t.id)                                 AS liczba_sprzedazy,
       COALESCE(sum(t.kwota), 0)                    AS suma_obrotow,
       fn_srednia_ocena_sprzedajacego(u.id)        AS srednia_ocena,
       (SELECT count(*) FROM recenzje r WHERE r.oceniany_id = u.id) AS liczba_ocen
FROM uzytkownicy u
LEFT JOIN transakcje t ON t.sprzedajacy_id = u.id
GROUP BY u.id, u.nazwa_uzytkownika
HAVING count(t.id) > 0
ORDER BY suma_obrotow DESC, srednia_ocena DESC NULLS LAST;

COMMENT ON VIEW widok_ranking_sprzedajacych IS 'Ranking sprzedawców wg obrotów i średniej oceny';

-- ----------------------------------------------------------------------------
--  widok_historia_ofert
--  Pełna historia ofert z pozycją (RANK) w obrębie aukcji — funkcja okna.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW widok_historia_ofert AS
SELECT o.id                                AS oferta_id,
       o.aukcja_id,
       p.nazwa                             AS produkt,
       u.nazwa_uzytkownika                 AS licytujacy,
       o.kwota,
       o.data_zlozenia,
       rank() OVER (PARTITION BY o.aukcja_id ORDER BY o.kwota DESC) AS pozycja
FROM oferty o
JOIN aukcje      a ON a.id = o.aukcja_id
JOIN produkty    p ON p.id = a.produkt_id
JOIN uzytkownicy u ON u.id = o.kupujacy_id
ORDER BY o.aukcja_id, o.kwota DESC;

COMMENT ON VIEW widok_historia_ofert IS 'Historia ofert z pozycją (RANK) w aukcji';

-- ----------------------------------------------------------------------------
--  widok_statystyki_kategorii
--  Agregaty per kategoria: liczba produktów, aukcji oraz statystyki cen.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW widok_statystyki_kategorii AS
SELECT k.id                                                       AS kategoria_id,
       k.nazwa                                                    AS kategoria,
       count(DISTINCT p.id)                                       AS liczba_produktow,
       count(DISTINCT a.id)                                       AS liczba_aukcji,
       count(DISTINCT a.id) FILTER (WHERE a.status = 'aktywna')   AS aktywne_aukcje,
       round(avg(a.cena_aktualna), 2)                            AS srednia_cena_aukcji,
       max(a.cena_aktualna)                                       AS najwyzsza_cena
FROM kategorie k
LEFT JOIN produkty p ON p.kategoria_id = k.id
LEFT JOIN aukcje   a ON a.produkt_id   = p.id
GROUP BY k.id, k.nazwa
ORDER BY k.nazwa;

COMMENT ON VIEW widok_statystyki_kategorii IS 'Statystyki produktów i aukcji w rozbiciu na kategorie';

-- ----------------------------------------------------------------------------
--  widok_profil_uzytkownika  (WIDOK BEZPIECZEŃSTWA)
--  Publiczny profil użytkownika BEZ danych wrażliwych (haslo_hash, e-mail,
--  telefon). Role kupujacy/gosc czytają dane użytkowników wyłącznie stąd.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW widok_profil_uzytkownika AS
SELECT u.id,
       u.nazwa_uzytkownika,
       u.imie,
       u.nazwisko,
       u.data_rejestracji,
       u.aktywny,
       fn_srednia_ocena_sprzedajacego(u.id) AS srednia_ocena,
       fn_liczba_aktywnych_aukcji(u.id)     AS liczba_aktywnych_aukcji
FROM uzytkownicy u;

COMMENT ON VIEW widok_profil_uzytkownika IS 'Publiczny profil użytkownika bez danych wrażliwych';
