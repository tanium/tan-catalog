#!/usr/bin/env bash

usage() {
  cat <<USAGE
Usage: bash $0 [OPTIONS]
  OPTIONS:
  --tanium-server                 Tanium server hostname/ip-address
  --tanium-client-files-folder    (Required) Path to Tanium client files stored in COS bucket
                                  Eg: cos-bucket-name/path/to/tanium-client-files-folder
  --apikey                        (Required) API key from Service Credential controlling
                                  access to COS bucket where dat file is stored
  --cos-bucket-public-endpoint    (Required) COS bucket public endpoint URL
  -h, --help)                     Print usage
USAGE
}

# options
tanium_server=""
apikey=""
cos_bucket_public_endpoint=""
client_folder=""

# parse options
while (( "$#" )); do
  case "$1" in
    --tanium-server)
      tanium_server="$2"
      shift 2
      ;;
    --tanium-client-files-folder)
      client_folder="$2"
      shift 2
      ;;
    --apikey)
      apikey=$2
      shift 2
      ;;
    --cos-bucket-public-endpoint)
      cos_bucket_public_endpoint=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit
      ;;
    *)
      echo -e "Error: Invalid arg(s)"
      usage
      exit 1
      ;;
  esac
done

# exit if missing args
if [[ -z ${apikey} || \
      -z ${cos_bucket_public_endpoint} || \
      -z ${tanium_server} || \
      -z ${client_folder} ]]; then
  echo "Error: Missing arg(s)"
  usage
  exit 1
fi

# tanium files target folder
tanium_dir="/tmp/tanium-$(date +%Y%m%d%H%M%S)"
mkdir -p ${tanium_dir}
echo "Tanium files directory: ${tanium_dir}"

# install curl on debian machines
uname -a | grep -i debian >/dev/null
if [[ $? -eq 0 ]]; then
  which curl >/dev/null
  if [[ $? -ne 0 ]]; then
    echo "Installing curl on Debian machine..."
    apt-get update
    apt-get install -y curl
  fi
fi

# exit if curl not found
which curl >/dev/null || \
  { echo "Error: curl not found. Exit with error."; exit 1; }

# get iam-access-token
access_token=$(curl -X "POST" "https://iam.cloud.ibm.com/oidc/token" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "apikey=${apikey}" \
  --data-urlencode "response_type=cloud_iam" \
  --data-urlencode "grant_type=urn:ibm:params:oauth:grant-type:apikey" \
  | tr '\n' ' ' | cut -d, -f1 | cut -d: -f2 | sed 's/"//g')
if [[ "$?" -eq "0" ]]; then
  echo "IAM token successfully downloaded"
else
  echo "Error: Failed to get IAM access token. Check COS bucket apikey and try again"
  exit 1
fi

# download tanium init dat file
tanium_dat="${tanium_dir}/tanium-init.dat"
echo "Downloading: https://${cos_bucket_public_endpoint}/${client_folder}/tanium-init.dat"
curl "https://${cos_bucket_public_endpoint}/${client_folder}/tanium-init.dat"  \
  -H "Authorization: bearer ${access_token}" \
  --output ${tanium_dat}
if [[ "$?" -eq "0" ]]; then
  echo "Downloaded to: ${tanium_dat}"
else
  echo "Error: Failed to download Tanium init dat file. Exit with error"
  exit 1
fi

# download installer file and install
get_installer_file() {
  echo "Downloading: https://${cos_bucket_public_endpoint}/${client_folder}/$1"
  curl "https://${cos_bucket_public_endpoint}/${client_folder}/$1" \
  -H "Authorization: bearer ${access_token}" \
  --output ${tanium_dir}/$1
  if [[ "$?" -eq "0" ]]; then
    echo "Downloaded to: ${tanium_dir}/$1"
  else
    echo "Error: Failed to download Tanium client install file. Exit with error"
    exit 1
  fi
}

# cleanup
cleanup() {
  echo "Delete downloaded Tanium client files folder ${tanium_dir}..."
  rm -rf ${tanium_dir}
  echo "Done."
}

