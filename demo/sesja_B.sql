-- =====================================================================
--  demo/sesja_B.sql  —  SESJA B (okno psql nr 2)
-- ---------------------------------------------------------------------
--  Uruchamiać KROK PO KROKU, naprzemiennie z demo/sesja_A.sql.
--  Poziom izolacji w KROKU B1 MUSI być taki sam jak w sesji A.
-- =====================================================================

-- KROK B1: rozpocznij transakcję o tym samym poziomie izolacji co sesja A
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- KROK B2: odczytaj stan aukcji — wciąż 1900, bo sesja A nie zatwierdziła
--          jeszcze swojej oferty (izolacja migawkowa).
SELECT id, cena_aktualna FROM aukcje WHERE id = 11;
SELECT fn_min_kolejna_oferta(11) AS min_oferta;        -- oczekiwane: 1950

-- KROK B3: złóż ofertę 1950 zł — ta instrukcja SIĘ ZABLOKUJE, ponieważ
--          wyzwalacz AFTER próbuje zaktualizować ten sam wiersz aukcji,
--          zablokowany przez niezatwierdzoną sesję A.
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (11, 16, 1950);

-- >>> WRÓĆ DO SESJI A i wykonaj KROK A4 (COMMIT) <<<

-- KROK B4: po zatwierdzeniu sesji A instrukcja z kroku B3 odblokuje się:
--
--   * SERIALIZABLE / REPEATABLE READ  ->
--       ERROR: could not serialize access due to concurrent update
--       (SQLSTATE 40001) — transakcję NALEŻY wycofać i PONOWIĆ:
--
--           ROLLBACK;
--
--   * READ COMMITTED ->
--       instrukcja wykonuje się bez błędu i przyjmuje DRUGĄ ofertę 1950 zł.
--       To ANOMALIA: dwie równe „najwyższe" oferty, mimo że druga nie
--       przebiła pierwszej. W takim wariancie zakończ przez:
--
--           COMMIT;

-- ---------------------------------------------------------------------
-- KROK B5 (tylko dla wariantu SERIALIZABLE, po ROLLBACK):
--   ponowienie transakcji. Sesja A zatwierdziła 1950, więc bieżąca cena
--   to 1950, a minimalna kolejna oferta = 2000. Próba 1950 zostałaby teraz
--   słusznie odrzucona przez wyzwalacz jako zbyt niska.
-- ---------------------------------------------------------------------
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT fn_min_kolejna_oferta(11) AS min_oferta_po_ponowieniu;  -- oczekiwane: 2000
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (11, 16, 2000);
COMMIT;
