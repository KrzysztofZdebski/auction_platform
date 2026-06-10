-- ============================================================================
--  08_dane_testowe.sql  —  Realistyczny zestaw danych testowych
-- ----------------------------------------------------------------------------
--  WAŻNE: uruchamiać PO 04_triggery.sql i 05_procedury.sql. Dane wstawiane są
--  z WŁĄCZONYMI wyzwalaczami, dzięki czemu:
--    * aukcje.cena_aktualna aktualizuje się automatycznie po każdej ofercie,
--    * każda operacja trafia do dziennik_zmian (audyt),
--    * walidacje ofert/recenzji są egzekwowane jak w działającym systemie.
--
--  Aukcje wstawiane są jako 'aktywna' z datą zakończenia w przyszłości (aby
--  oferty przeszły walidację), następnie część z nich jest rozliczana
--  procedurą zakoncz_aukcje, a daty zakończenia cofane w przeszłość — co daje
--  spójny obraz aukcji zakończonych, wygasłych i wciąż trwających.
--
--  Hasło wszystkich kont testowych: 'Haslo123!' (skrót bcrypt, pgcrypto).
-- ============================================================================

-- ----------------------------------------------------------------------------
--  Metody płatności
-- ----------------------------------------------------------------------------
INSERT INTO metody_platnosci (id, nazwa) VALUES
    (1, 'Przelew bankowy'),
    (2, 'BLIK'),
    (3, 'Karta płatnicza'),
    (4, 'PayPal'),
    (5, 'Płatność przy odbiorze');

-- ----------------------------------------------------------------------------
--  Kategorie (hierarchia: Elektronika -> ... )
-- ----------------------------------------------------------------------------
INSERT INTO kategorie (id, nazwa, kategoria_nadrzedna_id) VALUES
    (1,  'Elektronika',            NULL),
    (2,  'Komputery',              1),
    (3,  'Laptopy',                2),
    (4,  'Komputery stacjonarne',  2),
    (5,  'Podzespoły komputerowe', 2),
    (6,  'Telefony i akcesoria',   1),
    (7,  'Smartfony',              6),
    (8,  'Smartwatche',            6),
    (9,  'Audio',                  1),
    (10, 'Słuchawki',              9),
    (11, 'Głośniki',               9),
    (12, 'TV i monitory',          1),
    (13, 'Telewizory',             12),
    (14, 'Monitory',               12),
    (15, 'Fotografia',             1),
    (16, 'Aparaty cyfrowe',        15),
    (17, 'Obiektywy',              15),
    (18, 'Konsole i gry',          1),
    (19, 'Konsole',                18),
    (20, 'Gry',                    18);

-- ----------------------------------------------------------------------------
--  Producenci
-- ----------------------------------------------------------------------------
INSERT INTO producenci (id, nazwa, kraj) VALUES
    (1,  'Apple',     'USA'),
    (2,  'Samsung',   'Korea Południowa'),
    (3,  'Dell',      'USA'),
    (4,  'Lenovo',    'Chiny'),
    (5,  'Sony',      'Japonia'),
    (6,  'LG',        'Korea Południowa'),
    (7,  'Asus',      'Tajwan'),
    (8,  'HP',        'USA'),
    (9,  'Xiaomi',    'Chiny'),
    (10, 'Canon',     'Japonia'),
    (11, 'Nikon',     'Japonia'),
    (12, 'Bose',      'USA'),
    (13, 'JBL',       'USA'),
    (14, 'Microsoft', 'USA'),
    (15, 'Nintendo',  'Japonia');

-- ----------------------------------------------------------------------------
--  Użytkownicy (30 kont). Hasło: 'Haslo123!' (bcrypt, indywidualna sól).
-- ----------------------------------------------------------------------------
INSERT INTO uzytkownicy (id, nazwa_uzytkownika, email, haslo_hash, imie, nazwisko, telefon)
SELECT v.id, v.nazwa, v.email,
       crypt('Haslo123!', gen_salt('bf')),
       v.imie, v.nazwisko, v.tel
