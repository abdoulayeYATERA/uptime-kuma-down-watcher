#!/bin/bash
#NOTES
#1
#you'll see that spaces are added to gotify titles
#have to add space because gotify-tray popup is broken when title is small
#https://github.com/seird/gotify-tray

#exit on error
set -e
#exit on unset variable
set -u
#-o pipefail fail if pipe command failed (https://www.howtogeek.com/782514/how-to-use-set-and-pipefail-in-bash-scripts-on-linux/)
set -o pipefail
#extend globbing
shopt -s extglob

my_name=${0##*/}
my_path=$(readlink -f "$0")
top_dir=${my_path%/*}
my_real_name=${my_path##*/}

script_name="Uptime Kuma Down Watcher"
script_version="1.0.0"
installed_path="/opt/uptime-kuma-down-watcher"
installed_script_path="${installed_path}/uptime-kuma-down-watcher.sh"
installed_conf_path="${installed_path}/uptime-kuma-down-watcher.conf"
installed_cron_path="/etc/cron.d/uptime-kuma-down-watcher"
default_config="
uptime_kuma_url=
uptime_kuma_api_key=
mail=
gotify_url=
gotify_app_token=
gotify_priority=
"
default_cron="
DATEVAR=date -u +%Y-%m-%dT%H:%M
#m h dom m dow user script
* * * * *  root \"$installed_script_path\" check-down-monitors > /dev/null
"

hostname=$(hostname -f)

is_installed() {
  if ! [ -f "$installed_script_path" ] || ! [ -f "$installed_conf_path" ] || ! [ -f "$installed_cron_path" ]; then
    return 1
  fi
}

gotify_send_message() {
  #see note 1
  curl -X 'POST' \
  "$gotify_url/message" \
  -H 'accept: application/json' \
  -H "X-Gotify-Key: $gotify_app_token" \
  -H 'Content-Type: application/json' \
  -d "{
        \"message\": \"$2\",
        \"title\": \"$1                                           \",
        \"priority\": $3
      }"
}

gotify_is_setup() {
  [ -n "$gotify_url" ] && [ -n "$gotify_app_token" ] && [ "$gotify_priority" -gt 0 ]
}

print_help() {
  echo "Use with the following arguments

  install   
    install the script on the system

  remove    
    remove the script from the system

  check-down-monitors
    check that there is no uptime kuma down monitor,
    and send notification if it's the case.
    See $installed_conf_path for notifications config 

  test-notifications  
    send test notifications
    See $installed_conf_path for notifications config 
  
  help 
    show the help
  ------------
  For more details : https://github.com/abdoulayeYATERA/uptime-kuma-down-watcher
  "
}

echo "---  $script_name $script_version ---"

if [ $# -eq 0 ]; then
  print_help
  exit 0
fi

if [ "$1" = "install" ]; then
  echo "install $script_name $script_version"
  echo "create folder : $installed_path"
  mkdir -p "$installed_path"
  echo "copy script : $installed_script_path"
  cp "$my_path" "$installed_script_path"
  echo "copy conf : $installed_conf_path"
  printf "%s" "$default_config" > "$installed_conf_path"
  echo "copy cron : $installed_cron_path"
  printf "%s" "$default_cron" > "$installed_cron_path"
  echo "set permissions"
  chmod -R u=rwx,go=rx "$installed_path"
  echo "$script_name $script_version installed !"
  echo "Don't forget to edit $installed_conf_path for notifications config !"
	exit 0
fi 

if [ "$1" = "remove" ]; then
  echo "remove $script_name"
  if [ -f "$installed_cron_path" ]; then
    echo "remove cron : $installed_cron_path"
    rm  "$installed_cron_path" || { echo "Error deleting $installed_cron_path"; exit 1; }
  fi
  
  if [ -f "$installed_path" ]; then
    echo "delete folder : $installed_path"
    rm -r "$installed_path" || { echo "Error deleting $installed_path"; exit 1; }
  fi 
  echo "$script_name removed !"
	exit 0
fi

if [ "$1" = "help" ]; then
  print_help
  exit 0
fi

if [ "$1" != "check-down-monitors" ] && [ "$1" != "test-notifications" ]; then
  print_help
  exit 1
fi

if ! is_installed; then
  echo "$script_name is not intalled !"
  exit 1
fi
#source config
source "$installed_conf_path"
if [ "$uptime_kuma_api_key" = "" ]; then
  echo "ERROR: config error, uptime_kuma_api_key not set";
  exit 1
fi

if [ "$uptime_kuma_url" = "" ]; then
  echo "ERROR: config error, uptime_kuma_url not set"
  exit 1
fi

metrics=$(curl -u":$uptime_kuma_api_key" "$uptime_kuma_url/metrics" 2> /dev/null)
down_monitor_count_tmp=$(grep -E -c "^monitor_status.*0$" <<< "$metrics" || true)

if [ "$down_monitor_count_tmp" -gt 0 ]; then
  down_monitor_count="$down_monitor_count_tmp";
else 
  down_monitor_count="0";
fi

if [ "$1" = "test-notifications" ]; then 
  test_notification_title="Test notification $hostname $script_name $script_version"
	if [ -n "$mail" ]; then 
	  #send mail
    echo "Send test notification mail to $mail"
    printf "%s" "ERROR(uptime-kuma) : $down_monitor_count server(s) down !"  | \
      mail -s "$test_notification_title" "$mail" 
  fi

  if gotify_is_setup; then
    echo "Send test notification to Gotify 
    url : $gotify_url
    app_token : $gotify_app_token"
    gotify_notification_message="ERROR(uptime-kuma) : $down_monitor_count server(s) down !"
    gotify_response=$(gotify_send_message "$test_notification_title" "$gotify_notification_message" "$gotify_priority" 2>&1)
    echo "$gotify_response"
  fi
  exit 0
fi

if [ "$down_monitor_count" = "0" ]; then
  #no down monitor, exit the script
  echo "No down monitor !"
  exit 0
fi
echo "$down_monitor_count down monitor(s) !"
uptime_kuma_down_monitors_notification_title="ERROR(uptime-kuma): $down_monitor_count down monitor(s)"
uptime_kuma_down_monitors_notification_message="ERROR(uptime-kuma): $down_monitor_count down monitor(s)"
if [ -n "$mail" ]; then 
  #send mail
  echo "Send services failed email to $mail"
  printf "%s" "$uptime_kuma_down_monitors_notification_message" | mail -s "$uptime_kuma_down_monitors_notification_title" "$mail" 
fi

if gotify_is_setup; then
  #send gotify notification
  echo "Send services failed gotify notification
  url : $gotify_url
  app_token : $gotify_app_token"
  gotify_response=$(gotify_send_message \
    "$uptime_kuma_down_monitors_notification_title" \
    "$uptime_kuma_down_monitors_notification_message" \
    "$gotify_priority" 2>&1)
  echo "$gotify_response"
fi
