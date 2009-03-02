#!/bin/bash

cd `dirname $0`

echo Starting exrefcheck
erl $* \
	-sname exrefcheck \
	-pa ./ebin \
	-s exrefcheck 
        
