#!/bin/bash

# See also https://www.rocker-project.org/use/singularity/
function gen_passwd ()
{
    local l=$1;
    [ "$l" == "" ] && l=12;
    gtr -dc A-Za-z0-9_ < /dev/urandom | head -c ${l} | xargs
}

function get_free_port ()
{
    for p in $1; do
	if ! nc -z localhost "$p"; then
	    echo $p
	    return 0
	fi
    done
    return 1
}

# Main parameters for the script with default values
PORT_RANGE=$(echo {63000..63100})
PORT=$(get_free_port $PORT_RANGE)
USER=$(whoami)
PASSWORD=$(gen_passwd)
TMPDIR=${TMPDIR:-tmp}
CONTAINER="rstudio_latest.sif"  # path to singularity container (will be automatically downloaded)
DATA_DIR=$HOME/data

[[ ! -z $PORT ]] || (echo "Unable to find free port"; exit 1)

# Set-up temporary paths
RSTUDIO_TMP="${TMPDIR}/$(echo -n $CONDA_PREFIX | md5sum | awk '{print $1}')"
mkdir -p $RSTUDIO_TMP/{run,var-lib-rstudio-server,local-share-rstudio}

R_BIN=$CONDA_PREFIX/bin/R
PY_BIN=$CONDA_PREFIX/bin/python

if [ ! -f $CONTAINER ]; then
	singularity build --fakeroot $CONTAINER Singularity
fi

if [ -z "$CONDA_PREFIX" ]; then
  echo "Activate a conda env or specify \$CONDA_PREFIX"
  exit 1
fi

[ -d "$DATA_DIR" ] || mkdir $DATA_DIR
[ -d "$HOME/.config/rstudio" ] || mkdir -p $HOME/.config/rstudio

echo "Starting rstudio service on port for user $USER with password $PASSWORD. Visit https://$(hostname -f):$PORT"
singularity exec \
	--bind $RSTUDIO_TMP/run:/run \
	--bind $RSTUDIO_TMP/var-lib-rstudio-server:/var/lib/rstudio-server \
	--bind /sys/fs/cgroup/:/sys/fs/cgroup/:ro \
	--bind database.conf:/etc/rstudio/database.conf \
	--bind rsession.conf:/etc/rstudio/rsession.conf \
	--bind $RSTUDIO_TMP/local-share-rstudio:/home/rstudio/.local/share/rstudio \
	--bind ${CONDA_PREFIX}:${CONDA_PREFIX} \
	--bind $HOME/.config/rstudio:/home/rstudio/.config/rstudio \
        `# add additional bind mount required for your use-case` \
	--bind /store:/store \
	--bind /tools:/tools \
	--bind $DATA_DIR:/data \
	--env CONDA_PREFIX=$CONDA_PREFIX \
	--env RSTUDIO_WHICH_R=$R_BIN \
	--env RETICULATE_PYTHON=$PY_BIN \
	--env PASSWORD=$PASSWORD \
	--env PORT=$PORT \
	--env USER=$USER \
	rstudio_latest.sif \
	/init.sh

