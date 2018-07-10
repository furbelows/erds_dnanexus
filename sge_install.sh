#!/bin/sh
# Script to perform headless install on dnanexus instance
# Tested on ubuntu14.04 dnanexus cloud workstation
# alden.huang@gmail.com 07062018

# update repos
sudo apt-get update -qq

# configure the master host for SGE
echo "gridengine-master shared/gridenginemaster string $(hostname)" | sudo debconf-set-selections
echo "gridengine-master shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-master shared/gridengineconfig boolean true" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections

# sge install
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-common gridengine-master
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-client gridengine-exec

# don't need this shit
sudo service postfix stop
sudo update-rc.d postfix disable

# add me to the sgeadmin
sudo qconf -am dnanexus

## change scheduler to allow rapid submits
sudo qconf -Msconf scheduler_defaults

echo "group_name @allhosts\nhostlist NONE" > /home/dnanexus/grid
sudo qconf -Ahgrp /home/dnanexus/grid
rm /home/dnanexus/grid

## add default queue
sudo qconf -Aq queue_defaults

QUEUE="all.q"
HOSTNAME=`hostname`
SLOTS=`grep -c "^processor" /proc/cpuinfo`

# add to the execution host list
echo "hostname $HOSTNAME\nload_scaling NONE\ncomplex_values NONE\nuser_lists NONE\nxuser_lists NONE\nprojects NONE\nxprojects NONE\nusage_scaling NONE\nreport_variables NONE" > /home/dnanexus/host_defaults
sudo qconf -Ae /home/dnanexus/host_defaults
rm /home/dnanexus/host_defaults

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

## DONE!
