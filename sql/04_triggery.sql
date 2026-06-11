-- ============================================================================
--  04_triggery.sql  —  Funkcje wyzwalaczy i wyzwalacze
-- ----------------------------------------------------------------------------
--  Reguły biznesowe i audyt egzekwowane na poziomie bazy danych:
--    * trg_walidacja_oferty   — poprawność składanej oferty (BEFORE INSERT),
--    * trg_aktualizuj_cene     — aktualizacja aukcje.cena_aktualna (AFTER INSERT),
--    * trg_walidacja_recenzji  — recenzję wystawia tylko strona transakcji,
--    * trg_audyt               — zapis zmian do dziennik_zmian (AFTER I/U/D).
-- ============================================================================

-- ----------------------------------------------------------------------------
--  Wyzwalacz walidacji oferty — BEFORE INSERT ON oferty
--  Warunki: aukcja istnieje i jest aktywna, nie wygasła, kwota >= minimalnej
--  kolejnej oferty, a licytujący nie jest sprzedającym.
-- ----------------------------------------------------------------------------
-- SECURITY DEFINER: wyzwalacze działają z uprawnieniami właściciela, dzięki
-- czemu role o ograniczonych prawach (np. rola_kupujacy) mogą wstawić ofertę,
-- mimo że kaskadowo aktualizuje ona aukcje.cena_aktualna i dziennik_zmian —
-- tabele, do których nie mają bezpośredniego dostępu. SET search_path chroni
-- przed przejęciem przez obiekty z innych schematów (dobra praktyka DEFINER).
CREATE OR REPLACE FUNCTION fn_trg_walidacja_oferty()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_aukcja  aukcje%ROWTYPE;
    v_min     NUMERIC;
BEGIN
    -- Walidacja na podstawie bieżącej migawki (bez FOR UPDATE). Bezpieczeństwo
    -- współbieżne celowo delegujemy do POZIOMU IZOLACJI transakcji wołającej
    -- (patrz demo/). Naturalnym punktem serializacji jest współdzielona
    -- aktualizacja aukcje.cena_aktualna w wyzwalaczu trg_aktualizuj_cene:
    -- pod SERIALIZABLE dwie równoczesne oferty dają błąd serializacji, a pod
    -- READ COMMITTED ujawnia się anomalia (obie oferty przyjęte).
    SELECT * INTO v_aukcja FROM aukcje WHERE id = NEW.aukcja_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aukcja o id=% nie istnieje', NEW.aukcja_id;
    END IF;

    IF v_aukcja.status <> 'aktywna' THEN
        RAISE EXCEPTION 'Nie można licytować — aukcja % ma status %',
            NEW.aukcja_id, v_aukcja.status;
    END IF;

    IF v_aukcja.data_zakonczenia <= now() THEN
        RAISE EXCEPTION 'Nie można licytować — aukcja % już się zakończyła (%)' ,
            NEW.aukcja_id, v_aukcja.data_zakonczenia;
    END IF;

    IF NEW.kupujacy_id = v_aukcja.sprzedajacy_id THEN
        RAISE EXCEPTION 'Sprzedający nie może licytować własnej aukcji (%)',
            NEW.aukcja_id;
    END IF;

    v_min := fn_min_kolejna_oferta(NEW.aukcja_id);
    IF NEW.kwota < v_min THEN
        RAISE EXCEPTION 'Oferta % zł jest za niska — wymagane minimum to % zł',
            NEW.kwota, v_min;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_walidacja_oferty
    BEFORE INSERT ON oferty
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_walidacja_oferty();

-- ----------------------------------------------------------------------------
--  Wyzwalacz aktualizacji ceny — AFTER INSERT ON oferty
--  Po przyjęciu poprawnej oferty (najwyższej dotąd) aktualizuje
--  redundantną kolumnę aukcje.cena_aktualna.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_aktualizuj_cene()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE aukcje
       SET cena_aktualna = NEW.kwota
     WHERE id = NEW.aukcja_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_aktualizuj_cene
    AFTER INSERT ON oferty
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_aktualizuj_cene();

