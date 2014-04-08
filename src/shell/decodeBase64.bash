sed -i 's/\\n//g' $1
base64 -d $1 >> $2