FROM (VALUES
    (1,  'akowalski',   'a.kowalski@example.com',  'Anna',      'Kowalska',     '600100101'),
    (2,  'jnowak',      'j.nowak@example.com',     'Jan',       'Nowak',        '600100102'),
    (3,  'pwisniewski', 'p.wisniewski@example.com','Piotr',     'Wiśniewski',   '600100103'),
    (4,  'mwojcik',     'm.wojcik@example.com',    'Maria',     'Wójcik',       '600100104'),
    (5,  'kkaminski',   'k.kaminski@example.com',  'Krzysztof', 'Kamiński',     '600100105'),
    (6,  'alewandowska','a.lewandowska@example.com','Agnieszka','Lewandowska',  '600100106'),
    (7,  'tzielinski',  't.zielinski@example.com', 'Tomasz',    'Zieliński',    '600100107'),
    (8,  'mszymanska',  'm.szymanska@example.com', 'Magdalena', 'Szymańska',    '600100108'),
    (9,  'rwozniak',    'r.wozniak@example.com',   'Robert',    'Woźniak',      '600100109'),
    (10, 'kdabrowski',  'k.dabrowski@example.com', 'Karol',     'Dąbrowski',    '600100110'),
    (11, 'akozlowska',  'a.kozlowska@example.com', 'Aleksandra','Kozłowska',    '600100111'),
    (12, 'mjankowski',  'm.jankowski@example.com', 'Marek',     'Jankowski',    '600100112'),
    (13, 'pmazur',      'p.mazur@example.com',     'Paweł',     'Mazur',        '600100113'),
    (14, 'ekrawczyk',   'e.krawczyk@example.com',  'Ewa',       'Krawczyk',     '600100114'),
    (15, 'gpiotrowski', 'g.piotrowski@example.com','Grzegorz',  'Piotrowski',   '600100115'),
    (16, 'jgrabowska',  'j.grabowska@example.com', 'Joanna',    'Grabowska',    '600100116'),
    (17, 'mnowicki',    'm.nowicki@example.com',   'Michał',    'Nowicki',      '600100117'),
    (18, 'kpawlowska',  'k.pawlowska@example.com', 'Katarzyna', 'Pawłowska',    '600100118'),
    (19, 'lmichalski',  'l.michalski@example.com', 'Łukasz',    'Michalski',    '600100119'),
    (20, 'awrobel',     'a.wrobel@example.com',    'Adam',      'Wróbel',       '600100120'),
    (21, 'nzajac',      'n.zajac@example.com',     'Natalia',   'Zając',        '600100121'),
    (22, 'bkrol',       'b.krol@example.com',      'Bartosz',   'Król',         '600100122'),
    (23, 'wwieczorek',  'w.wieczorek@example.com', 'Weronika',  'Wieczorek',    '600100123'),
    (24, 'sjablonski',  's.jablonski@example.com', 'Sebastian', 'Jabłoński',    '600100124'),
    (25, 'mnowakowska', 'm.nowakowska@example.com','Monika',    'Nowakowska',   '600100125'),
    (26, 'dwojciechow', 'd.wojciechowski@example.com','Damian', 'Wojciechowski','600100126'),
    (27, 'iszczepanska','i.szczepanska@example.com','Iwona',    'Szczepańska',  '600100127'),
    (28, 'kgorski',     'k.gorski@example.com',    'Kamil',     'Górski',       '600100128'),
    (29, 'oadamczyk',   'o.adamczyk@example.com',  'Oliwia',    'Adamczyk',     '600100129'),
    (30, 'pdudek',      'p.dudek@example.com',     'Przemysław','Dudek',        '600100130')
) AS v(id, nazwa, email, imie, nazwisko, tel);

-- ----------------------------------------------------------------------------
--  Adresy (wybrane konta)
-- ----------------------------------------------------------------------------
INSERT INTO adresy (uzytkownik_id, ulica, miasto, kod_pocztowy, kraj, typ) VALUES
    (1,  'ul. Floriańska 12',   'Kraków',    '31-019', 'Polska', 'dostawy'),
    (1,  'ul. Floriańska 12',   'Kraków',    '31-019', 'Polska', 'rozliczeniowy'),
    (2,  'ul. Długa 5',         'Warszawa',  '00-238', 'Polska', 'dostawy'),
    (3,  'ul. Piotrkowska 100', 'Łódź',      '90-001', 'Polska', 'dostawy'),
    (5,  'ul. Świdnicka 8',     'Wrocław',   '50-067', 'Polska', 'rozliczeniowy'),
    (8,  'ul. Półwiejska 20',   'Poznań',    '61-888', 'Polska', 'dostawy'),
    (15, 'ul. Bałtycka 3',      'Gdańsk',    '80-001', 'Polska', 'dostawy');

