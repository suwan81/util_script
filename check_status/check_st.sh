#!/bin/bash

if [ $# -ne 1 ];then
 exit
fi

### DATE
now=$(date +"%Y%m%d%H%M")
LOG_FILE="/var/log/ansible-gpdb.log"
LOG_TIME=$(date +%Y-%m-%d@%H:%M:%S)

### check status functions
passwd="1234Qwer"
cs_host_path="$1"

function get_gpdb_conf(){
gpdb_ct=$(ps -ef | grep -v grep | grep postgres | wc -l)
if [ $gpdb_ct -ne 0 ];then
 gpdb_err="-1"
 gpdb_st=$(echo "$(su -l gpadmin -c 'gpstate')")
 gpconf_st1=$(echo "$(su -l gpadmin -c 'gpconfig -s max_connections')")
 gpconf_st2=$(echo "$(su -l gpadmin -c 'gpconfig -s max_prepared_transactions')")
 gpconf_st3=$(echo "$(su -l gpadmin -c 'gpconfig -s gp_vmem_protect_limit')")
 gpconf_st4=$(echo "$(su -l gpadmin -c 'gpconfig -s gp_resqueue_priority_cpucores_per_segment')")
 gpconf_st5=$(echo "$(su -l gpadmin -c 'gpconfig -s gp_resqueue_priority_inactivity_timeout')")
 gpconf_st6=$(echo "$(su -l gpadmin -c 'gpconfig -s xid_stop_limit')")
 gpconf_st7=$(echo "$(su -l gpadmin -c 'gpconfig -s xid_warn_limit')")
 gppkg_st=$(echo "$(su -l gpadmin -c 'gppkg -q --all')")
else
 gpdb_err="Not started GPDB!"
fi
gpfo_ct1=$(ssh smdw 'ps -ef | grep -v grep | grep gpfailover | wc -l')
gpfo_ct2=$(ssh smdw 'systemctl status gpfailover | grep "active (running)" | wc -l')
if [ $gpfo_ct1 -ge 1 ] && [ $gpfo_ct2 -eq 1 ];then
 gpfo_st="Active"
else
 gpfo_st="Stopped"
fi
gpcc_ct=$(ps -ef | grep -v grep | grep ccagent | wc -l)
if [ $gpcc_ct -ne 0 ];then
 gpcc_err="1"
 gpcc_ver=$(echo "$(su -l gpadmin -c 'gpcc -v')")
 gpcc_st=$(echo "$(su -l gpadmin -c 'gpcc status')")
else
 gpcc_err="Not started GPCC!"
fi
pxf_ct=0
pxf_seg_c=0
for i in $(cat /home/gpadmin/gpconfigs/host_seg)
do
 let pxf_ct=$pxf_ct+$(ssh $i 'ps -ef | grep -v grep | grep pxf | wc -l')
 pxf_seg_c=$((pxf_seg_c+1))
done
if [ $pxf_ct -eq $pxf_seg_c ];then
 pxf_err="-1"
 pxf_st=$(echo "$(su -l gpadmin -c '/usr/local/greenplum-db/pxf/bin/pxf cluster status')")
else
 c_pxf_st="Not installed PXF!"
fi
}

function check_vip(){
vip_ip=$(cat /usr/local/bin/vip_env.sh | grep -w "VIP" | awk -F'=' '{print$2}')
vip_net=$(cat /usr/local/bin/vip_env.sh | grep -w "VIP_NETMASK" | awk -F'=' '{print$2}')
vip_gate=$(cat /usr/local/bin/vip_env.sh | grep -w "VIP_GW" | awk -F'=' '{print$2}')
vip_ori=$(cat /usr/local/bin/vip_env.sh | grep -w "ARPING_INTERFACE" | awk -F'=' '{print$2}')
vip_int=$(cat /usr/local/bin/vip_env.sh | grep -w "VIP_INTERFACE" | awk -F'=' '{print$2}')

function page1(){
msg_show " === OS Configuration === "
echo ""
echo "[Current<mdw> Configuration]"
os_ver=$(cat /tmp/check_status_$(hostname) | grep "os_ver:" | awk -F':' '{print$2}')
ker_ver=$(cat /tmp/check_status_$(hostname) | grep "kernel_ver:" | awk -F':' '{print$2}')
mtu=$(cat /tmp/check_status_$(hostname) | grep "mtu:" | awk -F':' '{print$2}')
echo " OS Version       : $os_ver"
echo " Kernel Version   : $ker_ver"
echo " MTU              : $mtu"
echo ""
mlist=(OS_ver Kernel_Ver MTU)
printf "%-15s" ""
printf "%-20s" "Hostname"
for menu in "${mlist[@]}"
do
 printf "%-12s" "$menu"
done
printf "\n"
for var in $(cat $cs_host_path)
do
 sfile=""
 sfile=$(ls /tmp/check_status_* | grep -w "/tmp/check_status_$(cat /etc/hosts | grep -v "###" | grep -w "$var" | awk '{print$2}')")
 st_host=""
 st_host=$(cat $sfile | grep "hostname:" | awk -F':' '{print$2}')
 if [ "$os_ver" == "$(cat $sfile | grep "os_ver:" |. awk -F':' '{print$2}')" ];then
  st_os="O"
 else
  st_os="-"
 fi
 if [ "$ker_ver" == "$(cat $sfile | grep "kernel_ver:" | awk -F':' '{print$2}')" ];then
  st_ker="O"
 else
  st_ker="-"
 fi
 if [ "$mtu" == "$(cat $sfile | grep "mtu:" | awk -F':' '{print$2}')" ];then
  st_mtu="O"
 else
  st_mtu="-"
 fi
 hn=$(printf '%-15s' "$var")
 printf "%s%-20s%-12s%-12s%-12s\n" "$hn" "$st_host" "$st_os" "$st_ker" "$st_mtu"
done
}

function page2(){
msg_show " === Service & Deamon === "
msg_show " (1st: Service, 2nd: Daemon) "
echo ""
mlist=(SELinux Firewall NTP RC-LOCAL KDUMP)
printf "%-15s" ""
for menu in "${mlist[@]}"
do
 printf "%-12s" "$menu"
done
printf "\n"
for var in $(cat $cs_host_path)
do
 sfile =""
 sfile=$(ls /tmp/check_status_* | grep -w "/tmp/check_status_$(cat /etc/hosts | grep -v "###" | grep -w "$var" | awk '{print$2}')")
 if [ "$(cat $sfile | grep "selinux" | awk -F':' '{print2}')" == "disabled" ];then
  st_selinux="O"
 else
  st_selinux="-"
 fi
 if [ "$(cat $sfile | grep "firewall_st1" | awk -F':' '{print2}')" == "inactive" ];then
  st_firewall1="O"
 else
  st_firewall1="-"
 fi
 if [ "$(cat $sfile | grep "firewall_st2" | awk -F':' '{print2}')" == "disabled" ];then
  st_firewall2="O"
 else
  st_firewall2="-"
 fi
 if [ "$(cat $sfile | grep "ntp_st1" | awk -F':' '{print2}')" == "active" ];then
  st_ntp1="O"
 else
  st_ntp1="-"
 fi
 if [ "$(cat $sfile | grep "ntp_st2" | awk -F':' '{print2}')" == "enabled" ];then
  st_ntp2="O"
 else
  st_ntp2="-"
 fi
 if [ "$(cat $sfile | grep "rclocal_st1" | awk -F':' '{print2}')" == "active" ];then
  st_rclocal1="O"
 else
  st_rclocal1="-"
 fi
 if [ "$(cat $sfile | grep "rclocal_st2" | awk -F':' '{print2}')" == "static" ];then
  st_rclocal2="O"
 else
  st_frclocal2="-"
 fi
 if [ "$(cat $sfile | grep "kdump_st1" | awk -F':' '{print2}')" == "active" ];then
  st_kdump1="O"
 else
  st_kdump1="-"
 fi
 if [ "$(cat $sfile | grep "kdump_st2" | awk -F':' '{print2}')" == "enabled" ];then
  st_kdump2="O"
 else
  st_kdump2="-"
 fi
 hn=$(printf '%-15s' "$var")
 printf "%s%-12s%-12s%-12s%-12s%-12s\n" "$hn" "$st_selinux" "$st_firewall1$st_firewall2" "$st_ntp1$st_ntp2" "$st_rclocal1$st_rclocal2" "$st_kdump1$st_kdump2"
done
}

function page3(){
msg_show " === OS Configuration === "
msg_show " (Base on mdw parameter) "
echo ""
mlist=(Grubby Resolve Sysctl Ulimit)
printf "%-15s" ""
for menu in "${mlist[@]}"
do
 printf "%-12s" "$menu"
done
printf "\n"
mfile=$(ls /tmp/check_status_* | grep -w "/tmp/check_status_$(cat /etc/hosts | grep -v "###" | grep -w "mdw" | awk '{print$2}')")
grubby_st=$(sed -n "$(($(grep -n "grubby:" $mfile | cut -d':' -f1)+1)),$(($(grep -n ":grubby" $mfile | cut -d':' -f1)-1))p" $mfile)
resolve_st=$(sed -n "$(($(grep -n "resolve:" $mfile | cut -d':' -f1)+1)),$(($(grep -n ":resolve" $mfile | cut -d':' -f1)-1))p" $mfile)
sysctl_st=$(sed -n "$(($(grep -n "sysctl:" $mfile | cut -d':' -f1)+1)),$(($(grep -n ":sysctl" $mfile | cut -d':' -f1)-1))p" $mfile)
ulimit_st=$(sed -n "$(($(grep -n "ulimit:" $mfile | cut -d':' -f1)+1)),$(($(grep -n ":ulimit" $mfile | cut -d':' -f1)-1))p" $mfile)
for var in $(cat $cs_host_path)
do
 sfile=""
 sfile=$(ls /tmp/check_status_* | grep -w "/tmp/check_status_$(cat /etc/hosts | grep -v "###" | grep -w "$var" | awk '{print$2}')")
 if [ "$grubby_st" == "$(sed -n "$(($(grep -n "grubby:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":grubby" $sfile | cut -d':' -f1)-1))p" $sfile)" ];then
  re1="O"
 else
  re1="-"
 fi
 if [ "$resolve_st" == "$(sed -n "$(($(grep -n "resolve:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":resolve" $sfile | cut -d':' -f1)-1))p" $sfile)" ];then
  re2="O"
 else
  re2="-"
 fi
 if [ "$sysctl_st" == "$(sed -n "$(($(grep -n "sysctl:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":sysctl" $sfile | cut -d':' -f1)-1))p" $sfile)" ];then
  re3="O"
 else
  re3="-"
 fi
 if [ "$ulimit_st" == "$(sed -n "$(($(grep -n "ulimit:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":ulimit" $sfile | cut -d':' -f1)-1))p" $sfile)" ];then
  re4="O"
 else
  re4="-"
 fi
 hn=$(printf '%-15s' "$var")
 printf "%s%-12s%-12s%-12s%-12s\n" "$hn" "$re1" "$re2" "$re3" "$re4"
done
}

function page4(){
msg_show " === OS Configuration === "
msg_show " (Base on mdw parameter) "
echo ""
mlist=(Logind SSHD YUM Blockdev)
printf "%-15s" ""
for menu in "${mlist[@]}"
do
 printf "%-12s" "$menu"
done
printf "\n"
mfile=$(ls /tmp/check_status_* | grep -w "/tmp/check_status_$(cat /etc/hosts | grep -v "###" | grep -w "mdw" | awk '{print$2}')")
logind_st=$(sed -n "$(($(grep -n "logind:" $mfile | cut -d':' -f1)+1)),$(($(grep -n ":logind" $mfile | cut -d':' -f1)-1))p" $mfile)
sshd_st=$(sed -n "$(($(grep -n "sshd:" $mfile | cut -d':' -f1)+1)),$(($(grep -n ":sshd" $mfile | cut -d':' -f1)-1))p" $mfile)
yum_st=$(sed -n "$(($(grep -n "yum:" $mfile | cut -d':' -f1)+1)),$(($(grep -n ":yum" $mfile | cut -d':' -f1)-1))p" $mfile)
for var in $(cat $cs_host_path)
do
 sfile=""
 sfile=$(ls /tmp/check_status_* | grep -w "/tmp/check_status_$(cat /etc/hosts | grep -v "###" | grep -w "$var" | awk '{print$2}')")
 if [ "$logind_st" == "$(sed -n "$(($(grep -n "logind:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":logind" $sfile | cut -d':' -f1)-1))p" $sfile)" ];then
  re1="O"
 else
  re1="-"
 fi
 if [ "$sshd_st" == "$(sed -n "$(($(grep -n "sshd:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":sshd" $sfile | cut -d':' -f1)-1))p" $sfile)" ];then
  re2="O"
 else
  re2="-"
 fi
 if [ "$yum_st" == "$(sed -n "$(($(grep -n "yum:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":yum" $sfile | cut -d':' -f1)-1))p" $sfile)" ];then
  re3="O"
 else
  re3="-"
 fi
 blockdev_st=$(sed -n "$(($(grep -n "blockdev:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":blockdev" $sfile | cut -d':' -f1)-1))p" $sfile)
 blockdev_c=$(echo "$blockdev_st" | wc -l)
 blockdev_re=1
 for (( c=1;c<=$blockdev_c;c++ ))
 do
  if [ $(echo "$blockdev_st" | awk "NR==$c") -ne 16384 ];then
   blockdev_re=$((blockdev_re*2))
  fi
 done
 if [ $blockdev_re -eq 1 ];then
  re4="O"
 else
  re4="-"
 fi
 hn=$(printf '%-15s' "$var")
 printf "%s%-12s%-12s%-12s%-12s\n" "$hn" "$re1" "$re2" "$re3" "$re4"
done
}

function page5(){
msg_show " === OS Configuration === "
echo ""
mlist=(fstab df)
for menu in "${mlist[@]}"
do
 printf "%-15s" ""
 printf "%-12s" "--- $menu ---"
 printf "\n"
 for var in $(cat $cs_host_path)
 do
  sfile=""
  sfile=$(ls /tmp/check_status_* | grep -w "/tmp/check_status_$(cat /etc/hosts | grep -v "###" | grep -w "$var" | awk '{print$2}')")
  if [ "$menu" == "df" ];then
   result=$(sed -n "$(($(grep -n "df:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":df" $sfile | cut -d':' -f1)-1))p" $sfile | grep "/data")
  fi
  if [ "$menu" == "fstab" ];then
   result=$(sed -n "$(($(grep -n "fstab:" $sfile | cut -d':' -f1)+1)),$(($(grep -n ":fstab" $sfile | cut -d':' -f1)-1))p" $sfile | grep -v "#")
  fi
  result_c=$(echo "$result" | wc -l)
  if [ $result_c -gt 1 ];then
   for (( c=1;c<=$result_c;c++ ))
   do
    result_tt=$(echo "$result" | awk "NR==$c")
    hn=$(printf '%-15s' "$var")
    printf "%s%s\n" "$hn" "$result_tt"
   done
  else
   hn=$(printf '%-15s' "$var")
   printf "%s%s\n" "$hn" "$result"
  fi
 done
done
}

function page6(){
msg_show " === GPDB Configuration === "
echo ""
if [ "$gpdb_err" == "-1" ];then
 echo "- GPDB Base Info -"
 echo -n "GPDB Version                    : "
 echo "$gpdb_st" | grep "(Greenplum Database)" | awk '{print$8}'
 echo -n "GPDB Master Status        : "
 echo  "$gpdb_st" | grep "Master instance" | awk '{print$6}'
 echo -n "GPDB Master standby      : "
 echo  "$gpdb_st" | grep "Master standby" | awk '{print$6}'
 echo -n "GPDB Total instance         : "
 echo -n "$(echo -n "$gpdb_st" | grep "Total segment instance count from metadata" | awk -F'=' '{print$2}' | awk '{print$1}') "
 echo -n "(Primary: $(echo -n "$gpdb_st" | grep "Total primary segment valid" | awk -F'=' '{print$2}' | awk '{print$1}')/"
 echo -n "$(echo -n "$gpdb_st" | grep "Total primary segment failures" | awk -F'=' '{print$2}' | awk '{print$1}') , "
 echo -n "Mirror: $(echo  "$gpdb_st" | grep "Total mirror segment valid" | awk -F'=' '{print$2}' | awk '{print$1}')/"
 echo "$(echo "$gpdb_st" | grep "Total mirror segment failures" | awk -F'=' '{print$2}' | awk '{print$1}'))"
 echo ""
 echo "- GPDB failover config -"
 echo "Master Standby Service : $gpfo_st"
 if [ $(echo "$gpdb_st" | grep -i active | wc -l) -eq 1 ];then
  check_vip
  echo " > VIP-IP        : $vip_ip"
  echo " > VIP-NETMASK   : $vip_net"
  echo " > VIP-GATEWAY   : $vip_gate"
  echo " > VIP-SOURCE    : $vip_ori"
  echo " > VIP-TARGET    : $vip_int"
 fi
 echo ""
 echo "- GPDB gpconfig parameter -"
 echo "$gpconf_st1" | awk 'NR!=1'
 echo "$gpconf_st2" | awk 'NR!=1'
 echo "$gpconf_st3" | awk 'NR!=1'
 echo "$gpconf_st4" | awk 'NR!=1'
 echo "$gpconf_st5" | awk 'NR!=1'
 echo "$gpconf_st6" | awk 'NR!=1'
 echo "$gpconf_st7" | awk 'NR!=1'
 echo ""
 echo "- GPDB Package -"
 echo "$gppkg_st" | awk 'NR!=1'
 echo ""
else
 echo "$gpdb_err"
fi
if [ "$gpcc_err" == "-1" ];then
 echo "- GPCC Version -"
 echo "$gpcc_ver"
 echo ""
 echo "- GPCC Status - "
 echo "$gpcc _st"
 echo ""
else
 echo "$gpcc_err"
fi
if [ "$pxf_err" == "-1" ];then
 echo "- PXF Status -"
 echo "$pxf_st"
else
 echo "$pxf_err"
fi
}

function page_top(){
clear
echo ""
line -
msg_show " < Check OS/GPDB Status > "
}

function page_bot(){
echo ""
msg_line " [Page $ct/$tt] " "-"
}

function check_ct(){
if [ $1 -gt $tt ];then
 ct=1
elif [ $1 -eq 0 ];then
 ct=$tt
fi
}

function run_page(){
page_top
page$1
page_bot
}

function line(){
 for (( i=1;i<$(tput cols);i++ ))
 do
  echo -n "$1"
 done
 echo ""
}

function msg_line(){
EL=$(tput cols)
MSG="$1"
sline=""
eline=""
let SP=$EL/2-${#MSG}/2
let MP=$SP+${#MSG}
for (( i=1;i<$SP;i++ ))
do
 sline="${sline}$(echo -n "$2")"
done
for (( j=$MP;j<$EL;j++ ))
do
 eline="${eline}$(echo -n "$2")"
done
printf "%s%${#MSG}s%s\n" "$sline" "$1" "$eline"
}

function msg_show(){
MSG="$1"
let COL=$(tput cols)/2-${#MSG}/2
printf "%${COL}s$s\n" "" "$1"
}

function get_info(){
for i in $(cat $cs_host_path)
do
 sshpass -p $passwd scp -r ./collect_st.sh root@$i:/tmp/collect_st.sh
 ssh $i 'sh /tmp/collect_st.sh' > /tmp/check_st_$i
done
}

ct=1
tt=6
mq=""
rgc=report_gpdb_check-$(hostname)
get_gpdb_conf
get_info
#date >> ${LOG_FILE}.${LOG_TIME}
while [ "$mq" != "x" ]
 do
 run_page $ct
 echo -n -e " > Next<\033[1;32;49mN\033[0m> / Back<\033[1;34;49mB\033[0m> / Report<\033[1;33;49mN\033[0m> / Exit<\033[1;31;49mN\033[0m> "
 read -s -n1 mq
 case $mq in
 N|n)
 ct=$((ct+1))
 check_ct $ct
 ;;
 B|b)
 ct=$((ct-1))
 check_ct $ct
 ;;
 R|r)
 clear
 cat /dev/null > $rgc
 msg_show " < Report - OS/GPDB Status> " >> $rgc
 echo "Create Time: $LOG_TIME" >> $rgc
 for (( l=1;l<$(tput cols);l++ ))
 do
  echo -n "-" >> $rgc
 done
 echo "" >> $rgc
 for (( i=1;i<=$tt;i++ ))
 do
  page$i >> $rgc
 for (( j=1;j<$(tput cols);j++ ))
 do
  echo -n "-" >> $rgc
 done
 done
 echo "" >> $rgc
 more $rgc
 read -s -n1 qq
 ;;
 X|x)
 mq="x"
 ;;
 esac
echo ""
done
