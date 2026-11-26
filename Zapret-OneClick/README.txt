==================================================
  ОБХОД БЛОКИРОВОК — ОДНИМ НАЖАТИЕМ
==================================================

ЧТО ВНУТРИ
----------
- ON.bat   — включить всё (DNS-over-HTTPS + hosts + zapret)
- OFF.bat  — выключить (zapret + hosts), DNS остаётся
- zapret\  — сама программа обхода
- install.ps1 / off.ps1 — скрипты (можно редактировать)

КАК ПОЛЬЗОВАТЬСЯ
----------------
1. Распаковать архив в любую папку.
2. Двойной клик по ON.bat -> UAC "Да" -> ждём "DONE".
3. Всё. YouTube, Discord, Facebook, Instagram, Roblox работают.

Чтобы выключить — двойной клик по OFF.bat.

ЧТО ДЕЛАЕТ ON
-------------
- DoH (Cloudflare 1.1.1.1): чинит подмену DNS провайдером
  (без него у многих "умирает" браузер).
- hosts: рабочие IP для Roblox-иконок и Meta (IG/FB/WA).
- zapret-служба: обход DPI для YouTube, Discord и т.д.

ЧТО ДЕЛАЕТ OFF
--------------
- Останавливает/удаляет zapret и записи hosts.
- DoH ОСТАЁТСЯ, поэтому браузер продолжает работать.
- Полный откат DNS к провайдеру:
    powershell -ExecutionPolicy Bypass -File "off.ps1" -ResetDns

ПРИМЕЧАНИЯ
----------
- без zapret YouTube/Facebook/Instagram не открываются
  (это блок DPI на уровне провайдера — не ошибка);
- Telegram блокируется по IP — нужен MTProto-прокси
  (ссылки можно получить на github.com/0xRadikal/Free-Telegram-Proxy);
- нужны права администратора (UAC) и Windows 11.

Всё в открытом виде — можно править: списки доменов в
zapret\lists\list-general-user.txt, пресеты — *.bat в zapret\.
