complete --command service --no-files -x -d 'Synit service' -a '(service -arguments)'
complete --command service -d 'query status' -o status
complete --command service -d 'restart service' -o restart
complete --command service -d 'run service now' -o run
complete --command service -d 'stop and block service' -o block
