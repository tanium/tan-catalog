#!/bin/bash
basedir="$(dirname $0)"
echo "basedir: ${basedir}"
echo "creating ${basedir}/tanium-client.tgz..."
tar -C ${basedir}/tanium-client \
  -czvf ${basedir}/tanium-client.tgz \
  --exclude=.DS_Store \
  --exclude=.terraform \
  --exclude=terraform.* .
echo "Done"
exit