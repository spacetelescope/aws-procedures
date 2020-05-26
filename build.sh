#!/usr/bin/env bash

set -e
# set -x
if [ "$1" == "docs" ]; then
    if [ ! -d "env-docs" ]; then
        virtualenv -p $(which python3) env-docs
        source env-docs/bin/activate
        pip install sphinx sphinx_rtd_theme -U
    else
        source env-docs/bin/activate
    fi
    mkdir -p /tmp/docs
    sphinx-build -b html docs/ /tmp/docs/
fi
