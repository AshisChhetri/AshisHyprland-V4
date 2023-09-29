#!/bin/bash

#
# install bc package
# yay -S bc
#

# network_traffic.sh [-t POLLING_INTERVAL] [NETWORK_INTERFACE...]

getopts t: __ && shift
isecs=${OPTARG:-1}
ifaces=($@)
: ${rate_max:=1000000} # maximum transfer rate for {percent}, can be overridden setting the env var

# `snore` adapted from https://blog.dhampir.no/content/sleeping-without-a-subprocess-in-bash-and-how-to-sleep-forever
# without MacOS workaround, TODO: with _snore_fd initialized separatedly, also I don't touch IFS so don't bother with it
snore() {
    local IFS
    [[ -n "${_snore_fd:-}" ]] || { exec {_snore_fd}<> <(:); } 2>/dev/null
    read ${1:+-t "$1"} -u $_snore_fd || :
}

exit_err() {
  printf '{"text": "⚠ %s", "tooltip": "%s", "class": "error"}\n' "$@"
  exit
}

if test ${#ifaces[@]} -gt 0; then
# sanity check the interface names
  for iface in ${ifaces[@]}; do
    test -h "/sys/class/net/${iface}" || exit_err "${iface}" "${iface} is not an existing network interface name"
  done
else
# default to all interfaces except `lo`
  ifaces=(/sys/class/net/*)
  ifaces=(${ifaces[@]##*/})
  ifaces=(${ifaces[@]//lo/})
# TODO: check that filtering out `lo` is enough, else `^(eth|wlan|enp|wlp)` as suggested
fi

# sanity check polling interval
if test ${isecs} -lt 1; then
  exit_err "${isecs}" "${isecs} is not a valid polling interval"
fi

# NOTE: array items are:
# 0=rx_bytes 1=rx_packets 2=rx_errs 3=rx_drop
# 4=tx_bytes 5=tx_packets 6=tx_errs 7=tx_drop
for iface in ${ifaces[@]} aggregate; do
  declare -a traffic_prev_${iface} traffic_curr_${iface} traffic_delt_${iface}
  declare -n traffic_prev=traffic_prev_${iface}
  declare -n traffic_curr=traffic_curr_${iface}
  declare -n traffic_delt=traffic_delt_${iface}
  traffic_prev=(0 0 0 0 0 0 0 0)
  traffic_curr=(0 0 0 0 0 0 0 0)
  traffic_delt=(0 0 0 0 0 0 0 0)
done

while snore ${isecs} ;do
  traffic_delt_aggregate=(0 0 0 0 0 0 0 0)

  readarray -s2 proc_net_dev </proc/net/dev
  while read -a data; do
    iface=${data[0]%:}
    test "${ifaces[*]}" = "${ifaces[*]//${iface}/}" && continue
    declare -n traffic_prev=traffic_prev_${iface}
    declare -n traffic_curr=traffic_curr_${iface}
    declare -n traffic_delt=traffic_delt_${iface}
    traffic_curr=(${data[@]:1:4} ${data[@]:9:4})

    for i in {0..7}; do
      (( traffic_delt[i] = ( traffic_curr[i] - traffic_prev[i] ) / isecs ))
      (( traffic_delt_aggregate[i] += traffic_delt[i] ))
    done
    traffic_prev=(${traffic_curr[@]})
  done <<<"${proc_net_dev[@]}"

  rx_speed_mb=$(bc <<< "scale=2; ${traffic_delt_aggregate[0]} / (1024 * 1024) / ${isecs}")
  tx_speed_mb=$(bc <<< "scale=2; ${traffic_delt_aggregate[4]} / (1024 * 1024) / ${isecs}")

  printf '{"text": "%.2fm⇣:%.2fm⇡", "tooltip": "⇣: %.2f MB/s, ⇡: %.2f MB/s", "class": "normal"}\n' \
    $rx_speed_mb $tx_speed_mb $rx_speed_mb $tx_speed_mb
done