-- ----------------------------------------------------------------------------
--  Produkty
-- ----------------------------------------------------------------------------
INSERT INTO produkty (id, nazwa, opis, kategoria_id, producent_id, stan) VALUES
    (1,  'MacBook Pro 14" M3',        'Laptop Apple, 18 GB RAM, 512 GB SSD',     3,  1,  'nowy'),
    (2,  'Dell XPS 13',               'Ultrabook 13", i7, 16 GB RAM',            3,  3,  'uzywany'),
    (3,  'Lenovo ThinkPad X1 Carbon', 'Biznesowy ultrabook, i7, 16 GB',          3,  4,  'odnowiony'),
    (4,  'Asus ROG Zephyrus G14',     'Laptop gamingowy, Ryzen 9, RTX 4060',     3,  7,  'nowy'),
    (5,  'HP Spectre x360',           'Konwertowalny laptop 2w1',                3,  8,  'uzywany'),
    (6,  'iPhone 15 Pro',             'Smartfon Apple 256 GB, tytan',            7,  1,  'nowy'),
    (7,  'Samsung Galaxy S24',        'Smartfon 256 GB, Snapdragon 8 Gen 3',     7,  2,  'nowy'),
    (8,  'Xiaomi 14',                 'Smartfon 512 GB, aparat Leica',           7,  9,  'uzywany'),
    (9,  'iPhone 13',                 'Smartfon Apple 128 GB',                   7,  1,  'uzywany'),
    (10, 'Apple Watch Series 9',      'Smartwatch GPS 45 mm',                    8,  1,  'nowy'),
    (11, 'Samsung Galaxy Watch 6',    'Smartwatch 44 mm LTE',                    8,  2,  'nowy'),
    (12, 'Sony WH-1000XM5',           'Słuchawki bezprzewodowe ANC',             10, 5,  'nowy'),
    (13, 'Bose QuietComfort Ultra',   'Słuchawki nauszne ANC',                   10, 12, 'uzywany'),
    (14, 'JBL Charge 5',              'Głośnik przenośny Bluetooth',             11, 13, 'nowy'),
    (15, 'Sony Bravia 65" OLED',      'Telewizor 4K OLED 65 cali',               13, 5,  'nowy'),
    (16, 'LG OLED C3 55"',            'Telewizor 4K OLED 55 cali',               13, 6,  'nowy'),
    (17, 'Dell UltraSharp U2723QE',   'Monitor 27" 4K IPS USB-C',                14, 3,  'uzywany'),
    (18, 'Asus ProArt PA32UCG',       'Monitor 32" 4K HDR do grafiki',           14, 7,  'nowy'),
    (19, 'Canon EOS R6',              'Bezlusterkowiec pełnoklatkowy',           16, 10, 'uzywany'),
    (20, 'Nikon Z6 II',               'Bezlusterkowiec pełnoklatkowy',           16, 11, 'odnowiony'),
    (21, 'Canon RF 50mm f/1.8 STM',   'Obiektyw stałoogniskowy',                 17, 10, 'nowy'),
    (22, 'PlayStation 5',             'Konsola Sony, wersja z napędem',          19, 5,  'nowy'),
    (23, 'Xbox Series X',             'Konsola Microsoft 1 TB',                  19, 14, 'nowy'),
    (24, 'Nintendo Switch OLED',      'Konsola przenośna, ekran OLED',           19, 15, 'uzywany'),
    (25, 'Asus GeForce RTX 4080',     'Karta graficzna 16 GB GDDR6X',            5,  7,  'nowy');

