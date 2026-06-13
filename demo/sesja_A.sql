-- =====================================================================
--  demo/sesja_A.sql  —  SESJA A (okno psql nr 1)
-- ---------------------------------------------------------------------
--  Uruchamiać KROK PO KROKU (kopiując kolejne polecenia), naprzemiennie
--  z demo/sesja_B.sql, zgodnie z kolejnością opisaną w
--  demo/transakcje_izolacja.md.
--
--  Założenie: świeżo załadowane dane testowe (skrypty 01–08).
--  Aukcja 11:  cena_aktualna = 1900,  krok_przebicia = 50,
--              fn_min_kolejna_oferta(11) = 1950.
--
--  Aby porównać poziomy izolacji, zmień poziom w KROKU A1:
--      SERIALIZABLE      -> sesja B dostanie błąd serializacji (40001),
--      READ COMMITTED    -> sesja B przyjmie ofertę (ujawni się anomalia).
-- =====================================================================

-- KROK A1: rozpocznij transakcję o podwyższonej izolacji
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- KROK A2: odczytaj stan aukcji i minimalną dopuszczalną ofertę
SELECT id, cena_aktualna FROM aukcje WHERE id = 11;
SELECT fn_min_kolejna_oferta(11) AS min_oferta;        -- oczekiwane: 1950

-- KROK A3: złóż ofertę 1950 zł  (NIE zatwierdzaj jeszcze transakcji!)
--          Wyzwalacz AFTER zaktualizuje aukcje.cena_aktualna i ZABLOKUJE
--          wiersz aukcji do czasu COMMIT/ROLLBACK.
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (11, 14, 1950);

-- >>> PRZEŁĄCZ SIĘ NA SESJĘ B i wykonaj kroki B1–B3 <<<

-- KROK A4: zatwierdź transakcję (zwalnia blokadę wiersza aukcji)
COMMIT;

-- >>> WRÓĆ DO SESJI B i obserwuj wynik zablokowanej instrukcji (krok B4) <<<

-- Podgląd końcowy (po zakończeniu całego scenariusza):
-- SELECT id, kwota, kupujacy_id, data_zlozenia FROM oferty
--   WHERE aukcja_id = 11 ORDER BY id;
