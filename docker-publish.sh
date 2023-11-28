#!/usr/bin/env bash

calculate_version() {
  major=$(date +'%Y%m%d')
  minor=$(date +%s%N | cut -b1-13)
  echo $major.$minor
}


source_configuration() {
  if [ -f "$1" ]; then
    source "$1" 
  else
    echo "Couldn't find the $1 configuration file."
    exit 1
  fi
}

configure() {
  package=$pkgname
  version=$pkgver
}

docker_build() {
  docker build -t $registry/$author/$package:latest -t $registry/$author/$package:$version . || exit 1
}

docker_push() {
  docker push $registry/$author/$package --all-tags || exit 1
}

version_dump() {
  echo Preforming devops operations for $author/$package:$version...
}

git_clone() {
    if [ ! -d "$package" ]; then
        git clone "$repository" "$package" || exit 1
    fi
    cd "$package" || exit 1
    git pull || exit 1
}

preform_actions() {
  for i in "${actions[@]}"
  do
    $i || exit 1
  done
}

cd "$1"

source_configuration "$HOME/.config/docker-publish.conf" 
source_configuration "PKGBUILD"
preform_actions