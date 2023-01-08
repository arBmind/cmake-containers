# Docker images for CMake

This project generate a set of Docker images around the CMake build system used for CI runs and development setups.

| Image (latest versions) | Size |
| -- | -- |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/cmake-clang?color=black&label=arbmind%2Fcmake-clang&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/cmake-clang?color=green&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/cmake-clang-libstdcpp?color=black&label=arbmind%2Fcmake-clang-libstdcpp&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang-libstdcpp) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/cmake-clang-libstdcpp?color=green&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang-libstdcpp) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/cmake-clang-libstdcpp-qt?color=black&label=arbmind%2Fcmake-clang-libstdcpp-qt&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang-libstdcpp-qt) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/cmake-clang-libstdcpp-qt?color=yellow&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang-libstdcpp-qt) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/cmake-clang-libstdcpp-qtgui-dev?color=black&label=arbmind%2Fcmake-clang-libstdcpp-qtgui-dev&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang-libstdcpp-qtgui-dev) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/cmake-clang-libstdcpp-qtgui-dev?color=red&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/cmake-clang-libstdcpp-qtgui-dev) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/cmake-gcc?color=black&label=arbmind%2Fcmake-gcc&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/cmake-gcc) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/cmake-gcc?color=yellow&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/cmake-gcc) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/cmake-gcc-qt?color=black&label=arbmind%2Fcmake-gcc-qt&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/cmake-gcc-qt) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/cmake-gcc-qt?color=brown&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/cmake-gcc-qt) |
| [![Docker Image Version (latest semver)](https://img.shields.io/docker/v/arbmind/cmake-gcc-qtgui-dev?color=black&label=arbmind%2Fcmake-gcc-qtgui-dev&logo=Docker&sort=semver)](https://hub.docker.com/r/arbmind/cmake-gcc-qtgui-dev) | [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/arbmind/cmake-gcc-qtgui-dev?color=brown&logo=Ubuntu&sort=semver)](https://hub.docker.com/r/arbmind/cmake-gcc-qtgui-dev) |

### Versions

The compiler and Qt versions, modules and packages are provided as build-args.

See links to Dockerhub for older versions listed in tags.
See [`.github/workflows/docker_build.yml`](https://github.com/arBmind/cmake-containers/blob/develop/.github/workflows/docker_build.yml) for the current bulid matrix.


## Basic Usage

The default entry point is the bash shell.
For your CI you should write a simple bash script that runs the build, as cmake requires multiple invocations.

```bash
docker run -it \
    --mount src="$(pwd)",target=/project,type=bind
    -w /project \
    arbmind/cmake-clang-libstdcpp:latest \
    script/cmake_build.sh
```

This mounts your current directory to `/project` and a build volume in the container. Changes the workdir to `/project`.

In the image bash you can do the canonical cmake stuff.

```bash
mkdir build
cd build
cmake ..
cmake --build
```

If you want to see how this works, take a look at these repositories:
* https://github.com/basicpp17/co-cpp19


## Development Setup

The development setup was tested with [CLion](https://www.jetbrains.com/clion/) bud can be used with any custom setup.

For CLion simply add the docker image as a Docker toolchain.

Note: CLion and other IDEs may not always fully support the latest CMake versions.


## Details

The Dockerfile is multi staged and has different targets for all the variants.
All targets with underscores are meant to be internally only.

Note: clang libc++ Qt combination is missing because the Qt Company does not publish Linux binaries built for libc++
