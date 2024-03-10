#!/run/current-system/sw/bin/bash
target_folder="/var/lib/wordpress/localhost/uploads"
actual_path=$(readlink -s "$target_folder")
expected_path="wp-content/uploads"
if [ "$actual_path" != "$expected_path" ]; then
	rm -rf "$target_folder"
	cd /var/lib/wordpress/localhost/ || exit
	ln -s "$expected_path" "$target_folder" || true
	chown wordpress:wwwrun "$target_folder"
fi
