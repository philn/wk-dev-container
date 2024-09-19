
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
FORCE="0"
TYPE="Release"
#TYPE="RelWithDebInfo"
PORT="GTK"

while getopts "ft:p:" opt; do
    case "$opt" in
        f)
            FORCE="1"
            ;;
        t)  TYPE=$OPTARG
            ;;
        p)  PORT=$OPTARG
            ;;
    esac
done

PORT_LOWER="${PORT,,}"
TYPE_LOWER="${TYPE,,}"

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

EXTRA_ARGS=""
if [ "$PORT_LOWER" == "wpe" ]
then
    EXTRA_ARGS="--set-permissions=all --cookie-jar=text:cog.cookies --webprocess-failure=exit-ok"
fi

if [ "$PORT_LOWER" == "gtk" ]
then
    EXTRA_ARGS="--autoplay-policy=allow --cookies-file=mb.cookies"
fi

export WEBKIT_OUTPUTDIR=$WEBKIT_HOME/local-build-$PORT_LOWER/WebKitBuild

export ARGS="--$PORT_LOWER --$TYPE_LOWER"
export EXTRA_MB_ARGS=$EXTRA_ARGS
