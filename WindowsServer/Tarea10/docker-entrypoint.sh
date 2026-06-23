#!/bin/bash
crond -b
exec docker-entrypoint.sh "$@"