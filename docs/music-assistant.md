# Music Assistant на Станции 1

Готовый серверный плеер вместо самописной морды: UI на `http://192.168.1.2:8095`,
звук уходит на станцию через Snapcast-клиент на Android.

## Состав

| Что | Где |
|---|---|
| сервер | контейнер `ghcr.io/music-assistant/server` (`modules/music-assistant.nix`), host-network, состояние в `/var/lib/music-assistant` |
| библиотека | `/drive/sync/music` смонтирована в контейнер read-only как `/media`, в MA добавлена как Filesystem-провайдер |
| порты | 8095 UI, 8097 стрим, 1704/1705 Snapcast, 4953-5153 клиенты |
| клиент на станции | `de.badaix.snapcast` (Snapdroid), APK с GitHub releases, host `192.168.1.2`, порты 1704/1705 |

MA сам поднимает встроенный Snapserver; отдельный snapcast-сервер не нужен.

## Первичная настройка

1. Открыть `:8095`, создать админ-аккаунт.
2. Settings → Music sources → **Add a music source** → Filesystem (local disk), путь `/media`. Импорт идёт в фоне.
3. Settings → Player providers → **Add a player provider** → Snapcast.
4. На станции поставить Snapdroid, в его настройках указать хост `192.168.1.2`, включить Auto start Snapclient.

## Почему станция «не видна»

MA считает Snapcast-клиента доступным только пока Snapserver видит свежий `lastSeen`
(порог 15 с, `SNAPCLIENT_STALE_THRESHOLD`). Клиент после падения/перезапуска сам не
поднимается, пока приложение не откроют: у Snapdroid есть ресиверы на
`de.badaix.snapcast.START_SERVICE` и `BOOT_COMPLETED`, поэтому headless-запуск — это

```sh
adb shell am broadcast -a de.badaix.snapcast.START_SERVICE -n de.badaix.snapcast/.BroadcastReceiver
```

Без этого в списке игроков MA остаются только `pc` и веб-плеер, а строка станции
показывается в Settings → Players с `available: false`.

`am startservice -n de.badaix.snapcast/.SnapclientService` клиента не поднимает —
использовать broadcast.

## TIDAL

Settings → Music sources → Add a music source → Tidal. MA показывает код и ссылку
`link.tidal.com`: ввести код на телефоне/в браузере, вкладка настроек обновится сама.
Логин не нужен ни для локальной библиотеки, ни для Snapcast — только для стриминга TIDAL.

## Поведение

- Задержка около секунды на play/pause: это буфер Snapcast.
- Пауза реализована как STOP+RESUME — состояние в UI может не показывать `paused`.
- Громкость и эквалайзер станции не участвуют: звук идёт через AudioFlinger (OpenSL),
  громкость — системная, как у любого Android-приложения.
- Пока играет Snapcast, Алиса молчит; после остановки возвращается.
