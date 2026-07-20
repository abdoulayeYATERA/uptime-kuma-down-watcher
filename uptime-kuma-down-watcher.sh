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
script_version="1.1.0"
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

#see note 1
gotify_send_message() {
  local title="$1"
  local message=$(printf '%s' "$2" | sed ':a;N;$!ba;s/\n/\\n/g')
  local priority="$3"

  echo "Gotify send message
    url : $gotify_url
    app_token : $gotify_app_token
    title: $title
    message: $message
    priority: $priority"


  gotify_response=$(curl -X 'POST' \
    "$gotify_url/message" \
    -H 'accept: application/json' \
    -H "X-Gotify-Key: $gotify_app_token" \
    -H 'Content-Type: application/json' \
    -d "{
          \"title\": \"$1                                           \",
          \"message\": \"$message\",
          \"priority\": $3
        }")
  echo "Gotify send message RESPONSE:"
  echo "$gotify_response"

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


if [ "$1" = "test-notifications" ]; then 
  test_notification_title="Test notification $hostname $script_name $script_version"
  test_notification_message="Test(uptime-kuma) : Test notification uptime-kuma down watcher !"
	if [ -n "$mail" ]; then 
	  #send mail
    echo "Send test notification mail to $mail"
    printf "%s" "$test_notification_message" | \
      mail -s "$test_notification_title" "$mail" 
  fi


  if gotify_is_setup; then
    echo "Send test notification to Gotify "
    gotify_response=$(gotify_send_message "$test_notification_title" "$test_notification_message" "$gotify_priority" 2>&1)
    echo "$gotify_response"
  fi
  exit 0
fi

metrics=$(curl -u":$uptime_kuma_api_key" "$uptime_kuma_url/metrics" 2> /dev/null)

### cert warning 

cert_warning_monitor_list=$(printf "%s" "$metrics" | grep -E "^monitor_cert_days_remaining.*$" | awk '($NF < 28){ print $0; }'| grep -Eo 'monitor_name="[^"]*' | sed 's/monitor_name="//') 
cert_warning_monitor_count=$(wc -l <<< "$cert_warning_monitor_list")

if [ "$cert_warning_monitor_count" = "0" ]; then
  #no down monitor, exit the script
  echo "No cert warning monitor !"
else
  echo "$cert_warning_monitor_count cert warning monitor(s) !"
  uptime_kuma_cert_warning_monitors_notification_title="ERROR(uptime-kuma): $cert_warning_monitor_count  cert warning monitor(s)"
  uptime_kuma_cert_warning_notification_message="$cert_warning_monitor_list"
  if [ -n "$mail" ]; then 
    #send mail
    echo "Send cert warning email to $mail"
    printf "%s" "$uptime_kuma_cert_warning_notification_message" | mail -s "$uptime_kuma_cert_warning_monitors_notification_title" "$mail" 
  fi
  
  if gotify_is_setup; then
    #send gotify notification
    echo "Send cert warning gotify notification"
    gotify_send_message \
      "$uptime_kuma_cert_warning_monitors_notification_title" \
      "$uptime_kuma_cert_warning_notification_message" \
      "$gotify_priority" 2>&1
  fi
fi

### down monitors
down_monitor_list=$(printf "%s" "$metrics" | grep -E "^monitor_status.*0$" | grep -Eo 'monitor_name="[^"]*' | sed 's/monitor_name="//') 
down_monitor_count=$(wc -l <<< "$down_monitor_list")

if [ "$down_monitor_count" = "0" ]; then
  #no down monitor, exit the script
  echo "No down monitor !"
else
  echo "$down_monitor_count down monitor(s) !"
  uptime_kuma_down_monitors_notification_title="ERROR(uptime-kuma): $down_monitor_count down monitor(s)"
  uptime_kuma_down_monitors_notification_message="$down_monitor_list"
  if [ -n "$mail" ]; then 
    #send mail
    echo "Send down monitors gotify notification"
    printf "%s" "$uptime_kuma_down_monitors_notification_message" | mail -s "$uptime_kuma_down_monitors_notification_title" "$mail" 
  fi
  
  if gotify_is_setup; then
    #send gotify notification
    echo "Send down monitors gotify notification"
    gotify_send_message \
      "$uptime_kuma_down_monitors_notification_title" \
      "$uptime_kuma_down_monitors_notification_message" \
      "$gotify_priority" 2>&1
  fi
fi

