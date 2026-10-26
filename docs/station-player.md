# Плейлист tidal-syncer на Станции 1

Станция играет `Favorite Tracks.m3u8`, который `tidal-syncer` пересобирает на
`192.168.1.2`. Файлы не копируются: станция тянет FLAC по HTTP с того же сервера.

## Состав

| Что | Где |
|---|---|
| библиотека | `/drive/sync/music` на `server`, отдаётся nginx по `http://192.168.1.2/music/` только для `192.168.1.0/24` |
| плеер | `/data/local/bin/stplay` на станции |
| веб-морда | `busybox httpd` на `:8088`, страница и CGI в `/data/local/stplay/www` |
| обложки | `/var/lib/music-covers` на `server`, отдаются по `http://192.168.1.2/covers/` (модуль `modules/music-covers.nix`) |

Открывается как `http://<ip-станции>:8088/`.

## Как играет

`stplay super` — фоновой супервизор: берёт URL из `/data/local/stplay/urls`,
запускает `maind --gst-launch "souphttpsrc location=… ! decodebin ! audioconvert !
audioresample ! openslessink"`, ждёт EOS и переходит к следующему треку. Индекс,
режим и PID лежат файлами в `/data/local/stplay`, поэтому управление работает из
любого процесса.

`alsasink` в прошивке станции нет: GStreamer собран с `openslessink` и `a2dpsink`,
рецепт из вики (`alsasink`) относится к Buildroot-моделям.

## Веб-морда

| CGI | Что отдаёт |
|---|---|
| `cmd=now` | `режим`, `индекс`, `всего`, `позиция`, `длительность`, `артист`, `альбом`, `название` через табуляцию; позиция вырезается из последней строки `Progress:` в логе `maind` |
| `cmd=list` | `индекс`, `артист`, `альбом`, `название` |
| `cmd=covers` | проксирует `index.tsv` с сервера: `Артист/Альбом<TAB>hash` |
| `cmd=lyrics&idx=N` | текст трека: `.lrc` рядом с FLAC, пусто если файла нет |
| `cmd=play&idx=N`, `cmd=next`, `prev`, `toggle`, `stop`, `refresh` | управление |

Страница опрашивает `now` раз в секунду: прогресс, состояние кнопок и подсветка
играющего трека. Артист и альбом берутся из пути в m3u8, обложка — из
`/covers/<hash>.jpg`, набор обложек подтягивается при загрузке страницы.

Экран проигрывания — полноэкранная панель: обложка, синхронный текст (строка
подсвечивается по таймкодам `.lrc`, заливка внутри строки считается по интервалу
до следующей), полоса прогресса и управление. Фон — размытое свечение из среднего
цвета обложки; для выборки пикселей nginx отдаёт `/covers/` с
`Access-Control-Allow-Origin`, иначе canvas не может читать чужой домен.

## Установка

```sh
adb shell 'mkdir -p /data/local/bin /data/local/stplay/www/cgi-bin'
adb push scripts/station-player/stplay /data/local/bin/stplay
adb push scripts/station-player/www/index.html /data/local/stplay/www/index.html
adb push scripts/station-player/www/cgi-bin/ctl /data/local/stplay/www/cgi-bin/ctl
adb shell 'chmod 755 /data/local/bin/stplay /data/local/stplay/www/cgi-bin/ctl'
adb shell '/data/local/bin/stplay refresh; /data/local/bin/stplay httpd'
```

`/data/local` принадлежит root, поэтому каталоги создаются из root-шелла
(`telnet <ip> 2323`, появился после установки `boot-root.img`) и отдаются
пользователю `shell`, под которым живёт httpd и CGI.

Автозапуск — строка в конце `/system/vendor/quasar/onboot.sh`:

```sh
[ -x /data/local/bin/stplay ] && /data/local/bin/stplay httpd
```

## Ограничения

- Перемотки нет: `next`/`prev`/`pause`/`stop` только.
- Между треками пауза около двух секунд: супервизор стартует новый `maind`.
- Очередь одна; другой плейлист — это `PLAYLIST` в начале `stplay` плюс `refresh`.
- Громкость общая со Алисой: плеер пишет в тот же миксер.