echo "Checking for amazon1-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/os-release && cat /etc/os-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Amazon Linux AMI 201.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.amzn2018.03.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.amzn2018.03.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for amazon2-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/os-release && cat /etc/os-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Amazon Linux 2"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.amzn2.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.amzn2.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    service taniumclient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for rhe6-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Red Hat Enterprise.*release[[:space:]]6.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe6.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe6.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for centos6-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "CentOS .*release[[:space:]]6.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe6.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe6.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for centos6-x86"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "CentOS .*release[[:space:]]6.*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe6.i686.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe6.i686.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for rhe6-x86"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Red Hat Enterprise.*release[[:space:]]6.*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe6.i686.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe6.i686.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for centos7-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "CentOS .*release[[:space:]]7.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe7.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe7.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for rhe7-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Red Hat Enterprise.*release[[:space:]]7.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe7.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe7.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for debian8-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/debian-version && cat /etc/debian-version 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Debian GNU/Linux 8.[0-9]*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-debian8_amd64.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-debian8_amd64.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for debian8-x86"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/debian-version && cat /etc/debian-version 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Debian GNU/Linux 8.[0-9]*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-debian8_i386.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-debian8_i386.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for debian9-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/debian-version && cat /etc/debian-version 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Debian GNU/Linux 9.[0-9]*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-debian9_amd64.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-debian9_amd64.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for debian9-x86"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/debian-version && cat /etc/debian-version 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Debian GNU/Linux 9.[0-9]*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-debian9_i386.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-debian9_i386.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for opensuse12-x64"
COMMAND_RESULT=$(echo "$(cat /etc/os-release 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "openSUSE 12.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.sle12.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.sle12.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient.service
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for opensuse12-x64"
COMMAND_RESULT=$(echo "$(cat /etc/os-release 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "SUSE Linux Enterprise Server 12"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.sle12.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.sle12.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient.service
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for opensuse12-x86"
COMMAND_RESULT=$(echo "$(cat /etc/os-release 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "openSUSE 12.*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.sle12.i586.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.sle12.i586.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient.service
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for opensuse12-x86"
COMMAND_RESULT=$(echo "$(cat /etc/os-release 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "SUSE Linux Enterprise Server 12"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.sle12.i586.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.sle12.i586.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient.service
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for oracle6-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/oracle-release && cat /etc/oracle-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Oracle Linux Server release 6.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.oel6.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.oel6.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for oracle6-x86"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/oracle-release && cat /etc/oracle-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Oracle Linux Server release 6.*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.oel6.i686.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.oel6.i686.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for oracle7-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/oracle-release && cat /etc/oracle-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Oracle Linux Server release 7.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.oel7.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.oel7.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient.service
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for ubuntu14-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "[Uu]buntu 14.[0-9]*.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-ubuntu14_amd64.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-ubuntu14_amd64.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    service taniumclient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for ubuntu16-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "[Uu]buntu 16.[0-9]*.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-ubuntu16_amd64.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-ubuntu16_amd64.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for ubuntu18-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "[Uu]buntu 18.[0-9]*.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-ubuntu18_amd64.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-ubuntu18_amd64.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for centos5-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "CentOS .*release[[:space:]]5.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe5.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe5.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for rhe5-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Red Hat Enterprise.*release[[:space:]]5.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe5.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe5.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for centos5-x86"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "CentOS .*release[[:space:]]5.*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe5.i386.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe5.i386.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for rhe5-x86"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Red Hat Enterprise.*release[[:space:]]5.*"
OS_MATCH=$?
if [[ $OS_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe5.i386.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe5.i386.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    /sbin/service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for oracle5-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/oracle-release && cat /etc/oracle-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Oracle Linux Server release 5.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.oel5.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.oel5.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    service TaniumClient start
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for rhel8-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/redhat-release && cat /etc/redhat-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Red Hat Enterprise.*release[[:space:]]8.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe8.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe8.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for rhel8-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(cat /etc/redhat-release 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "CentOS .*release[[:space:]]8.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file TaniumClient-7.4.2.2073-1.rhe8.x86_64.rpm
  rpm -i ${tanium_dir}/TaniumClient-7.4.2.2073-1.rhe8.x86_64.rpm
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for debian10-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/debian-version && cat /etc/debian-version 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "Debian GNU/Linux 10.[0-9]*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-debian10_amd64.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-debian10_amd64.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi

echo "Checking for ubuntu20-x64"
COMMAND_RESULT=$(echo "$(uname -a 2>/dev/null)"; echo "$(test -f /etc/lsb-release && cat /etc/lsb-release 2>/dev/null)"; echo "$(test -f /etc/issue && cat /etc/issue 2>/dev/null)"; echo "$(uname -m 2>/dev/null)")
echo "$COMMAND_RESULT" | grep -q "[Uu]buntu 20.[0-9]*.*"
OS_MATCH=$?
echo "$COMMAND_RESULT" | grep -q "x86_64"
ARCH_MATCH=$?
if [[ $OS_MATCH -eq "0" && $ARCH_MATCH -eq "0" ]]; then
  get_installer_file taniumclient_7.4.2.2073-ubuntu20_amd64.deb
  dpkg -i ${tanium_dir}/taniumclient_7.4.2.2073-ubuntu20_amd64.deb
  if [[ "$?" -eq "0" ]]; then
    echo "Install successful"
    echo "Setting ServerNameList in client config..."
    /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList ${tanium_server}
    echo "Copying ${tanium_dat}..."
    mv ${tanium_dat} /opt/Tanium/TaniumClient/tanium-init.dat
    ls -l /opt/Tanium/TaniumClient/tanium-init.dat
    echo "Starting service."
    systemctl start taniumclient
  else
    echo "Install failed."
  fi
  cleanup
  exit
fi