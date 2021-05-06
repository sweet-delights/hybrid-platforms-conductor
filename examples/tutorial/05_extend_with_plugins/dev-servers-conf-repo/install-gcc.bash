hostname=${1}
check_flag=${2:-deploy}
if [ "${check_flag}" = "check" ]; then
  # Check if gcc is installed
  if ssh -o StrictHostKeyChecking=no root@${hostname} 'gcc --version' 2>/dev/null; then
    echo 'OK'
  else
    echo 'Missing'
  fi
else
  # Install gcc
  ssh -o StrictHostKeyChecking=no root@${hostname} 'apt install -y gcc' 2>/dev/null
  echo 'Installed'
fi
