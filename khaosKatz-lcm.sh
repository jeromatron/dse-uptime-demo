#!/bin/bash

lcm=127.0.0.1
lcmport=8888
clustername=Demo
localdc=dc1
username=ubuntu
keyfile=./priv.key

nodes=(`curl -s http://${lcm}:${lcmport}/${clustername}/nodes | jq -rc ".[].node_ip" | paste -s`)
dcs=(`curl -s http://${lcm}:${lcmport}/${clustername}/nodes | jq -rc ".[].dc" | paste -s`)
dccount=`echo ${dcs[@]} | sed 's/ /\n/g' | sort | uniq | wc -l`
localnodes=()
localnodecount=0
remotenodes=()
remotenodecount=0
nodecount=0

for i in ${nodes[@]}; do
 echo $i is in ${dcs[$nodecount]}
 if [ "${dcs[$nodecount]}" = "$localdc" ]; then
  localnodes[$localnodecount]=$i
  localnodecount=$(( $localnodecount + 1 ))
 else
  remotenodes[$remotenodecount]=$i
  remotenodecount=$(( $remotenodecount + 1 ))
 fi
 
 nodecount=$(( $nodecount + 1 ))
done
echo total nodes: ${nodecount}
echo local nodes: ${localnodecount}
echo remote nodes: ${remotenodecount}
echo dc count: ${dccount}
sleep 5

kill_node () {
 ssh -oStrictHostKeyChecking=no -i $keyfile $2@$1 "sudo pkill -9 -f dse.jar" > /dev/null
}

recover_node () {
 ssh -oStrictHostKeyChecking=no -i $keyfile $2@$1 "sudo service dse stop" > /dev/null
 sleep 3
 ssh -oStrictHostKeyChecking=no -i $keyfile $2@$1 "sudo service dse start" > /dev/null
 #curl -X POST http://$lcm:$lcmport/$clustername/ops/start/$1
}

while [ 1 ]; do

clear
echo "Randomly selecting scenario.."
sleep 1
#seed=$((1 + RANDOM % 7))
seed=5
#echo $seed

if [ $seed = 1 ]; then
 #kill local node
 echo "Scenario: Single local node failure"
 sleep 1
 echo -n "  Step: Selecting node to crash.. "
 r=$((1 + RANDOM % $localnodecount ))
 r=$(( $r - 1 )) 
 crash=${localnodes[$r]}
 sleep 1
 echo $crash
 sleep 1
 echo "  Step: Kill -9 on $crash"
 kill_node $crash $username
 echo "  Step: Resting.."
 sleep 45
 echo "  Step: Restarting $crash"
 recover_node $crash $username
fi

if [ $seed = 2 ]; then
 #kill two local nodes
 echo "Scenario: Dual local node failure"
 sleep 1
 echo "  Step: Selecting nodes to crash.."
 r=$((1 + RANDOM % $localnodecount ))
 r=$(( $r - 1 )) 
 r2=${r}
 x=0
 while [ $x -eq 0 ]; do
  r2=$((1 + RANDOM % $localnodecount ))
  r2=$(( $r2 - 1 )) 
  if [ $r2 -ne $r ]; then
   x=1
  fi
 done
 crash1=${localnodes[$r]}
 crash2=${localnodes[$r2]}
 sleep 1
 echo "        $crash1"
 sleep 1
 echo "        $crash2"
 sleep 1
 echo "  Step: Sending Kill -9 to nodes"
 sleep 1
 echo "        $crash1"
 kill_node $crash1 $username
 sleep 1
 echo "        $crash2"
 kill_node $crash2 $username
 echo "  Step: Resting.."
 sleep 45
 echo "  Step: Restarting nodes"
 sleep 1
 echo "        $crash1"
 recover_node $crash1 $username
 sleep 1
 echo "        $crash2"
 recover_node $crash2 $username
fi

if [ $seed = 3 ]; then
 #kill local node
 echo "Scenario: Total local DC failure!"
 sleep 1
 echo "  Step: Sending Kill -9 to local nodes"
 for n in ${localnodes[@]}; do
  echo "        $n"
  kill_node $n $username
 done
 echo "  Step: Resting.."
 sleep 45
 echo "  Step: Restarting local nodes"
 for n in ${localnodes[@]}; do
  echo "        $n"
  recover_node $n $username
 done
fi

if [ $seed = 4 ]; then
 echo "Scenario: Dual remote node failure"
 sleep 1
 echo "  Step: Selecting nodes to crash.."
 r=$((1 + RANDOM % $remotenodecount ))
 r=$(( $r - 1 )) 
 r2=${r}
 x=0
 while [ $x -eq 0 ]; do
  r2=$((1 + RANDOM % $remotenodecount ))
  r2=$(( $r2 - 1 )) 
  if [ $r2 -ne $r ]; then
   x=1
  fi
 done
 crash1=${remotenodes[$r]}
 crash2=${remotenodes[$r2]}
 sleep 1
 echo "        $crash1"
 sleep 1
 echo "        $crash2"
 sleep 1
 echo "  Step: Sending Kill -9 to nodes"
 sleep 1
 echo "        $crash1"
 kill_node $crash1 $username
 sleep 1
 echo "        $crash2"
 kill_node $crash2 $username
 echo "  Step: Resting.."
 sleep 45
 echo "  Step: Restarting nodes"
 sleep 1
 echo "        $crash1"
 recover_node $crash1 $username
 sleep 1
 echo "        $crash2"
 recover_node $crash2 $username
fi

if [ $seed = 5 ]; then
 #kill local node
 echo "Scenario: Total local DC failure!"
 echo "Bonus: During remote DC maintenance!"
 sleep 1
 echo -n "  Step: Selecting remote node.. "
 r=$((1 + RANDOM % $remotenodecount ))
 r=$(( $r - 1 ))
 crash=${remotenodes[$r]}
 sleep 1
 echo $crash
 sleep 1
 echo "  Step: Stopping $crash for maintenance"
 kill_node $crash $username
 echo "  Step: Resting.."
 sleep 45
 echo "  Step: Sending Kill -9 to local nodes"
 for n in ${localnodes[@]}; do
  echo "        $n"
  kill_node $n $username
 done
 echo "  Step: Resting.."
 sleep 45
 echo "  Step: Restart remote node $crash"
 sleep 1
 recover_node $crash $username
 echo "  Step: Restarting local nodes"
 for n in ${localnodes[@]}; do
  echo "        $n"
  recover_node $n $username
 done
fi






#End of Scenarios
echo "  Step: Recovering for next scenario"
sleep 60
status=`curl -s http://127.0.0.1:8888/$clustername/nodes | jq -r ".[]".mode  | grep -v normal > /dev/null | echo $?`
if [ $status -eq 1 ]; then
 echo "  =^_^= khaosKatz is pleased."
else 
 echo "  =^_^= khaosKatz senses nodes still down!"
fi
sleep 3

done
