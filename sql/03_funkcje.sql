-- ============================================================================
--  03_funkcje.sql  —  Funkcje PL/pgSQL
-- ----------------------------------------------------------------------------
--  Funkcje pomocnicze wykorzystywane w widokach, wyzwalaczach i procedurach.
--  Oznaczone jako STABLE — w obrębie jednego zapytania zwracają spójny wynik
--  i nie modyfikują bazy.
-- ============================================================================

-- ----------------------------------------------------------------------------
--  fn_srednia_ocena_sprzedajacego(uzytkownik_id) -> NUMERIC
--  Średnia ocen otrzymanych przez użytkownika jako oceniany (recenzje).
--  Zwraca NULL, gdy użytkownik nie ma jeszcze żadnej recenzji.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_srednia_ocena_sprzedajacego(p_uzytkownik_id BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_srednia NUMERIC;
BEGIN
    SELECT round(avg(ocena), 2)
      INTO v_srednia
      FROM recenzje
     WHERE oceniany_id = p_uzytkownik_id;

    RETURN v_srednia;   -- NULL, jeśli brak recenzji
END;
$$;

COMMENT ON FUNCTION fn_srednia_ocena_sprzedajacego(BIGINT)
    IS 'Średnia ocen otrzymanych przez użytkownika (NULL gdy brak recenzji)';

-- ----------------------------------------------------------------------------
--  fn_liczba_aktywnych_aukcji(uzytkownik_id) -> INTEGER
--  Liczba aktywnych aukcji wystawionych przez danego sprzedającego.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_liczba_aktywnych_aukcji(p_uzytkownik_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_liczba INTEGER;
BEGIN
    SELECT count(*)
      INTO v_liczba
      FROM aukcje
     WHERE sprzedajacy_id = p_uzytkownik_id
       AND status = 'aktywna';

    RETURN v_liczba;
END;
$$;

COMMENT ON FUNCTION fn_liczba_aktywnych_aukcji(BIGINT)
    IS 'Liczba aktywnych aukcji wystawionych przez użytkownika';

-- ----------------------------------------------------------------------------
--  fn_min_kolejna_oferta(aukcja_id) -> NUMERIC
--  Minimalna dopuszczalna kwota kolejnej oferty:
--    * brak ofert  -> cena wywoławcza (pierwsza oferta może ją zrównać),
--    * są oferty   -> aktualna cena + krok przebicia danej aukcji.
--  Zgłasza wyjątek, gdy aukcja nie istnieje.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_min_kolejna_oferta(p_aukcja_id BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_aukcja        aukcje%ROWTYPE;
    v_liczba_ofert  INTEGER;
BEGIN
    SELECT * INTO v_aukcja FROM aukcje WHERE id = p_aukcja_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aukcja o id=% nie istnieje', p_aukcja_id
            USING ERRCODE = 'no_data_found';
    END IF;

    SELECT count(*) INTO v_liczba_ofert FROM oferty WHERE aukcja_id = p_aukcja_id;

    IF v_liczba_ofert = 0 THEN
        RETURN v_aukcja.cena_wywolawcza;
    ELSE
        RETURN v_aukcja.cena_aktualna + v_aukcja.krok_przebicia;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_min_kolejna_oferta(BIGINT)
    IS 'Minimalna dopuszczalna kwota kolejnej oferty (cena wywoławcza lub cena_aktualna + krok)';
