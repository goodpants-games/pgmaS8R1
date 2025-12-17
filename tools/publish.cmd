@echo off
cd exports
butler push lovejs pumkinhead/system-shutdown-imminent:html5
butler push win-x64 pumkinhead/system-shutdown-imminent:win-x64
butler push SystemShutdownImminent.love pumkinhead/system-shutdown-imminent:love
cd ..