#!/bin/bash
cd root
zip -FSr ../exports/game.love res `find . -iname '*.lua' -not -path './res/*'`
cd ..

love.js -t "pgma1" -c exports/game.love exports/lovejs