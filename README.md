# net-fix

Набор скриптов для обхода поломок сети у провайдера: подмена DNS на DNS-over-HTTPS,
правка `hosts` для Roblox/Meta и обход DPI через [zapret](https://github.com/bol-van/zapret).
Всё под Windows, прав администратора достаточно для запуска `.bat`/`.ps1`.

## Zapret-OneClick — готовый комплект (рекомендуется)

📦 **Скачать одним архивом: [Releases → Zapret-OneClick v1.0](https://github.com/scrapic/net-fix/releases/latest)** — там уже всё собрано, распаковать и запустить `ON.bat`.

Сделано для **Сахалина, провайдер «Солнце Телеком»** — под его конкретные блокировки (DPI + подмена DNS).
У других провайдеров блокировки другие, может понадобиться сменить пресет.

Или клонируй репозиторий и запускай прямо из папки:

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

## Источники и благодарности

- **Основа — сборка zapret от [Flowseal](https://github.com/Flowseal/zapret-discord-youtube)**:
  `zapret-discord-youtube` 1.10.1. Пресеты `general*.bat`, списки в `lists\`, `bin\`
  (`winws.exe`, `WinDivert`, `cygwin1.dll`, пейлоады) взяты оттуда **без изменений**.
- Сам zapret написан **[bol-van](https://github.com/bol-van/zapret)** (лицензия MIT).
- Моего здесь только обвязка «в один клик»: `ON.bat`, `OFF.bat`, `install.ps1`, `off.ps1`
  и документация. Чужой код я себе не присваиваю.
- Настроено и проверено под **Сахалин, провайдер «Солнце Телеком»**. У других провайдеров
  блокировки другие — возможно, придётся подобрать другой пресет.

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
