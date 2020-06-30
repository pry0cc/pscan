#!/bin/bash

name="example"
global_name=$name
scope="ranges.txt"
total=4
# Start fleet using the supplied name, spend $0.1 and self-destruct after 1 hour
#axiom-fleet $name -i=$total --spend=0.1 --time=1

# Split the files up by how many instances we have, and then name them appropriately.
lines=$(wc -l $scope | awk '{ print $1 }')
echo $lines
lines_per_file=$(bc <<< "scale=2; $lines / $total" | awk '{print int($1+0.5)}')
split -l $lines_per_file $scope
a=1
for f in $(bash -c "ls | grep x")
do 
    mv $f $a.txt
    a=$((a+1))
done

# Push the per-host split files to each host
a=1
for name in $(axiom-ls -d | grep -E "$name*")
do
    axiom-scp $a.txt $name:~/ranges.txt
    rm -f $a.txt
    a=$((a+1))
done

# Execute this one liner on every machine, basically scan its portion
axiom-execb 'sudo masscan -iL ranges.txt --rate=100000 -p443 --shard $i/$total -oG $name.txt' "$name*" 

# Wait until the scan has finished, then press enter to tear down!
echo "Press enter to tear down (when finished)"
read

# Download all the output masscan files
for i in $(axiom-ls -d | grep -E "$global_name*"); do axiom-scp $i:~/$i.txt $i.txt; cat $i.txt >> all.txt; rm -f ./$i.txt; done

cat all.txt | sort -u > $global_name.txt
rm -f all.txt

# Shut down all instances that match $name
echo "Shutting down instances..."
axiom-rm "$global_name*" -f
