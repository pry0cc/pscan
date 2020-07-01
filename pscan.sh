#!/bin/bash


## pscan ranges.txt myproject
name="$2"
global_name=$name
scope="$1"
total=10
# Start fleet using the supplied name, spend $0.1 and self-destruct after 1 hour
echo '
              _                       ______          __
  ____ __  __(_)___  ____ ___        / __/ /__  ___  / /_
 / __ `/ |/_/ / __ \/ __ `__ \______/ /_/ / _ \/ _ \/ __/
/ /_/ />  </ / /_/ / / / / / /_____/ __/ /  __/  __/ /_
\__,_/_/|_/_/\____/_/ /_/ /_/     /_/ /_/\___/\___/\__/

	axiom-fleet, written by @pry0cc
'
axiom-fleet $name -i=$total --spend=0.2 --time=1

# Split the files up by how many instances we have, and then name them appropriately.
lines=$(wc -l $scope | awk '{ print $1 }')
lines_per_file=$(bc <<< "scale=2; $lines / $total" | awk '{print int($1+0.5)}')
split -l $lines_per_file $scope
a=1

mkdir -p .tmp/
for f in $(bash -c "ls | grep -v '$scope' | grep x")
do 
    mv $f .tmp/$a.txt
    a=$((a+1))
done

echo "Waiting 20 seconds for hosts to come up..."
sleep 20

# Push the per-host split files to each host
a=1
for name in $(axiom-ls -d | grep -E "$name*")
do
	echo "Uploading ranges to $name"
    axiom-scp .tmp/$a.txt $name:~/ranges.txt
    a=$((a+1))
done

rm -rf .tmp

# Execute this one liner on every machine, basically scan its portion
axiom-execb 'sudo masscan -iL ranges.txt --rate=100000 -p443 --shard $i/$total -oG $name.masscan && sudo chown op:users $name.masscan && cat $name.masscan | awk "{ print \$2 }" | sort -u > $name.txt' "$name*" 

# Wait until the scan has finished, then press enter to tear down!
instances=$(axiom-ls -d | grep -E "$name*")
total=$(echo $instances | tr " " "\n" | wc -l | awk '{ print $1 }')
echo "TOTAL FIRST INSTANCES: $total $(echo $instances | tr '\n' ', ')"
sleep 1
while [[ "$(axiom-ls -d | grep -E "$name*" | tr ' ' '\n' | wc -l | awk '{ print $1 }')" -gt 0 ]]
do
	sleep 1
	instances=$(axiom-ls -d | grep -E "$name*")
	total=$(echo $instances | tr ' ' '\n' | wc -l | awk '{ print $1 }')
	echo "TOTAL INSTANCES: $total $(echo $instances | tr '\n' ', ')"
	for instance in $instances
	do
		echo "Checking $instance..."
		count=$(timeout 5 axiom-exec "ps aux | grep '[m]asscan' | wc -l | awk '{ print \$1 }'" "$instance" -q)

		if [[ "$count" -lt 1 ]]
		then
			echo "Killing $instance"
			axiom-scp $instance:~/$instance.txt $instance.txt
			cat $instance.txt >> all.txt
			rm -f $instance.txt
			axiom-rm $instance -f
			sleep 2
		fi
	done
done

# Download all the output masscan files
#for i in $(axiom-ls -d | grep -E "$global_name*"); do axiom-scp $i:~/$i.txt $i.txt; cat $i.txt >> all.txt; rm -f ./$i.txt; done

cat all.txt | grep -v "#" | sort -u > $global_name.txt
rm -f all.txt

