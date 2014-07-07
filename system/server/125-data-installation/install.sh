#
### DATA ###
#

### SKIP ON UPGRADE ###
if [ -f "/etc/gislab/$GISLAB_INSTALL_CURRENT_SERVICE.done" ]; then return; fi

cp -a /vagrant/user/data /storage/repository/
chown -R :labadmins /storage/repository/*


# vim: set syntax=sh ts=4 sts=4 sw=4 noet:
