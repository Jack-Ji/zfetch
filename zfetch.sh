#!/bin/bash

set -e

forceupdate=false
if [ "$1" = "-f" ]; then
    forceupdate=true
    shift
fi

keepfiles=false
if [ "$1" = "-k" ]; then
    keepfiles=true
    shift
fi

cachedir=`zig env | grep global_cache_dir | awk -F \" '{print $(NF-1)}'`

do_fetch() {
    for d in `grep -o '^[[:space:]]*.url *=.*' $1 | awk -F \" '{print $2}'`; do
        d=`echo $d | grep -o 'https://[^"]*' | sed 's/\?.*#/#/'`
        echo -e "\n>>> Deal with $d"
        if echo $d | grep -q '\.tar\.gz\|\.zip$'; then
            url=$d
        elif echo $d | grep -q '#[.0-9a-z]*$'; then
            url_base=`echo $d | awk -F \# '{print $1}'`
            url_base=${url_base%.git}
            url_commit=`echo $d | awk -F \# '{print $2}'`
            url="${url_base}/archive/${url_commit}.tar.gz"
        else
            echo ">>> Ignored $d, unable to resolve it!"
            continue
        fi
        hash=`grep -m 1 -A 1 "$d" $1 | grep hash |  awk -F \" '{print $(NF-1)}'`
        if [ -z "$hash" ]; then
          forceupdate=true
        fi
        if ! $forceupdate && [ -e $cachedir/p/$hash ]; then
          echo ">>> Found in cache, ignored"
          continue
        fi
        tarfile=${url##*/}
        if ! wget -c --show-progress --quiet $url -O $tarfile; then
            echo ">>> Failed!"
            exit -1
        fi
        hash=`zig fetch --debug-hash $tarfile | tail -n 1`
        echo ">>> Installed, hash: $hash"
        if ! $keepfiles; then
            rm $tarfile
        fi
        if [ -e $cachedir/p/$hash/build.zig.zon ]; then
            do_fetch $cachedir/p/$hash/build.zig.zon
        fi
    done

    for d in `grep -o 'path *=.*' $1 | cut -d = -f 2`; do
        path=`echo $d | awk -F \" '{print $(NF-1)}'`
        if [ -e $path/build.zig.zon ]; then
            do_fetch $path/build.zig.zon
        fi
    done
}

zonfile=$1
if [ -z "$zonfile" ]; then
    zonfile=build.zig.zon
fi

if ! [ -e $zonfile ]; then
    echo "can't find build.zig.zon!"
    exit 1
fi

do_fetch $zonfile
