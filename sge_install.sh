#!/bin/sh
# Script to perform headless install on dnanexus instance
# Tested on ubuntu14.04 base docker image
# alden.huang@gmail.com 07062018

# update repos
sudo apt-get update -qq

# configure the master host for SGE
echo "gridengine-master shared/gridenginemaster string localhost" | sudo debconf-set-selections
echo "gridengine-master shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-master shared/gridengineconfig boolean true" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections

# sge install
sudo DEBIAN_FRONTEND=noninteractive apt-get install gridengine-common gridengine-master
sudo DEBIAN_FRONTEND=noninteractive apt-get install gridengine-client gridengine-exec

# don't need this shit
sudo service postfix stop
sudo update-rc.d postfix disable

## change scheduler to allow rapid submits
sudo qconf -Msconf erds_dnanexus/scheduler_defaults

echo -e "group_name @allhosts\nhostlist NONE" > ./grid
sudo qconf -Ahgrp ./grid
rm ./grid

## add default queue
sudo qconf -Aq erds_dnanexus/queue_defaults

QUEUE="all.q"
HOSTNAME=`hostname`
SLOTS=`grep -c "^processor" /proc/cpuinfo`

# add to the execution host list
qconf -Ae erds_dnanexus/host_defa
rm $TMPFILE

# add to the all hosts list
sudo qconf -aattr hostgroup hostlist $HOSTNAME @allhosts

# enable the host for the queue, in case it was disabled and not removed
sudo qmod -e $QUEUE@$HOSTNAME

# add slots
if [ "$SLOTS" ]; then
    sudo qconf -aattr queue slots "[$HOSTNAME=$SLOTS]" $QUEUE
fi

# add submit host
sudo qconf -as `hostname`
sudo service gridengine-exec restart

# should be correct
qstat -f 
