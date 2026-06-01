# Uptime Kuma down watcher

## What it is and what it does
A watcher that check periodically the number of down monitors on atargeted uptime-kuma instance. When down monitors are detected, send notification by email and/or Gotify:

## How to use it

```
---  uptime-kuma down watcher 1.0.0 ---
Use with the following arguments

  install
    install the script on the system

  remove
    remove the script from the system

  check-down-monitors

  test-notifications
    send test notifications
    See /opt/uptime-kuma-down-watcher/uptime-kuma-down-watcher.conf for notifications config

  help
    show the help
  ------------
  For more details : https://github.com/abdoulayeYATERA/uptime-kuma-down-watcher
```

- 1.download

  Clone the project on the system

  ```
  git clone https://github.com/abdoulayeYATERA/uptime-kuma-down-watcher
  ```

- 1.Install

  Use install argument to install the script on the system

  ```
  ./uptime-kuma-down-watcher/uptime-kuma-down-watcher.sh install
  ```

- 2.Configure

  Edit the config file

  ```
    vim /opt/uptime-kuma-down-watcher/uptime-kuma-down-watcher.conf
    #or
    nano /opt/uptime-kuma-down-watcher/uptime-kuma-down-watcher.conf
  ```
  Set the targeted uptime-kuma instance url, and api key
  ```
    uptime_kuma_url=https://uptime-kuma.myserver.com
    uptime_kuma_api_key=DU83-IDXTqudl3
  ```

  To receive mail notifications put your email or alias (see https://www.baeldung.com/linux/etc-aliases-file).<br/>
  System Postfix have to be working for email notifications to work.

  ```
  mail=myemail@mydomain.com
  ```

  To receive Gotify notifications put your Gotify url and app key.

  ```
  gotify_url=https://gotify.mywebsite.com
  gotify_app_token=xdnsidutsridx_ist
  gotify_priority=6
  ```
- 3. Update watcher frequency if needed

Default down watcher frequency is once per minute.
You can change that. Edit the cron file according to your
need.

  ```
    vim /etc/cron.d/uptime-kuma-down-watcher.conf
    #or
    nano /opt/cron.d/uptime-kuma-down-watcher.conf
  ```

- 4. Done

  Delete the cloned project

  ```
  rm -r ./uptime-kuma-down-watcher
  ```


  You're done, you'll receive notifications periodically when you have down monitors.
