ARG DISTRO=focal
ARG CLANG_MAJOR=13
ARG GCC_MAJOR=11
ARG QT_ARCH=gcc_64
ARG QT_VERSION=6.2.4
ARG QT_MODULES=""
ARG CMAKE_VERSION=3.22.3
ARG CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz
ARG RUNTIME_APT="libicu70 libgssapi-krb5-2 libdbus-1-3 libpcre2-16-0"
# use "cmake-gcc-qt" or "cmake-clang-libstdcpp-qt"
ARG QTGUI_BASE_IMAGE="cmake-gcc-qt"
# note: these depend on distro and Qt version
ARG QTGUI_PACKAGES=libegl-dev \
  libglu1-mesa-dev \
  libgl-dev \
  libopengl-dev \
  libxkbcommon-dev \
  libfontconfig1-dev \
  xdg-utils \
  libxcb-keysyms1 \
  libxcb-render-util0 \
  libxcb-xfixes0 \
  libxcb-icccm4 \
  libxcb-image0 \
  libxcb-shape0 \
  libgssapi-krb5-2 \
  libxcb-xinerama0 \
  libxcb-xkb1 \
  libxkbcommon-x11-0 \
  libxcb-randr0

# base Qt setup
FROM python:3.10-slim as qt_base
ARG QT_ARCH
ARG QT_VERSION
ARG QT_MODULES
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

RUN pip install aqtinstall

RUN \
  apt update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    p7zip-full \
    libglib2.0-0 \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

RUN \
  mkdir /qt && cd /qt \
  && aqt install-qt linux desktop ${QT_VERSION} ${QT_ARCH} -m ${QT_MODULES} --external $(which 7zr)


# base CMake setup
FROM ubuntu:${DISTRO} AS cmake_base
ARG CMAKE_URL
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

RUN \
  apt-get update --quiet \
  && apt-get upgrade --yes --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    ca-certificates \
    wget \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

RUN \
  mkdir -p /opt/cmake \
  && wget -q -c ${CMAKE_URL} -O - | tar --strip-components=1 -xz -C /opt/cmake


# base compiler setup for GCC
FROM ubuntu:${DISTRO} AS gcc_base
ARG DISTRO
ARG GCC_MAJOR
ARG RUNTIME_APT
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

ENV \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

# install GCC
RUN \
  apt-get update --quiet \
  && apt-get upgrade --yes --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    libglib2.0-0 \
    apt-transport-https \
    ca-certificates \
    gnupg \
    wget \
  && wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x60c317803a41ba51845e371a1e9377a2ba9ef27f" | apt-key add - \
  && echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/gcc.list \
  && apt-get update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    git \
    ninja-build \
    make \
    libstdc++-${GCC_MAJOR}-dev \
    gcc-${GCC_MAJOR} \
    g++-${GCC_MAJOR} \
    ${RUNTIME_APT} \
  && update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-${GCC_MAJOR} 100 \
  && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-${GCC_MAJOR} 100 \
  && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_MAJOR} 100 \
  && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_MAJOR} 100 \
  && c++ --version \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*


# final cmake-gcc (no Qt)
FROM gcc_base AS cmake-gcc
ARG DISTRO
ARG GCC_MAJOR
ARG CMAKE_VERSION

LABEL Description="Ubuntu ${DISTRO} - Gcc${GCC_MAJOR} + CMake ${CMAKE_VERSION}"

COPY --from=cmake_base /opt/cmake /opt/cmake
ENV \
  PATH=/opt/cmake/bin:${PATH}


# final cmake-gcc-gt (with Qt)
FROM gcc_base AS cmake-gcc-qt
ARG DISTRO
ARG GCC_MAJOR
ARG CMAKE_VERSION
ARG QT_VERSION
ARG QT_ARCH

LABEL Description="Ubuntu ${DISTRO} - Gcc${GCC_MAJOR} + CMake ${CMAKE_VERSION} + Qt ${QT_VERSION}"

