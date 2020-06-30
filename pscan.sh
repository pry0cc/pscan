#!/bin/bash

name="example-scan"
scope="ranges.txt"
# Start fleet using the supplied name, spend $0.1 and self-destruct after 1 hour
axiom-fleet $name -i=5 --spend=0.1 --time=1

# Upload the scope to every single host... If this is really big, do some magic with split.
for i in $(axiom-ls -d | grep -E "$name*"); do axiom-scp $scope $i:~/ranges.txt .; done

# Execute this one liner on every machine, basically scan its portion
axiom-execb 'sudo masscan -iL ranges.txt --rate=10000 -p443 --shard $i/$total -oG $name.txt' "$name*" 


# Wait until the scan has finished, then press enter to tear down!
echo "Press enter to tear down"
read

# Download all the output masscan files
for i in $(axiom-ls -d | grep -E "$name*"); do axiom-scp $i:~/$i.txt .; done

# Sort and merge the massscan files into a single sorted file
cat $name* | sort -u > tmp && rm -rf $name* && mv tmp $name.txt

# Shut down all instances that match $name
echo "Shutting down instances..."
axiom-rm "$name*" -f
