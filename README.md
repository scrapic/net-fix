# net-fix

Набор скриптов для обхода поломок сети у провайдера: подмена DNS на DNS-over-HTTPS,
правка `hosts` для Roblox/Meta и обход DPI через [zapret](https://github.com/bol-van/zapret).
Всё под Windows, прав администратора достаточно для запуска `.bat`/`.ps1`.

## Zapret-OneClick — готовый комплект (рекомендуется)

Просто скачай папку и запусти нужный файл:

| Файл | Что делает |
|---|---|
| `ON.bat` | Включает всё: DoH (Cloudflare 1.1.1.1), записи в `hosts`, службу `zapret` |
| `OFF.bat` | Останавливает и удаляет службу `zapret`, чистит `hosts` (DoH остаётся, чтобы интернет не отвалился) |

- При запуске попросит UAC — это нормально, скрипт ставит службу и правит `hosts`.
- Проверка после включения: YouTube, Discord, Facebook, Instagram, Roblox.
- Полный возврат DNS провайдера: `powershell -ExecutionPolicy Bypass -File off.ps1 -ResetDns`
- Пресет zapret по умолчанию: `general (SIMPLE FAKE).bat`. Остальные пресеты лежат в `zapret\*.bat` —
  если конкретный сайт не открывается, попробуй другой (`ALT`, `FAKE TLS AUTO` и т.д.).
- Свои домены можно добавить в `zapret\lists\list-general-user.txt`.

Что внутри `zapret\`: `winws.exe`, `WinDivert`, `cygwin1.dll`, списки и пресеты — это сборка
стороннего проекта **zapret** (автор bol-van), она нужна как есть.

## Отдельные скрипты

| Скрипт | Назначение |
|---|---|
| `doh-on.ps1` / `doh-off.ps1` | Включить / откатить системный DNS-over-HTTPS (Cloudflare) на всех физических адаптерах |
| `roblox-hosts.ps1` | Чинит битые иконки/миниатюры Roblox: пинит `tr.rbxcdn.com` на живой Akamai-edge |
| `check-tg-proxies.ps1` | Проверяет список MTProto-прокси Telegram из `%TEMP%\tg_proxies.txt` |
| `test-presets.ps1` | Замеряет скорость googlevideo с выключенной службой и с каждым пресетом zapret |

`test-presets.ps1` содержит путь к локальной папке zapret — поправь `$root` под себя.

## Дисклеймер

Скрипты меняют системные настройки (`hosts`, DNS, службы). Перед запуском понимай, что делаешь:
после `OFF.bat` без `-ResetDns` DNS остаётся на Cloudflare. Используй на свой риск.
