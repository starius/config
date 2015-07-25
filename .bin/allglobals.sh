(for f in $@; do luac -l -p $f; done) | egrep ETGLOBAL
