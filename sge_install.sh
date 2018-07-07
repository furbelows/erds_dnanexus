<<<<<<< HEAD
#!/bin/sh
# Script to perform headless install on dnanexus instance
# Tested on ubuntu14.04 base docker image
# alden.huang@gmail.com 07062018

# update repos
apt-get update -qq

# configure the master host for SGE
echo "gridengine-master	shared/gridenginemaster string $HOSTNAME" | debconf-set-selections
echo "gridengine-master	shared/gridenginecell string default" | debconf-set-selections
echo "gridengine-master	shared/gridengineconfig boolean false" | debconf-set-selections
echo "gridengine-common	shared/gridenginemaster string $HOSTNAME" | debconf-set-selections
echo "gridengine-common	shared/gridenginecell string default" | debconf-set-selections
echo "gridengine-common	shared/gridengineconfig boolean false" | debconf-set-selections
echo "gridengine-client	shared/gridenginemaster string $HOSTNAME" | debconf-set-selections
echo "gridengine-client	shared/gridenginecell string default" | debconf-set-selections
echo "gridengine-client	shared/gridengineconfig boolean false" | debconf-set-selections
echo "postfix postfix/main_mailer_type	select	No configuration" |  debconf-set-selections

# sge install
DEBIAN_FRONTEND=noninteractive apt-get install -yq gridengine-master gridengine-exec gridengine-client

# set up sge
/usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin
service gridengine-master restart

# don't need this shit
service postfix stop
update-rc.d postfix disable

## change scheduler to allow rapid submits
cat > ./grid <<EOL
algorithm                         default
schedule_interval                 0:0:1
maxujobs                          0
queue_sort_method                 load
job_load_adjustments              np_load_avg=0.50
load_adjustment_decay_time        0:7:30
load_formula                      np_load_avg
schedd_job_info                   true
flush_submit_sec                  0
flush_finish_sec                  0
params                            none
reprioritize_interval             0:0:0
halftime                          168
usage_weight_list                 cpu=1.000000,mem=0.000000,io=0.000000
compensation_factor               5.000000
weight_user                       0.250000
weight_project                    0.250000
weight_department                 0.250000
weight_job                        0.250000
weight_tickets_functional         0
weight_tickets_share              0
share_override_tickets            TRUE
share_functional_shares           TRUE
max_functional_jobs_to_schedule   200
report_pjob_tickets               TRUE
max_pending_tasks_per_job         50
halflife_decay_list               none
policy_hierarchy                  OFS
weight_ticket                     0.500000
weight_waiting_time               0.278000
weight_deadline                   3600000.000000
weight_urgency                    0.500000
weight_priority                   0.000000
max_reservation                   0
default_duration                  INFINITY
EOL
qconf -Msconf ./grid
rm ./grid

echo -e "group_name @allhosts\nhostlist NONE" > ./grid
qconf -Ahgrp ./grid
rm ./grid

## add default queue
cat > ./grid <<EOL
qname                 all.q
hostlist              @allhosts
seq_no                0
load_thresholds       NONE
suspend_thresholds    NONE
nsuspend              1
suspend_interval      00:00:01
priority              0
min_cpu_interval      00:00:01
processors            UNDEFINED
qtype                 BATCH INTERACTIVE
ckpt_list             NONE
pe_list               make
rerun                 FALSE
slots                 2
tmpdir                /tmp
shell                 /bin/bash
prolog                NONE
epilog                NONE
shell_start_mode      posix_compliant
starter_method        NONE
suspend_method        NONE
resume_method         NONE
terminate_method      NONE
notify                00:00:01
owner_list            NONE
user_lists            NONE
xuser_lists           NONE
subordinate_list      NONE
complex_values        NONE
projects              NONE
xprojects             NONE
calendar              NONE
initial_state         default
s_rt                  INFINITY
h_rt                  INFINITY
s_cpu                 INFINITY
h_cpu                 INFINITY
s_fsize               INFINITY
h_fsize               INFINITY
s_data                INFINITY
h_data                INFINITY
s_stack               INFINITY
h_stack               INFINITY
s_core                INFINITY
h_core                INFINITY
s_rss                 INFINITY
h_rss                 INFINITY
s_vmem                INFINITY
h_vmem                INFINITY
EOL
qconf -Aq ./grid
rm ./grid

QUEUE="all.q"
HOSTNAME=`hostname`
SLOTS=`grep -c "^processor" /proc/cpuinfo`

# add to the execution host list
TMPFILE=/tmp/sge.hostname-$HOSTNAME
echo -e "hostname $HOSTNAME\nload_scaling NONE\ncomplex_values NONE\nuser_lists NONE\nxuser_lists NONE\nprojects NONE\nxprojects NONE\nusage_scaling NONE\nreport_variables NONE" > $TMPFILE
qconf -Ae $TMPFILE
rm $TMPFILE

# add to the all hosts list
qconf -aattr hostgroup hostlist $HOSTNAME @allhosts

# enable the host for the queue, in case it was disabled and not removed
qmod -e $QUEUE@$HOSTNAME

# add slots
if [ "$SLOTS" ]; then
    qconf -aattr queue slots "[$HOSTNAME=$SLOTS]" $QUEUE
fi

# add submit host
qconf -as `hostname`
service service gridengine-exec restart

# should be correct
qstat -f 
=======
#!/bin/bash
# This script installs and configures a Sun Grid Engine installation for use
# on a Travis instance.
#
# Written by Dan Blanchard (dblanchard@ets.org), September 2013
# 
# Edited by alden for dnanexus

# sudo sed -i -r "s/^(127.0.0.1\s)(localhost\.localdomain\slocalhost)/\1localhost localhost.localdomain $(hostname) /" /etc/hosts

# Update first
sudo apt-get update -qq

# Set parameters which will allow us to install SGE without opening pop-up.
# The first option was missing before, not having this still opens the pop-up and asks for email 
# configuration.
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
# Recall that we are now going to set master as the instance hostname.
echo "gridengine-master shared/gridenginemaster string $(hostname)" | sudo debconf-set-selections
# THe rest remains unchanged.
echo "gridengine-master shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-master shared/gridengineconfig boolean true" | sudo debconf-set-selections
# The first main step. Install grid engine.
sudo apt-get install gridengine-common gridengine-master
# Do this in a separate step to give master time to start
# The next line changes slightly. I install gridengine-drmaa1.0 since I am use Ubuntu 14.04 for amazon EC2.
sudo apt-get install gridengine-drmaa1.0 gridengine-client gridengine-exec

# Obtain the number of cores and some parts remain unchanged.
export CORES=$(grep -c '^processor' /proc/cpuinfo)
sed -i -r "s/template/$USER/" user_template
sudo qconf -Auser user_template
sudo qconf -au $USER arusers
# Instead of adding localhost as submitter add the hostname.
sudo qconf -as $HOSTNAME

# Add the host name. 
sed -i -r "s/HOST/$HOSTNAME/" host_template
sudo qconf -Ae host_template

# Specify number of cores.
sed -i -r "s/UNDEFINED/$CORES/" queue_template
# Add the host name. 
sed -i -r "s/HOST/$HOSTNAME/" queue_template

sudo qconf -Ap smp_template
sudo qconf -Aq queue_template

echo "Printing queue info to verify that things are working correctly."
qstat -f -q all.q -explain a
echo "You should see sge_execd and sge_qmaster running below:"
ps aux | grep "sge"
>>>>>>> 906f2e6d7cab696567707b187cbc8ced3dfb87fd
