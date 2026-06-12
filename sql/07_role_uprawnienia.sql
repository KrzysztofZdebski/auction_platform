-- ============================================================================
--  07_role_uprawnienia.sql  —  Bezpieczeństwo: role, uprawnienia, pgcrypto
-- ----------------------------------------------------------------------------
--  Model bezpieczeństwa platformy:
--    * rola_gosc        — wyłącznie odczyt katalogu i widoków publicznych,
--    * rola_kupujacy    — licytowanie, obserwowanie, recenzje (dziedziczy gościa),
--    * rola_sprzedajacy — zarządzanie produktami i aukcjami (dziedziczy kupującego),
--    * rola_admin       — pełnia praw.
--
--  Zasady ochrony danych wrażliwych:
--    * tabela `uzytkownicy` (haslo_hash, email, telefon) oraz `adresy` NIE są
--      udostępniane rolom niższym — dane użytkowników widoczne tylko przez
--      widok_profil_uzytkownika (bez kolumn wrażliwych),
--    * hasła przechowywane jako skróty bcrypt (pgcrypto),
--    * rejestracja i logowanie realizowane funkcjami SECURITY DEFINER, więc
--      gość nie potrzebuje bezpośredniego dostępu do tabeli uzytkownicy.
-- ============================================================================

-- ----------------------------------------------------------------------------
--  Rozszerzenie pgcrypto — skróty haseł bcrypt (crypt + gen_salt('bf')).
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
--  Utworzenie ról (idempotentnie — pomijane, jeśli już istnieją).
--  Role grupowe NOLOGIN; konta logowania zakłada się jako ich członków.
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rola_gosc') THEN
        CREATE ROLE rola_gosc NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rola_kupujacy') THEN
        CREATE ROLE rola_kupujacy NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rola_sprzedajacy') THEN
        CREATE ROLE rola_sprzedajacy NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rola_admin') THEN
        CREATE ROLE rola_admin NOLOGIN;
    END IF;
END$$;

-- Hierarchia dziedziczenia uprawnień (gosc < kupujacy < sprzedajacy < admin).
GRANT rola_gosc        TO rola_kupujacy;
GRANT rola_kupujacy    TO rola_sprzedajacy;
GRANT rola_sprzedajacy TO rola_admin;

-- Dostęp do schematu dla wszystkich ról.
GRANT USAGE ON SCHEMA public TO rola_gosc, rola_kupujacy, rola_sprzedajacy, rola_admin;

-- ----------------------------------------------------------------------------
--  ROLA_GOSC — tylko odczyt publicznego katalogu i widoków.
--  Brak dostępu do tabel z danymi osobowymi (uzytkownicy, adresy,
--  transakcje, oferty).
-- ----------------------------------------------------------------------------
GRANT SELECT ON kategorie, producenci, produkty, metody_platnosci TO rola_gosc;
GRANT SELECT ON widok_aktywne_aukcje,
                widok_ranking_sprzedajacych,
                widok_statystyki_kategorii,
                widok_profil_uzytkownika,
                widok_historia_ofert
      TO rola_gosc;

-- ----------------------------------------------------------------------------
--  ROLA_KUPUJACY — przegląd aukcji i licytowanie (dziedziczy gościa).
--  Może składać oferty, obserwować aukcje i wystawiać recenzje.
--  Nie ma bezpośredniego dostępu do tabeli uzytkownicy (FK działa mimo to —
--  kontrola integralności nie wymaga uprawnienia SELECT do tabeli nadrzędnej).
-- ----------------------------------------------------------------------------
GRANT SELECT ON aukcje, oferty, recenzje, obserwowane TO rola_kupujacy;
GRANT INSERT ON oferty           TO rola_kupujacy;
GRANT INSERT ON recenzje         TO rola_kupujacy;
GRANT INSERT, DELETE ON obserwowane TO rola_kupujacy;

-- ----------------------------------------------------------------------------
--  ROLA_SPRZEDAJACY — wystawianie produktów i aukcji (dziedziczy kupującego).
-- ----------------------------------------------------------------------------
GRANT INSERT, UPDATE ON produkty TO rola_sprzedajacy;
GRANT INSERT, UPDATE ON aukcje   TO rola_sprzedajacy;
GRANT SELECT ON transakcje       TO rola_sprzedajacy;

-- ----------------------------------------------------------------------------
--  ROLA_ADMIN — pełnia praw do wszystkich obiektów schematu.
-- ----------------------------------------------------------------------------
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO rola_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rola_admin;