-- ----------------------------------------------------------------------------
--  Aukcje — wszystkie startują jako 'aktywna' z datą zakończenia w przyszłości.
--  cena_aktualna inicjowana ceną wywoławczą (trigger podniesie ją po ofertach).
-- ----------------------------------------------------------------------------
INSERT INTO aukcje (id, produkt_id, sprzedajacy_id, cena_wywolawcza, cena_minimalna,
                    cena_aktualna, krok_przebicia, data_rozpoczecia, data_zakonczenia, status) VALUES
    (1,  1,  2,  6000, 7000, 6000, 200, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (2,  6,  3,  4000, NULL, 4000, 100, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (3,  12, 4,   800, NULL,  800,  50, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (4,  22, 5,  1500, 1800, 1500,  50, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (5,  15, 1,  4000, NULL, 4000, 200, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (6,  19, 6,  6000, NULL, 6000, 200, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (7,  2,  7,  2500, 4000, 2500, 100, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (8,  24, 8,   800, NULL,  800,  20, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (9,  7,  9,  3000, NULL, 3000, 100, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (10, 16, 10, 3500, NULL, 3500, 100, now() - interval '20 days', now() + interval '5 days', 'aktywna'),
    (11, 9,  11, 1800, NULL, 1800,  50, now() - interval '5 days',  now() + interval '7 days', 'aktywna'),
    (12, 3,  12, 2200, NULL, 2200, 100, now() - interval '5 days',  now() + interval '6 days', 'aktywna'),
    (13, 23, 1,  1800, NULL, 1800,  50, now() - interval '4 days',  now() + interval '8 days', 'aktywna'),
    (14, 10, 2,  1200, 1500, 1200,  50, now() - interval '3 days',  now() + interval '9 days', 'aktywna'),
    (15, 18, 3,  2500, NULL, 2500, 100, now() - interval '2 days',  now() + interval '10 days','aktywna'),
    (16, 25, 4,  4500, NULL, 4500, 100, now() - interval '1 days',  now() + interval '12 days','aktywna');

-- ----------------------------------------------------------------------------
--  Oferty — pojedyncze instrukcje INSERT (każda osobno, aby wyzwalacz
--  aktualizacji ceny zadziałał przed walidacją kolejnej oferty).
--  Kwoty rosną o co najmniej krok przebicia danej aukcji.
-- ----------------------------------------------------------------------------
-- Aukcja 1 (krok 200, rezerwa 7000) — rezerwa osiągnięta, zwycięzca u15
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (1, 13, 6000);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (1, 14, 6500);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (1, 13, 7000);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (1, 15, 7400);
-- Aukcja 2 (krok 100) — zwycięzca u17
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (2, 14, 4000);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (2, 16, 4300);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (2, 17, 4600);
-- Aukcja 3 (krok 50) — zwycięzca u18
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (3, 18, 800);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (3, 19, 900);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (3, 18, 1000);
-- Aukcja 4 (krok 50, rezerwa 1800) — zwycięzca u22
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (4, 20, 1500);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (4, 21, 1700);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (4, 22, 1900);
-- Aukcja 5 (krok 200) — zwycięzca u24
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (5, 15, 4000);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (5, 23, 4500);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (5, 24, 5000);
-- Aukcja 6 (krok 200) — zwycięzca u25 (transakcja celowo bez recenzji)
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (6, 16, 6000);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (6, 25, 6600);
-- Aukcja 7 (krok 100, rezerwa 4000) — rezerwa NIEosiągnięta (max 3000)
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (7, 26, 2500);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (7, 27, 2800);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (7, 26, 3000);
-- Aukcja 8 — brak ofert (zostanie zamknięta bez rozstrzygnięcia)
-- Aukcja 9 (krok 100) — wygaśnie nierozliczona, max u28
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (9, 28, 3000);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (9, 29, 3300);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (9, 28, 3500);
-- Aukcja 10 (krok 100) — wygaśnie nierozliczona, max u13
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (10, 30, 3500);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (10, 13, 3800);
-- Aukcja 11 (krok 50) — AKTYWNA (wykorzystywana w demo izolacji)
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (11, 14, 1800);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (11, 15, 1900);
-- Aukcja 12 (krok 100) — AKTYWNA
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (12, 16, 2200);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (12, 17, 2400);
-- Aukcja 13 (krok 50) — AKTYWNA, jedna oferta
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (13, 18, 1800);
-- Aukcja 14 (krok 50, rezerwa 1500) — AKTYWNA, rezerwa jeszcze nieosiągnięta
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (14, 19, 1200);
INSERT INTO oferty (aukcja_id, kupujacy_id, kwota) VALUES (14, 20, 1300);
-- Aukcje 15, 16 — AKTYWNE bez ofert

-- ----------------------------------------------------------------------------
--  Rozliczenie aukcji zakończonych (procedura tworzy rekordy w transakcje).
--  A1–A6: ze zwycięzcą; A7: rezerwa nieosiągnięta; A8: brak ofert.
-- ----------------------------------------------------------------------------
CALL zakoncz_aukcje(1);
CALL zakoncz_aukcje(2);
CALL zakoncz_aukcje(3);
CALL zakoncz_aukcje(4);
CALL zakoncz_aukcje(5);
CALL zakoncz_aukcje(6);
CALL zakoncz_aukcje(7);   -- bez rozstrzygnięcia (rezerwa)
CALL zakoncz_aukcje(8);   -- bez rozstrzygnięcia (brak ofert)

-- Ustawienie różnych metod płatności dla realizmu (domyślnie była metoda 1).
UPDATE transakcje SET metoda_platnosci_id = 2, status_platnosci = 'oplacona' WHERE aukcja_id = 1;
UPDATE transakcje SET metoda_platnosci_id = 4, status_platnosci = 'oplacona' WHERE aukcja_id = 2;
UPDATE transakcje SET metoda_platnosci_id = 3, status_platnosci = 'oplacona' WHERE aukcja_id = 3;
UPDATE transakcje SET metoda_platnosci_id = 2, status_platnosci = 'oczekujaca' WHERE aukcja_id = 4;
UPDATE transakcje SET metoda_platnosci_id = 1, status_platnosci = 'oplacona' WHERE aukcja_id = 5;

-- ----------------------------------------------------------------------------
--  Cofnięcie dat zakończenia w przeszłość:
--    * A1–A8 — aukcje zakończone (rozliczone lub bez rozstrzygnięcia),
--    * A9, A10 — aukcje WYGASŁE, lecz wciąż 'aktywna' (do demonstracji
--      procedury zakoncz_wygasle_aukcje).
-- ----------------------------------------------------------------------------
UPDATE aukcje SET data_zakonczenia = now() - interval '2 days'  WHERE id BETWEEN 1 AND 8;
UPDATE aukcje SET data_zakonczenia = now() - interval '1 days'  WHERE id IN (9, 10);

-- ----------------------------------------------------------------------------
--  Recenzje (tylko dla rozliczonych transakcji A1–A5; A6 celowo bez recenzji).
--  transakcja_id pobierane przez aukcja_id (relacja 1:1). Wyzwalacz sprawdza,
--  że autor i oceniany to strony tej transakcji.
-- ----------------------------------------------------------------------------
-- Kupujący ocenia sprzedającego
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
SELECT t.id, t.kupujacy_id, t.sprzedajacy_id, 5, 'Sprawna transakcja, szybka wysyłka. Polecam!'
FROM transakcje t WHERE t.aukcja_id = 1;
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
SELECT t.id, t.kupujacy_id, t.sprzedajacy_id, 4, 'Produkt zgodny z opisem, drobne opóźnienie.'
FROM transakcje t WHERE t.aukcja_id = 2;
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
SELECT t.id, t.kupujacy_id, t.sprzedajacy_id, 5, 'Wszystko super, kontakt bez zarzutu.'
FROM transakcje t WHERE t.aukcja_id = 3;
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
SELECT t.id, t.kupujacy_id, t.sprzedajacy_id, 3, 'Sprzęt ok, opakowanie mogłoby być lepsze.'
FROM transakcje t WHERE t.aukcja_id = 4;
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
SELECT t.id, t.kupujacy_id, t.sprzedajacy_id, 5, 'Polecam sprzedającego, duży profesjonalizm.'
FROM transakcje t WHERE t.aukcja_id = 5;
-- Sprzedający ocenia kupującego
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
SELECT t.id, t.sprzedajacy_id, t.kupujacy_id, 5, 'Błyskawiczna płatność, polecam kupującego.'
FROM transakcje t WHERE t.aukcja_id = 1;
INSERT INTO recenzje (transakcja_id, autor_id, oceniany_id, ocena, komentarz)
SELECT t.id, t.sprzedajacy_id, t.kupujacy_id, 5, 'Wszystko sprawnie, dziękuję.'
FROM transakcje t WHERE t.aukcja_id = 3;

-- ----------------------------------------------------------------------------
--  Obserwowane aukcje (lista obserwowanych — relacja M:N)
-- ----------------------------------------------------------------------------
INSERT INTO obserwowane (uzytkownik_id, aukcja_id) VALUES
    (13, 11), (14, 11), (16, 11),
    (15, 12), (18, 12),
    (19, 13), (20, 13), (21, 13),
    (22, 14),
    (23, 15), (24, 16),
    (1, 11), (2, 12), (3, 13);

-- ----------------------------------------------------------------------------
--  Synchronizacja sekwencji IDENTITY po wstawieniu rekordów z jawnym id,
--  aby kolejne automatyczne wstawienia nie kolidowały z istniejącymi kluczami.
-- ----------------------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('metody_platnosci','id'), (SELECT max(id) FROM metody_platnosci));
SELECT setval(pg_get_serial_sequence('kategorie','id'),        (SELECT max(id) FROM kategorie));
SELECT setval(pg_get_serial_sequence('producenci','id'),       (SELECT max(id) FROM producenci));
SELECT setval(pg_get_serial_sequence('uzytkownicy','id'),      (SELECT max(id) FROM uzytkownicy));
SELECT setval(pg_get_serial_sequence('produkty','id'),         (SELECT max(id) FROM produkty));
SELECT setval(pg_get_serial_sequence('aukcje','id'),           (SELECT max(id) FROM aukcje));
