{ pkgs ? import <nixpkgs> { } }:

pkgs.writeShellScriptBin "ea-disable-overlay" ''
  #!/bin/sh
  set -e

  path="$1"
  if [ -z "$path" ]; then
    echo "Использование: $0 <путь/к/директории/игры>"
    exit 1
  fi

  echo "Ищем appmanifest для игры..."
  game_dir=$(basename "$path")
  appmanifest=$(find "''${path%/steamapps*}/steamapps" -name "appmanifest_*.acf" | xargs grep -l "installdir.*\"$game_dir\"" | head -n 1)
  if [ -z "$appmanifest" ]; then
    echo "Ошибка: Не удалось найти appmanifest для игры '$game_dir'."
    echo "Проверенный путь: ''${path%/steamapps*}/steamapps"
    exit 1
  fi
  echo "Найден appmanifest: $appmanifest"

  gameID=$(basename "$appmanifest" | grep -oP "appmanifest_\K\d+")
  echo "ID игры: $gameID"

  echo "Ищем директорию compatdata..."
  compatdata_dir="''${path%/steamapps*}/steamapps/compatdata/$gameID"
  if [ ! -d "$compatdata_dir" ]; then
    echo "Ошибка: Директория compatdata не найдена."
    echo "Проверенный путь: $compatdata_dir"
    echo "Содержимое директории steamapps/compatdata:"
    ls -la "''${path%/steamapps*}/steamapps/compatdata"
    exit 1
  fi
  echo "Найдена директория compatdata: $compatdata_dir"

  echo "Ищем файл конфигурации EA Desktop..."
  config_dir="$compatdata_dir/pfx/drive_c/users/steamuser/AppData/Local/Electronic Arts/EA Desktop"
  file=$(find "$config_dir" -name "user_*.ini" 2>/dev/null | head -n 1)
  
  if [ -z "$file" ]; then
    echo "Файл конфигурации EA Desktop не найден."
    echo "Проверенный путь: $config_dir"
    echo "Содержимое директории EA Desktop (если существует):"
    ls -la "$config_dir" 2>/dev/null || echo "Директория не существует или недоступна"
    exit 1
  fi

  echo "Найден файл конфигурации: $file"

  if grep -q "user.igoenabled=0" "$file"; then
    echo "Оверлей EA уже отключен."
  else
    echo "user.igoenabled=0" >> "$file"
    echo "Оверлей EA был отключен."
  fi
''
