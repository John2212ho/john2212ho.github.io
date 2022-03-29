#!/bin/bash


#change the following to "false" to disable auto web updates
updcheck="true"
#change the following to "false" to disable all replacements (e.g. changing the default server, ensuring bungeecord is on the right port, etc.)
rplcheck="true"

echo ensuring old server process is truly closed...
nginx -s stop -c ~/$REPL_SLUG/nginx.conf -g 'daemon off; pid /tmp/nginx/nginx.pid;' -p /tmp/nginx -e /tmp/nginx/error.log
pkill java
pkill nginx
rm -rf /tmp/*
echo deleting old backup files...
rm -rf old/

echo verifying files...
if [ -d "java" -a -d "web" ]; then
    echo files exist! proceeding...
else
    echo files do not exist! forcing download, if needed...
    updcheck="true"
    rplcheck="true"
fi

if [ "$updcheck" = "true" ]; then
  echo backing up old files...
  mkdir old
  mv java web old
  echo checking if file still works...

  status_code=$(curl -L --write-out %{http_code} --silent --output /dev/null https://raw.githubusercontent.com/LAX1DUDE/eaglercraft/main/stable-download/stable-download.zip)

  if [[ "$status_code" -ne 200 ]] ; then
    echo site is down! using backup files...
    cp old/java old/web ./
  else
    echo site is still up! downloading...
    curl -L -o stable-download.zip https://raw.githubusercontent.com/LAX1DUDE/eaglercraft/main/stable-download/stable-download.zip
    echo extracting zip...
    unzip stable-download.zip
    echo deleting original zip file...
    rm -rf stable-download.zip
  fi

  echo verifying files...
  if [ -d "java" -a -d "web" ]; then
      echo files exist! proceeding...
  else
      echo files do not exist! using backup files...
      cp old/java old/web ./
  fi

  #todo: detect modified files
  if [ -d "old/java/bukkit_command" -a -d "old/java/bungee_command" ]; then
      echo restoring servers from backup so you dont lose data...
      rm -rf java/*
      cp -r old/java/* ./java/
  fi
fi

if [ "$rplcheck" = "true" ]; then
  echo ensuring that bungeecord is hosting on the correct port...
  sed -i 's/host: 0\.0\.0\.0:[0-9]\+/host: 0.0.0.0:1/' java/bungee_command/config.yml
fi

echo starting bungeecord...
cd java/bungee_command
java -Xmx32M -Xms32M -jar bungee-dist.jar > /dev/null 2>&1 &
cd -

if [ "$rplcheck" = "true" ]; then
  echo configuring local website...
  sed -i 's/https:\/\/g\.eags\.us\/eaglercraft/https:\/\/gnome\.vercel\.app/' web/index.html
  sed -i 's/alert/console.log/' web/index.html
  echo setting default server...
  sed -i 's/"CgAACQAHc2VydmVycwoAAAABCAACaXAAIHdzKHMpOi8vIChhZGRyZXNzIGhlcmUpOihwb3J0KSAvCAAEbmFtZQAIdGVtcGxhdGUBAAtoaWRlQWRkcmVzcwEIAApmb3JjZWRNT1REABl0aGlzIGlzIG5vdCBhIHJlYWwgc2VydmVyAAA="/btoa(atob("CgAACQAHc2VydmVycwoAAAABCAAKZm9yY2VkTU9URABtb3RkaGVyZQEAC2hpZGVBZGRyZXNzAQgAAmlwAGlwaGVyZQgABG5hbWUAbmFtZWhlcmUAAA==").replace("motdhere",String.fromCharCode("Your Minecraft Server".length)+"Your Minecraft Server").replace("namehere",String.fromCharCode("Minecraft Server".length)+"Minecraft Server").replace("iphere",String.fromCharCode(("ws"+location.protocol.slice(4)+"\/\/"+location.host+"\/server").length)+("ws"+location.protocol.slice(4)+"\/\/"+location.host+"\/server")))/' web/index.html
fi

echo starting nginx...
mkdir /tmp/nginx
rm -rf nginx.conf
sed "s/eaglercraft-server/$REPL_SLUG/" nginx_template.conf > nginx.conf
nginx -c ~/$REPL_SLUG/nginx.conf -g 'daemon off; pid /tmp/nginx/nginx.pid;' -p /tmp/nginx -e /tmp/nginx/error.log > /tmp/nginx/output.log 2>&1 &

echo starting bukkit...
cd java/bukkit_command
java -Xmx512M -Xms512M -jar craftbukkit-1.5.2-R1.0.jar
cd -

echo killing bungeecord and nginx...
nginx -s stop -c ~/$REPL_SLUG/nginx.conf -g 'daemon off; pid /tmp/nginx/nginx.pid;' -p /tmp/nginx -e /tmp/nginx/error.log
pkill java
pkill nginx

echo done!