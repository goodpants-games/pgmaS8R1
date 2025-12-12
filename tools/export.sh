#!/bin/bash
cd root
zip -FSr ../exports/game.love res `find . -iname '*.lua' -not -path './res/*'`
cd ..

love.js -t "pgma1" -c exports/game.love exports/lovejs
cp -f tools/lovejs_index.html exports/lovejs/index.html
cp -f tools/loading.png exports/lovejs/loading.png