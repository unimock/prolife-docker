#!/bin/bash

echo "#################################################"

echo "# starting container boot up script (start.sh)  #"
echo "#################################################"

echo "export APP_SMTP_SERVER=${APP_SMTP_SERVER}"  > /.env
echo "export MYSQL_USER=${MYSQL_USER}"           >> /.env
echo "export MYSQL_PASSWORD=${MYSQL_PASSWORD}"   >> /.env
chmod a+r /.env

list=$(ls -1 /etc/supervisor/boot.d/* 2>/dev/null)
for i in $list ; do
  echo "execute : <$i>"
  $i
done


echo "#################################################"
echo "# check for disabled services"
echo "#"

for task in $DISABLED_SERVICES ; do
  echo "disable : $task"
  sed  -i "/program:$task/a autostart=false"  /etc/supervisor/services.d/$task
  if [ -e /etc/logrotate.d/$task ] ; then
    rm -v /etc/logrotate.d/$task
  fi 
done

echo "#################################################"
echo "# execute init scripts for enabled services"
echo "#"


list=$(ls -1 /etc/supervisor/init.d/* 2>/dev/null)
for i in $list ; do
  if [ -e $i ] ; then
    task=`basename $i`
     if [ "$(grep 'autostart=false' /etc/supervisor/services.d/${task})" = "" ] ; then
       echo "execute: <$task>"
       $i
     fi
  fi
done



# Tweak nginx to match the workers to cpu's
procs=$(cat /proc/cpuinfo |grep processor | wc -l)
sed -i -e "s/worker_processes 5/worker_processes $procs/" /etc/nginx/nginx.conf

# Set the right permissions (needed when mounting from a volume)
chown -Rf www-data.www-data /usr/share/nginx/html/
mkdir -p  /var/www/.ssh
chmod 777 /var/www/.ssh

echo "#################################################"
echo "# start supervisord"
echo "#"

trap 'kill -TERM $PID; wait $PID' TERM
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &

PID=$!
wait $PID

echo "#################################################"
echo "# shutdown container"
echo "#"
list=$(ls -1 /etc/supervisor/shutdown.d/* 2>/dev/null)
for i in $list ; do
  echo "execute: <$i>"
  $i
done
