#! /bin/bash

# Make sure the tmsp cli can connect to the dummy
echo "Dummy test ..."
dummy &> /dev/null &
PID=`echo $!`
sleep 1
RESULT_HASH=`tmsp get_hash`
if [[ "$RESULT_HASH" != "" ]]; then
	echo "Expected nothing but got: $RESULT_HASH"
	exit 1
fi
echo "... Pass!"
echo ""

# Add a tx, get hash, commit, get hash
# hashes should be non-empty and identical
echo "Dummy batch test ..."
OUTPUT=`(tmsp batch) <<STDIN 
append_tx abc
get_hash
commit
get_hash
STDIN`

HASH1=`echo "$OUTPUT" | tail -n 3 | head -n 1`
HASH2=`echo "$OUTPUT" | tail -n 1`

if [[ "$HASH1" == "" ]]; then
	echo "Expected non empty hash!"
	exit 1
fi

if [[ "$HASH1" != "$HASH2" ]]; then
	echo "Expected hashes before and after commit to match: $HASH1, $HASH2"
	exit 1
fi
echo "... Pass!"
echo ""

# Start a new connection and ensure the hash is the same
echo "New connection test ..."
RESULT_HASH=`tmsp get_hash`
if [[ "$HASH1" != "$RESULT_HASH" ]]; then
	echo "Expected hash to persist as $HASH1 for new connection. Got $RESULT_HASH"
	exit 1
fi
echo "... Pass!"
echo ""


kill $PID
sleep 1
