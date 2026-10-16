#!/run/current-system/sw/bin/bash

# Функция для проверки и создания символической ссылки
check_and_create_symlink() {
	local target_folder="$1"
	local expected_path="$2"

	actual_path=$(readlink -s "$target_folder")

	if [ "$actual_path" != "$expected_path" ]; then
		rm -rf "$target_folder"
		cd "$(dirname "$target_folder")" || exit
		ln -s "$expected_path" "$(basename "$target_folder")" || true
		chown wordpress:wwwrun "$(basename "$target_folder")"
	fi
}

# Массив папок, которые нужно проверить и создать
folders=("uploads" "plugins" "themes" "languages" "upgrade")

# Цикл по всем папкам
for folder in "${folders[@]}"; do
	check_and_create_symlink "/var/lib/wordpress/localhost/$folder" "wp-content/$folder"
done
