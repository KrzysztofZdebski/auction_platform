-- ============================================================================
--  02_indeksy.sql  —  Indeksy wspierające
-- ----------------------------------------------------------------------------
--  Klucze główne (PRIMARY KEY) oraz ograniczenia UNIQUE są automatycznie
--  indeksowane przez PostgreSQL. NIE dotyczy to kluczy obcych (FOREIGN KEY) —
--  dla nich indeksy trzeba założyć ręcznie (przyspieszają złączenia oraz
--  weryfikację ON DELETE).
--
--  Zgodnie z założeniami projektu (cel: ocena 4.5) zakładamy wyłącznie
--  PODSTAWOWE indeksy wspierające klucze obce i najczęstsze zapytania.
--  Analiza wydajności (EXPLAIN, strojenie) to zakres oceny 5.0 — pominięty.
-- ============================================================================

-- Klucze obce (FK) — indeksowane ręcznie.
CREATE INDEX idx_adresy_uzytkownik       ON adresy(uzytkownik_id);
CREATE INDEX idx_kategorie_nadrzedna     ON kategorie(kategoria_nadrzedna_id);
CREATE INDEX idx_produkty_kategoria      ON produkty(kategoria_id);
CREATE INDEX idx_produkty_producent      ON produkty(producent_id);
CREATE INDEX idx_aukcje_produkt          ON aukcje(produkt_id);
CREATE INDEX idx_aukcje_sprzedajacy      ON aukcje(sprzedajacy_id);
CREATE INDEX idx_aukcje_zwyciezca        ON aukcje(zwyciezca_id);
CREATE INDEX idx_oferty_aukcja           ON oferty(aukcja_id);
CREATE INDEX idx_oferty_kupujacy         ON oferty(kupujacy_id);
CREATE INDEX idx_transakcje_kupujacy     ON transakcje(kupujacy_id);
CREATE INDEX idx_transakcje_sprzedajacy  ON transakcje(sprzedajacy_id);
CREATE INDEX idx_transakcje_metoda       ON transakcje(metoda_platnosci_id);
CREATE INDEX idx_recenzje_transakcja     ON recenzje(transakcja_id);
CREATE INDEX idx_recenzje_oceniany       ON recenzje(oceniany_id);
CREATE INDEX idx_obserwowane_aukcja      ON obserwowane(aukcja_id);

-- Indeksy wspierające typowe zapytania platformy.
-- Wyszukiwanie aukcji aktywnych kończących się najbliżej (indeks częściowy).
CREATE INDEX idx_aukcje_aktywne_koniec
    ON aukcje(data_zakonczenia)
    WHERE status = 'aktywna';

-- Wyłanianie najwyższej oferty w aukcji: MAX(kwota) per aukcja_id.
CREATE INDEX idx_oferty_aukcja_kwota
    ON oferty(aukcja_id, kwota DESC);

-- Przeszukiwanie dziennika audytowego po tabeli i czasie.
CREATE INDEX idx_dziennik_tabela_czas
    ON dziennik_zmian(tabela, czas);