COPY --from=cmake_base /opt/cmake /opt/cmake
COPY --from=qt_base /qt/${QT_VERSION} /qt/${QT_VERSION}
ENV \
  QTDIR=/qt/${QT_VERSION}/${QT_ARCH} \
  PATH=/qt/${QT_VERSION}/${QT_ARCH}/bin:/opt/cmake/bin:${PATH} \
  LD_LIBRARY_PATH=/qt/${QT_VERSION}/${QT_ARCH}/lib:${LD_LIBRARY_PATH}


# base compiler setup for Clang
FROM ubuntu:${DISTRO} AS clang_base
ARG DISTRO
ARG CLANG_MAJOR
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive
ARG RUNTIME_APT

ENV \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

# install Clang (https://apt.llvm.org/)
RUN apt-get update --quiet \
  && apt-get upgrade --yes --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    libglib2.0-0 \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates \
  && wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
  && echo "deb http://apt.llvm.org/${DISTRO}/ llvm-toolchain-${DISTRO}-${CLANG_MAJOR} main" > /etc/apt/sources.list.d/llvm.list \
  && apt-get update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    git \
    ninja-build \
    make \
    ${RUNTIME_APT} \
    clang-${CLANG_MAJOR} \
    lld-${CLANG_MAJOR} \
    libc++abi-${CLANG_MAJOR}-dev \
    libc++-${CLANG_MAJOR}-dev \
    $( [ $CLANG_MAJOR -ge 12 ] && echo "libunwind-${CLANG_MAJOR}-dev" ) \
  && update-alternatives --install /usr/bin/cc cc /usr/bin/clang-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.lld-${CLANG_MAJOR} 10 \
  && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.gold 20 \
  && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.bfd 30 \
  && c++ --version \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*


# final cmake-clang (no Qt)
FROM clang_base AS cmake-clang
ARG DISTRO
ARG CLANG_MAJOR
ARG CMAKE_VERSION

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + CMake ${CMAKE_VERSION}"

COPY --from=cmake_base /opt/cmake /opt/cmake
ENV \
  PATH=/opt/cmake/bin:${PATH}


FROM clang_base AS clang_libstdcpp_base
ARG DISTRO
ARG GCC_MAJOR
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

RUN \
  wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x60c317803a41ba51845e371a1e9377a2ba9ef27f" | apt-key add - \
  && echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/gcc.list \
  && apt-get update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    libstdc++-${GCC_MAJOR}-dev \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*


# final cmake-clang-libstdcpp (no Qt)
FROM clang_libstdcpp_base AS cmake-clang-libstdcpp
ARG DISTRO
ARG CLANG_MAJOR
ARG GCC_MAJOR
ARG CMAKE_VERSION

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + Libstdc++-${GCC_MAJOR} + CMake ${CMAKE_VERSION}"

COPY --from=cmake_base /opt/cmake /opt/cmake
ENV \
  PATH=/opt/cmake/bin:${PATH}


# final cmake-clang-qt (with Qt)
FROM clang_libstdcpp_base AS cmake-clang-libstdcpp-qt
ARG DISTRO
ARG CLANG_MAJOR
ARG GCC_MAJOR
ARG CMAKE_VERSION
ARG QT_VERSION
ARG QT_ARCH

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + Libstdc++-${GCC_MAJOR} + CMake ${CMAKE_VERSION} + Qt ${QT_VERSION}"

COPY --from=cmake_base /opt/cmake /opt/cmake
COPY --from=qt_base /qt/${QT_VERSION} /qt/${QT_VERSION}
ENV \
  QTDIR=/qt/${QT_VERSION}/${QT_ARCH} \
  PATH=/qt/${QT_VERSION}/${QT_ARCH}/bin:/opt/cmake/bin:${PATH} \
  LD_LIBRARY_PATH=/qt/${QT_VERSION}/${QT_ARCH}/lib:${LD_LIBRARY_PATH}


# final qtqui (as developer setup)
FROM ${QTGUI_BASE_IMAGE} AS cmake-qtgui-dev
ARG QTGUI_PACKAGES

RUN \
  apt update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    ${QTGUI_PACKAGES} \
    gdb \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
