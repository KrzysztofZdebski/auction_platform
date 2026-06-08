-- ============================================================================
--  00_reset.sql  —  Wyczyszczenie schematu (TYLKO środowisko deweloperskie!)
-- ----------------------------------------------------------------------------
--  Skrypt usuwa wszystkie obiekty schematu `public` (tabele, typy, funkcje,
--  widoki, sekwencje), aby umożliwić ponowne, czyste uruchomienie skryptów
--  01–09. NIE usuwa ról bazodanowych (są obiektami na poziomie klastra) —
--  o ich idempotentne utworzenie dba skrypt 07_role_uprawnienia.sql.
--
--  UWAGA: operacja nieodwracalna. Uruchamiać wyłącznie na bazie testowej.
-- ============================================================================

-- Najprostszy i najpewniejszy sposób usunięcia wszystkich obiektów schematu.
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- Przywrócenie domyślnych uprawnień do schematu.
GRANT ALL ON SCHEMA public TO public;
COMMENT ON SCHEMA public IS 'Domyślny schemat platformy aukcyjnej';

-- Rozszerzenia instalowane są ponownie w skrypcie 07 (pgcrypto).
