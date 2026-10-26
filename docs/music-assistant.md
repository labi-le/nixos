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

## Фоновый анализ громкости

MA считает loudness/EBU R128 для локальных файлов ночным фоновым сканом, чтобы играть ReplayGain без клиппинга. Расписание лежит в `/var/lib/music-assistant/settings.json` (`core.tasks.scheduled_task_states.audio_analysis_background_scan`) в UTC, а дефолт сервер берёт от локальной полуночи — то есть 21:00 UTC, и скан молотил CPU с 00:00.

Окно задаётся в `modules/music-assistant.nix`: `ExecStartPre` контейнера прогоняет `jq` по `settings.json` и ставит расписание на 01:00 UTC = 04:00 MSK. Правка применяется на каждом старте контейнера, поэтому смена окна через UI не переживёт рестарта — менять только в модуле. Прогон ограничен четырьмя часами (`BACKGROUND_SCAN_RUN_BUDGET_SECONDS` в образе), значит ночь занимает 04:00–08:00 максимум и обычно заканчивается раньше: в окно попадает только накопленное с прошлой ночи.

## Поведение

- Задержка около секунды на play/pause: это буфер Snapcast.
- Пауза реализована как STOP+RESUME — состояние в UI может не показывать `paused`.
- Эквалайзер станции не участвует: звук идёт через AudioFlinger (OpenSL).
- Громкость — см. раздел ниже.
- Пока играет Snapcast, Алиса молчит; после остановки возвращается.

## Громкость

Слайдер MA — это `Client.SetVolume` Snapcast, то есть софт-громкость клиента.
Усилитель станции при этом закреплён на максимуме: его шкала в дБ (0…672, шаг
дробный), и без закрепления проценты MA перемножались с аппаратным затуханием —
30 % звучали как тишина.

| Слой | Шкала | Кто пишет |
|---|---|---|
| софт-громкость клиента | 0…100 % | MA, крутилка через мост |
| усилитель, card1 | `Tweeters/Subwoofer Master Playback Volume`, 0…672 | `ampmax.sh` держит 672/662, откатывая записи quasar |

Крутилка: quasar (`volume_setd`) пишет `hw_master_volume` 0…85. `knob.sh` слушает
`logcat -s volume_setd`, переводит `n` в `n*100/85` и шлёт `Client.SetVolume` на
`192.168.1.2:1705`; MA обновляет слайдер сам, без запроса.

Скрипты живут на станции, в репозитории их нет:

| Файл | Роль |
|---|---|
| `/data/local/etc/netlock.sh` | iptables-блок Яндекса, LAN остаётся |
| `/data/local/etc/ampmax.sh` | раз в секунду возвращает усилитель на 672/662 |
| `/data/local/etc/knob.sh` | крутилка → `Client.SetVolume` |
| `/data/local/etc/station-watch.sh` | раз в 30 с перезапускает всё выше по pidfile и поднимает snapclient |

Запуск — строка в конце `/system/vendor/quasar/onboot.sh`.

## YAM

`yamd` — менеджер `.yap`-пакетов для станций. Лежит в `/data/quazar/yam/bin/yamd`,
данные в `/data/quazar/yam/data`, веб-панель на `:8099` без пароля (только LAN).
Стартует от root и перезапускается тем же `station-watch.sh`, поэтому переживает ребут.

Модель определяется как `unknown`: профиля Станции 1 в YAM нет, поэтому пакеты с
привязкой к модели откажутся ставиться. Доступные фичи: Lua-runtime, `.yap`-плагины,
`input.evdev`, `led.sysfs`, датчик температуры, батарея.

CLI на pc — пакет `pkgs/yam.nix` через overlay, `yam` в PATH. Адрес колонки CLI
находит сам по adb. Команды: `yam registry list` (75 пакетов), `yam install <id>`,
`yam logs <id>`.
