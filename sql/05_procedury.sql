-- ============================================================================
--  05_procedury.sql  —  Procedury składowane (transakcje, poziomy izolacji)
-- ----------------------------------------------------------------------------
--  Procedury realizują operacje biznesowe jako jednostki atomowe. Wybór
--  POZIOMU IZOLACJI należy do sesji wołającej (np. demo/sesja_A.sql) — to
--  poprawne podejście w PostgreSQL, gdzie `SET TRANSACTION ISOLATION LEVEL`
--  musi być pierwszą instrukcją transakcji. Tutaj dbamy o atomowość,
--  blokady wierszy (FOR UPDATE) i obsługę wyjątków.
-- ============================================================================

-- pgcrypto wymagane przez zarejestruj_uzytkownika (crypt/gen_salt).
-- Instalowane idempotentnie; pełny opis bezpieczeństwa w 07_role_uprawnienia.sql.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
--  zarejestruj_uzytkownika(...)
--  Rejestruje użytkownika, hashując hasło algorytmem bcrypt (pgcrypto).
--  Zwraca identyfikator nowego konta przez parametr INOUT p_id.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE zarejestruj_uzytkownika(
    IN    p_nazwa     VARCHAR,
    IN    p_email     VARCHAR,
    IN    p_haslo     TEXT,
    IN    p_imie      VARCHAR DEFAULT NULL,
    IN    p_nazwisko  VARCHAR DEFAULT NULL,
    IN    p_telefon   VARCHAR DEFAULT NULL,
    INOUT p_id        BIGINT  DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER                       -- gość rejestruje konto bez praw do tabeli uzytkownicy
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO uzytkownicy (nazwa_uzytkownika, email, haslo_hash,
                             imie, nazwisko, telefon)
    VALUES (p_nazwa, p_email,
            crypt(p_haslo, gen_salt('bf')),   -- skrót bcrypt
            p_imie, p_nazwisko, p_telefon)
    RETURNING id INTO p_id;

    RAISE NOTICE 'Zarejestrowano użytkownika % (id=%)', p_nazwa, p_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Nazwa użytkownika lub e-mail już istnieje (%, %)',
            p_nazwa, p_email;
END;
$$;

-- ----------------------------------------------------------------------------
--  fn_weryfikuj_haslo(nazwa, haslo) -> BOOLEAN
--  Funkcja pomocnicza do logowania: porównuje hasło ze skrótem bcrypt.
--  (Funkcja, nie procedura — używana w wyrażeniu SELECT.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_weryfikuj_haslo(p_nazwa VARCHAR, p_haslo TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER                       -- logowanie bez ujawniania haslo_hash wołającemu
SET search_path = public, pg_temp
AS $$
DECLARE
    v_hash TEXT;
BEGIN
    SELECT haslo_hash INTO v_hash
      FROM uzytkownicy
     WHERE nazwa_uzytkownika = p_nazwa AND aktywny;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- crypt(podane_haslo, zapisany_hash) = zapisany_hash  <=> hasło poprawne
    RETURN v_hash = crypt(p_haslo, v_hash);
END;
$$;

-- ----------------------------------------------------------------------------
--  zloz_oferte(aukcja_id, kupujacy_id, kwota)
--  Składa ofertę w aukcji. Walidację (aukcja aktywna, kwota >= minimum,
--  licytujący != sprzedający) wykonuje wyzwalacz trg_walidacja_oferty,
--  a aktualizację ceny — trg_aktualizuj_cene.
--
--  ZALECENIE: wołać w transakcji REPEATABLE READ lub SERIALIZABLE, aby
--  uniknąć anomalii przy równoczesnych ofertach. W razie błędu serializacji
--  (SQLSTATE 40001) transakcję należy PONOWIĆ — patrz demo/.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE zloz_oferte(
    IN p_aukcja_id   BIGINT,
    IN p_kupujacy_id BIGINT,
    IN p_kwota       NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO oferty (aukcja_id, kupujacy_id, kwota)
    VALUES (p_aukcja_id, p_kupujacy_id, p_kwota)
    RETURNING id INTO v_id;

    RAISE NOTICE 'Przyjęto ofertę % zł w aukcji % (oferta id=%)',
        p_kwota, p_aukcja_id, v_id;
END;
$$;

-- ----------------------------------------------------------------------------
--  zakoncz_aukcje(aukcja_id, metoda_platnosci_id)
--  Atomowo rozlicza aukcję:
--    * blokuje wiersz aukcji (FOR UPDATE),
--    * wyłania zwycięzcę (najwyższa oferta),
--    * sprawdza cenę rezerwową (jeśli nieosiągnięta — brak zwycięzcy),
--    * ustawia status='zakonczona' i zwyciezca_id,
--    * tworzy rekord w transakcje (gdy jest zwycięzca).
--  ZALECANY poziom izolacji wołającego: SERIALIZABLE.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE zakoncz_aukcje(
    IN p_aukcja_id          BIGINT,
    IN p_metoda_platnosci_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_aukcja        aukcje%ROWTYPE;
    v_max_kwota     NUMERIC;
    v_zwyciezca     BIGINT;
    v_metoda        BIGINT;
BEGIN
    -- Blokada wiersza aukcji do końca transakcji.
    SELECT * INTO v_aukcja FROM aukcje WHERE id = p_aukcja_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aukcja o id=% nie istnieje', p_aukcja_id;
    END IF;

    IF v_aukcja.status <> 'aktywna' THEN
        RAISE EXCEPTION 'Aukcja % nie jest aktywna (status=%)',
            p_aukcja_id, v_aukcja.status;
    END IF;

    -- Najwyższa oferta i jej autor.
    SELECT o.kwota, o.kupujacy_id
      INTO v_max_kwota, v_zwyciezca
      FROM oferty o
     WHERE o.aukcja_id = p_aukcja_id
     ORDER BY o.kwota DESC, o.data_zlozenia ASC
     LIMIT 1;

    -- Przypadek 1: brak ofert lub niespełniona cena rezerwowa -> bez zwycięzcy.
    IF v_zwyciezca IS NULL
       OR (v_aukcja.cena_minimalna IS NOT NULL
           AND v_max_kwota < v_aukcja.cena_minimalna) THEN
        UPDATE aukcje
           SET status = 'zakonczona'
         WHERE id = p_aukcja_id;
        RAISE NOTICE 'Aukcja % zakończona bez rozstrzygnięcia (brak ofert lub cena rezerwowa nieosiągnięta)',
            p_aukcja_id;
        RETURN;
    END IF;

    -- Przypadek 2: jest zwycięzca -> rozliczenie.
    UPDATE aukcje
       SET status        = 'zakonczona',
           zwyciezca_id  = v_zwyciezca,
           cena_aktualna = v_max_kwota
     WHERE id = p_aukcja_id;

    -- Domyślna metoda płatności: pierwsza dostępna, gdy nie podano.
    v_metoda := COALESCE(p_metoda_platnosci_id,
                         (SELECT id FROM metody_platnosci ORDER BY id LIMIT 1));

    INSERT INTO transakcje (aukcja_id, kupujacy_id, sprzedajacy_id,
                            kwota, metoda_platnosci_id, status_platnosci)
    VALUES (p_aukcja_id, v_zwyciezca, v_aukcja.sprzedajacy_id,
            v_max_kwota, v_metoda, 'oczekujaca');

    RAISE NOTICE 'Aukcja % rozliczona: zwycięzca=%, kwota=% zł',
        p_aukcja_id, v_zwyciezca, v_max_kwota;
END;
$$;

-- ----------------------------------------------------------------------------
--  zakoncz_wygasle_aukcje()
--  Wsadowe zamknięcie wszystkich aukcji, których czas już minął.
--  PostgreSQL nie ma wyzwalaczy czasowych — w praktyce wywoływane cyklicznie
--  przez harmonogram (np. rozszerzenie pg_cron albo zadanie systemowe cron).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE zakoncz_wygasle_aukcje()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rek   RECORD;
    v_ile   INTEGER := 0;
BEGIN
    FOR v_rek IN
        SELECT id FROM aukcje
         WHERE status = 'aktywna' AND data_zakonczenia <= now()
         ORDER BY id
    LOOP
        CALL zakoncz_aukcje(v_rek.id, NULL);
        v_ile := v_ile + 1;
    END LOOP;

    RAISE NOTICE 'Zamknięto % wygasłych aukcji', v_ile;
END;
$$;
