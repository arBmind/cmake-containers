# Docker images for CMake

These docker images are used to run continuious integrations and local builds with the CMake build system.

## Options

compilers and standard libraries:
* Clang/libc++
* Clang/libstdc++
* GCC/libstdc++

Qt:
* none (bring your own)
* Qt official builds (using aqtinstall)


## Usage

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


## Details

The Dockerfile is multi staged and has different targets for all the variants.
All targets with underscores are meant to be internally only.

Targets:
* clang
* clang-libstdcpp
* clang-libstdcpp-qt
* gcc
* gcc-qt

Note: clang-qt is missing because the Qt Company does not publish binaries built for libc++
