# docker-publish.sh

> A simple yet powerful CLI tool for publishing docker images and other devops actions.

## Installation

- Copy `docker-publish.sh` from this repository into your project.
- Make `docker-publish.sh` executable:

```sh
chmod +x docker-publish.sh
```

- Create the global configuration file in `~/.config/docker-publish.conf`:

```sh
registry="registry.example.com" # the docker registry
author="example" # the username for the registry
actions=(configure version_dump) # default actions to run

# ...
# you can add other configuration options here for any extensions you make

```

## Usage

```sh
./docker-publish [directory]
```

- Working directory is changed to `[directory]`
- `~/.config/docker-publish.conf` will get loaded.
- `PKGBUILD` will get loaded.
- The functions in the `actions` variable will get called.

## What are `PKGBUILD` files and how to make them?

`PKGBUILD` files are shell scripts that define how a docker image should get built, this format was taken and slightly modified from [Arch Linux](https://wiki.archlinux.org/title/PKGBUILD).

The difference from Arch Linux `PKGBUILD` files is that our format doesn't have default behavior for variables or functions, we just call the functions are in the `actions` variable (which isn't used in the Arch Linux format).

Our format can be fully compatible with Arch Linux `PKGBUILD` files if the `actions` array contains do the same thing that `makepkg` does.

A `PKGBUILD` file in our format would look like this:

```bash
pkgname="my-app"
pkgver="1.0"
repository="git@github.com:example/my-app.git"
actions+=(prepare git_clone docker_build docker_push)

prepare() {
    cd ../build
}
```

This file has the actions:

- `prepare` - user defined action, which will change the working directory to `../build`
- `git_cone` - built-in action, which will clone the git repository
- `docker_build` - built-in action, which will build and tag a docker container
- `docker_push` - built-in action, which will push the built image to a registry

This example file is a good template for projects that use git.

## Built-in Actions

### `configure`

Define `$version` and `$package` based on `$pkgver` and `$pkgname`.

> [!NOTE]
> This action should be a part of the global configuration in `~/.config/docker-publish.conf` for users who prefer Arch Linux-like syntax.

### `docker_build`

Build a image using the Dockerfile in the working directory and tag it as:

- `$registry/$author/$package:$version`
- `$registry/$author/$package:latest`

### `docker_push`

Push all tags to the docker registry for the image: `$registry/$author/$package`.

### `version_dump`

Print a message containing the package name (`$package`), author (`$author`) and version (`$version`).

### `git_clone`

If a directory called `$package` exists:

- Change the working directory to `$package`
- Preform a pull

Else:

- Clone `$repository` into `$package` directory
- Change the working directory to `$package`

## Built-in Functions

### `calculate_version`

Outputs a unique version based on the current date and time.

Usage:

```bash
pkgver=$(calculate_version)
```

### `source_configuration`

Loads a configuration file or exits if the file doesn't exist.

Usage:

```bash
some_action() {
    source_configuration "test.conf"
}
```

## Usage with GitHub Actions

Some setup must be done before you have the ability to call `docker-image.sh` inside of GitHub Actions.

- For the `git_clone` action using private repos SSH/token authentication is required.
- For the `docker_push` action authentication for the docker registry is required.

This is how an action would look like using all the previously mentioned features with `workflow_dispatch` and two image options: `example-1`, `example-2`.

```yml
name: Publish a docker container

on:
  workflow_dispatch:
    inputs:
      image:
        type: choice
        required: true
        options:
          - example-1
          - example-2
        description: "Image"
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Login to GitHub using SSH Key
        uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Configure Git
        run: |
          git config user.name "GitHub Actions Bot"
          git config user.email "<>"

      - name: Login to Docker Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ secrets.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Configure Docker Publish
        run: |
          mkdir build
          mkdir -p $HOME/.config
          echo registry=${{ secrets.REGISTRY }} > $HOME/.config/docker-publish.conf
          echo author=${{ secrets.AUTHOR }}>> $HOME/.config/docker-publish.conf
          echo actions=\(configure version_dump\)>> $HOME/.config/docker-publish.conf

      - name: Run Docker Publish
        run: |
          ./docker-publish.sh ${{github.event.inputs.image}}
```

For this GitHub action to work without any modification, the following requirements must be met:

- `/example-1/PKGBUILD` and `/example-2/PKGBUILD` should exist
- The `REGISTRY` secret should be defined as a valid docker registry
- The `REGISTRY_USERNAME` secret should be defined as a valid username for the registry
- The `REGISTRY_PASSWORD` secret should be defined as a valid password for the user in the registry
- The `AUTHOR` secret should probably be equal to the `REGISTRY_USERNAME` secret unless using a private registry
- The `SSH_PRIVATE_KEY` secret should be a valid SSH private key that enables access to all the required git repositories that are getting cloned (if not required, remove the step that uses this secret, and the "Configure Git" step).
