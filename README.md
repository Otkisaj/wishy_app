# 🎁 Wishy — Moja Lista Życzeń

Aplikacja do zarządzania listą marzeń z synchronizacją w Firebase.

## 🛠 Technologia i Wymagania

### Obowiązkowe:
*   **Nawigacja**: GoRouter (trasy `/`, `/add`, `/edit`).
*   **Stan**: Riverpod (`StreamProvider`, `FutureProvider`, `.when`).
*   **API**: DIO (pobieranie kursów walut z NBP API).
*   **Firebase**: 
    *   Auth (Logowanie anonimowe).
    *   Firestore (Pełny CRUD: zapis, odczyt, edycja, usuwanie).

### Dodatkowe (wybrane 4):
1.  **Formularz**: TextField z obsługą danych.
2.  **DatePicker**: Wybór daty z kalendarza systemowego.
3.  **Dark/Light Mode**: Obsługa motywów przez FlexColorScheme.
4.  **GoogleFonts**: Czcionka "Plus Jakarta Sans".

## ✨ Funkcje
*   Logowanie anonimowe.
*   Kurs USD/PLN na żywo (NBP API).
*   Zarządzanie marzeniami (Dodaj / Edytuj / Usuń).
*   Synchronizacja z chmurą Firestore.
*   Przełącznik trybu ciemnego/jasnego.
