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