-- ----------------------------------------------------------------------------
--  Uprawnienia do procedur i funkcji.
--  Domyślnie PUBLIC ma EXECUTE na funkcjach — operacje wrażliwe odbieramy
--  i nadajemy wybiórczo.
-- ----------------------------------------------------------------------------
-- Rozliczanie aukcji — tylko administrator.
REVOKE EXECUTE ON PROCEDURE zakoncz_aukcje(BIGINT, BIGINT) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE zakoncz_wygasle_aukcje()       FROM PUBLIC;
GRANT  EXECUTE ON PROCEDURE zakoncz_aukcje(BIGINT, BIGINT) TO rola_admin;
GRANT  EXECUTE ON PROCEDURE zakoncz_wygasle_aukcje()       TO rola_admin;

-- Składanie ofert — kupujący (i wyżej przez dziedziczenie).
REVOKE EXECUTE ON PROCEDURE zloz_oferte(BIGINT, BIGINT, NUMERIC) FROM PUBLIC;
GRANT  EXECUTE ON PROCEDURE zloz_oferte(BIGINT, BIGINT, NUMERIC) TO rola_kupujacy, rola_admin;

-- Rejestracja konta — dostępna dla gościa (funkcja SECURITY DEFINER chroni tabelę).
REVOKE EXECUTE ON PROCEDURE
    zarejestruj_uzytkownika(VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR, VARCHAR, BIGINT)
    FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE
    zarejestruj_uzytkownika(VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR, VARCHAR, BIGINT)
    TO rola_gosc, rola_admin;

-- Weryfikacja hasła (logowanie) — SECURITY DEFINER, nie ujawnia haslo_hash;
-- pozostaje dostępna dla wszystkich (PUBLIC EXECUTE).

-- ----------------------------------------------------------------------------
--  (Opcjonalnie) Przykładowe konta logowania jako członkowie ról.
--  Uwaga: rzeczywiste logowanie hasłem wymaga konfiguracji pg_hba.conf.
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'demo_admin') THEN
        CREATE ROLE demo_admin       LOGIN PASSWORD 'demo' IN ROLE rola_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'demo_sprzedajacy') THEN
        CREATE ROLE demo_sprzedajacy LOGIN PASSWORD 'demo' IN ROLE rola_sprzedajacy;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'demo_kupujacy') THEN
        CREATE ROLE demo_kupujacy     LOGIN PASSWORD 'demo' IN ROLE rola_kupujacy;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'demo_gosc') THEN
        CREATE ROLE demo_gosc         LOGIN PASSWORD 'demo' IN ROLE rola_gosc;
    END IF;
END$$;

-- ============================================================================
--  SCENARIUSZE TESTOWE (uruchamiać RĘCZNIE — część celowo kończy się błędem
--  "permission denied", co potwierdza działanie ochrony).
-- ----------------------------------------------------------------------------
--  -- Wcielenie się w rolę gościa:
--  SET ROLE rola_gosc;
--  SELECT * FROM widok_aktywne_aukcje LIMIT 3;          -- OK
--  SELECT * FROM widok_profil_uzytkownika LIMIT 3;       -- OK (bez haslo_hash)
--  SELECT haslo_hash FROM uzytkownicy LIMIT 1;           -- BŁĄD: permission denied
--  RESET ROLE;
--
--  -- Kupujący nie może wystawić aukcji:
--  SET ROLE rola_kupujacy;
--  INSERT INTO aukcje(produkt_id, sprzedajacy_id, cena_wywolawcza, cena_aktualna,
--                     data_zakonczenia) VALUES (1,1,100,100, now()+interval '1 day');
--                                                        -- BŁĄD: permission denied
--  CALL zloz_oferte(11, 14, 2000);                       -- OK (licytacja)
--  RESET ROLE;
--
--  -- Logowanie bez ujawniania skrótu hasła (działa dla każdej roli):
--  SELECT fn_weryfikuj_haslo('akowalski', 'Haslo123!');  -- TRUE
--  SELECT fn_weryfikuj_haslo('akowalski', 'zle_haslo');  -- FALSE
-- ============================================================================

-- ----------------------------------------------------------------------------
--  Kierunek rozwoju (ponad wymagania): Row-Level Security (RLS) pozwoliłby
--  ograniczyć widoczność wierszy per użytkownik, np. aby sprzedający widział
--  wyłącznie własne aukcje:
--      ALTER TABLE aukcje ENABLE ROW LEVEL SECURITY;
--      CREATE POLICY p_wlasne_aukcje ON aukcje USING (sprzedajacy_id = ...);
--  W tym projekcie pozostajemy przy modelu ról + widoków.
-- ----------------------------------------------------------------------------