-- ----------------------------------------------------------------------------
--  Wyzwalacz walidacji recenzji — BEFORE INSERT ON recenzje
--  Recenzję może wystawić wyłącznie jedna ze stron transakcji, a oceniany
--  musi być drugą stroną tej samej transakcji.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_walidacja_recenzji()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_kupujacy    BIGINT;
    v_sprzedajacy BIGINT;
BEGIN
    SELECT kupujacy_id, sprzedajacy_id
      INTO v_kupujacy, v_sprzedajacy
      FROM transakcje
     WHERE id = NEW.transakcja_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transakcja o id=% nie istnieje', NEW.transakcja_id;
    END IF;

    IF NEW.autor_id NOT IN (v_kupujacy, v_sprzedajacy) THEN
        RAISE EXCEPTION 'Recenzję może wystawić tylko strona transakcji %',
            NEW.transakcja_id;
    END IF;

    IF NEW.oceniany_id NOT IN (v_kupujacy, v_sprzedajacy)
       OR NEW.oceniany_id = NEW.autor_id THEN
        RAISE EXCEPTION 'Oceniany musi być drugą stroną transakcji %',
            NEW.transakcja_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_walidacja_recenzji
    BEFORE INSERT ON recenzje
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_walidacja_recenzji();

-- ----------------------------------------------------------------------------
--  Wyzwalacz audytowy — AFTER INSERT/UPDATE/DELETE na kluczowych tabelach.
--  Zapisuje operację i pełną treść wiersza (JSONB) do dziennik_zmian.
--  Jedna funkcja obsługuje wszystkie tabele (uniwersalna, oparta o TG_OP).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_audyt()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_dane       JSONB;
    v_id_rekordu TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_dane       := to_jsonb(NEW);
        v_id_rekordu := v_dane ->> 'id';
    ELSIF TG_OP = 'UPDATE' THEN
        v_dane       := jsonb_build_object('stare', to_jsonb(OLD),
                                           'nowe',  to_jsonb(NEW));
        v_id_rekordu := to_jsonb(NEW) ->> 'id';
    ELSE  -- DELETE
        v_dane       := to_jsonb(OLD);
        v_id_rekordu := v_dane ->> 'id';
    END IF;

    -- session_user (a nie current_user) — pod SECURITY DEFINER rejestruje
    -- realnego użytkownika sesji, nie właściciela funkcji.
    INSERT INTO dziennik_zmian (tabela, operacja, id_rekordu, dane, uzytkownik_db)
    VALUES (TG_TABLE_NAME, TG_OP, v_id_rekordu, v_dane, session_user);

    -- Wartość zwracana nieistotna dla wyzwalacza AFTER, ale wymagana składniowo.
    RETURN NULL;
END;
$$;

-- Podpięcie wyzwalacza audytowego do kluczowych tabel.
CREATE TRIGGER trg_audyt_uzytkownicy
    AFTER INSERT OR UPDATE OR DELETE ON uzytkownicy
    FOR EACH ROW EXECUTE FUNCTION fn_trg_audyt();

CREATE TRIGGER trg_audyt_produkty
    AFTER INSERT OR UPDATE OR DELETE ON produkty
    FOR EACH ROW EXECUTE FUNCTION fn_trg_audyt();

CREATE TRIGGER trg_audyt_aukcje
    AFTER INSERT OR UPDATE OR DELETE ON aukcje
    FOR EACH ROW EXECUTE FUNCTION fn_trg_audyt();

CREATE TRIGGER trg_audyt_oferty
    AFTER INSERT OR UPDATE OR DELETE ON oferty
    FOR EACH ROW EXECUTE FUNCTION fn_trg_audyt();

CREATE TRIGGER trg_audyt_transakcje
    AFTER INSERT OR UPDATE OR DELETE ON transakcje
    FOR EACH ROW EXECUTE FUNCTION fn_trg_audyt();
