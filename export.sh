#!/bin/bash
cd root
zip -FSr ../exports/game.love *
cd ..

love.js -t "pgma1" -c exports/game.love exports/lovejs