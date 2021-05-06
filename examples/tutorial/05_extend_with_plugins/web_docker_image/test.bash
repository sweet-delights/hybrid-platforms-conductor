#!/bin/bash

for ((i=1;i<=10;i++));
do 
   echo "Container web$i: $(curl http://web$i.hpc_tutorial.org 2>/dev/null)"
done
