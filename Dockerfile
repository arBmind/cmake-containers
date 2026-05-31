# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

ARG DISTRO=noble
ARG CLANG_MAJOR=21
# clang source options:
# apt - directly use apt version
# llvm - add llvm distro repo
ARG CLANG_SOURCE=llvm
ARG GCC_MAJOR=14
# gcc source options:
# apt - directly use apt version
# ppa - add toolchain ppa
ARG GCC_SOURCE=apt
# note: this AQT version has patch for latest python pool issues (no new release yet)
ARG AQT_WHL_URL=https://github.com/arBmind/aqtinstall/releases/download/3.3.1-dev/aqtinstall-3.3.1.dev19-py3-none-any.whl
ARG QT_ARCH=gcc_64
ARG QT_VERSION=6.9.2
ARG QT_MODULES=""
ARG CLANG_QT_URL=https://github.com/arBmind/qt5/releases/download/v6.5.3/qt653_clang17.tgz
ARG QT_EXTRAS_URL=https://github.com/arBmind/qt5/releases/download/v6.5.3/extra_libs.tgz
ARG CMAKE_VERSION=3.29.5
ARG CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz
# Ubuntu lunar
#ARG RUNTIME_APT="libicu72 libgssapi-krb5-2 libdbus-1-3 libpcre2-16-0"
# Ubuntu noble
ARG RUNTIME_APT="icu-devtools libgssapi-krb5-2 libdbus-1-3 libpcre2-16-0 libbrotli1"
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
FROM python:3.13-slim AS qt_base
ARG \
  AQT_WHL_URL \
  QT_ARCH \
  QT_VERSION \
  QT_MODULES \
  DEBIAN_FRONTEND=noninteractive

RUN <<INSTALL_AQT
  apt-get -qq update -o=Dpkg::Use-Pty=0
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    wget \
    p7zip-full \
    libglib2.0-0
  apt-get -qq --yes autoremove -o=Dpkg::Use-Pty=0
  apt-get -qq clean autoclean -o=Dpkg::Use-Pty=0
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
  if [ "$AQT_WHL_URL" != "" ] ; then
    FILENAME=$(basename "$AQT_WHL_URL")
    wget -q -c ${AQT_WHL_URL} -O /tmp/$FILENAME
    pip install /tmp/$FILENAME
    rm /tmp/$FILENAME
  else
    pip install aqtinstall
  fi
INSTALL_AQT

RUN <<INSTALL_QT
  set -e
  mkdir /qt
  cd /qt
  echo '#!/bin/bash' > /tmp/7z.sh
  echo "$(which 7zr) \"\$@\" -snld20" >> /tmp/7z.sh
  chmod u+x /tmp/7z.sh
  aqt install-qt linux desktop ${QT_VERSION} ${QT_ARCH} -m ${QT_MODULES} --external /tmp/7z.sh
  rm /tmp/7z.sh
INSTALL_QT



# base CMake setup
FROM ubuntu:${DISTRO} AS cmake_base
ARG \
  CMAKE_URL \
  DEBIAN_FRONTEND=noninteractive

RUN <<INSTALL_WGET
  apt-get -qq update -o=Dpkg::Use-Pty=0
  apt-get -qq --yes upgrade -o=Dpkg::Use-Pty=0
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    ca-certificates \
    wget
  apt-get -qq --yes autoremove -o=Dpkg::Use-Pty=0
  apt-get -qq clean autoclean -o=Dpkg::Use-Pty=0
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_WGET

RUN <<INSTALL_CMAKE
  mkdir -p /opt/cmake
  wget -q -c ${CMAKE_URL} -O - | tar --strip-components=1 -xz -C /opt/cmake
INSTALL_CMAKE



# base compiler setup for GCC
FROM ubuntu:${DISTRO} AS gcc_base
ARG \
  DISTRO \
  GCC_MAJOR \
  GCC_SOURCE \
  RUNTIME_APT \
  APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
  DEBIAN_FRONTEND=noninteractive
ENV \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

RUN <<INSTALL_GCC
  set -e
  apt-get -qq update -o=Dpkg::Use-Pty=0
  apt-get -qq --yes upgrade -o=Dpkg::Use-Pty=0
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    libglib2.0-0 \
    apt-transport-https \
    ca-certificates \
    gnupg \
    wget
  if [ "$GCC_SOURCE" = "ppa" ] ; then
    wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x60c317803a41ba51845e371a1e9377a2ba9ef27f" | apt-key add -
    echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/gcc.list
    apt-get -qq update -o=Dpkg::Use-Pty=0
  fi
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    git \
    ninja-build \
    make \
    libstdc++-${GCC_MAJOR}-dev \
    gcc-${GCC_MAJOR} \
    g++-${GCC_MAJOR} \
    ${RUNTIME_APT}
  update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-${GCC_MAJOR} 100
  update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-${GCC_MAJOR} 100
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_MAJOR} 100
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_MAJOR} 100
  c++ --version
  apt-get -qq --yes autoremove -o=Dpkg::Use-Pty=0
  apt-get -qq clean autoclean -o=Dpkg::Use-Pty=0
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_GCC



# final cmake-gcc (no Qt)
FROM gcc_base AS cmake-gcc
COPY --from=cmake_base /opt/cmake /opt/cmake
ENV \
  PATH=/opt/cmake/bin:${PATH}



# final cmake-gcc-gt (with Qt)
FROM gcc_base AS cmake-gcc-qt
ARG QT_VERSION

COPY --from=cmake_base /opt/cmake /opt/cmake
COPY --from=qt_base /qt/${QT_VERSION} /qt/${QT_VERSION}
ENV \
  QTDIR=/qt/${QT_VERSION}/gcc_64 \
  PATH=/qt/${QT_VERSION}/gcc_64/bin:/opt/cmake/bin:${PATH}
# LD_LIBRARY_PATH=/qt/${QT_VERSION}/gcc_64/lib



# base compiler setup for Clang
FROM ubuntu:${DISTRO} AS clang_base
ARG \
  DISTRO \
  CLANG_MAJOR \
  CLANG_SOURCE \
  DEBIAN_FRONTEND=noninteractive \
  RUNTIME_APT
ENV \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

# install Clang (https://apt.llvm.org/)
RUN <<INSTALL_CLANG
  apt-get -qq update -o=Dpkg::Use-Pty=0
  apt-get -qq --yes upgrade -o=Dpkg::Use-Pty=0
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    libglib2.0-0 \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates
  if [ "$CLANG_SOURCE" = "llvm" ] ; then
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key > /etc/apt/trusted.gpg.d/apt.llvm.org.asc
    tee /etc/apt/sources.list.d/llvm.sources <<LLVM_SOURCES
Enabled: yes
Types: deb
URIs: http://apt.llvm.org/${DISTRO}/
Suites: llvm-toolchain-${DISTRO}-${CLANG_MAJOR}
Components: main
Signed-By: /etc/apt/trusted.gpg.d/apt.llvm.org.asc
LLVM_SOURCES
    apt-get -qq update -o=Dpkg::Use-Pty=0
  fi
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    git \
    ninja-build \
    make \
    ${RUNTIME_APT} \
    clang-${CLANG_MAJOR} \
    lld-${CLANG_MAJOR} \
    libc++abi-${CLANG_MAJOR}-dev \
    libc++-${CLANG_MAJOR}-dev \
    $( [ $CLANG_MAJOR -ge 12 ] && echo "libunwind-${CLANG_MAJOR}-dev" )
  update-alternatives --install /usr/bin/cc cc /usr/bin/clang-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_MAJOR} 100
  update-alternatives --install /usr/bin/ld ld /usr/bin/ld.lld-${CLANG_MAJOR} 10
  update-alternatives --install /usr/bin/ld ld /usr/bin/ld.gold 20
  update-alternatives --install /usr/bin/ld ld /usr/bin/ld.bfd 30
  c++ --version
  apt-get -qq --yes autoremove -o=Dpkg::Use-Pty=0
  apt-get -qq clean autoclean -o=Dpkg::Use-Pty=0
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_CLANG

# final cmake-clang (no Qt)
FROM clang_base AS cmake-clang
COPY --from=cmake_base /opt/cmake /opt/cmake
ENV \
  PATH=/opt/cmake/bin:${PATH}


# final cmake-clang-qt (with Qt)
FROM clang_base AS cmake-clang-qt
ARG \
  QT_VERSION \
  CLANG_QT_URL \
  QT_EXTRAS_URL

COPY --from=cmake_base /opt/cmake /opt/cmake
RUN <<INSTALL_CLANG_QT
  mkdir -p /opt/qt${QT_VERSION}
  wget -q -c ${CLANG_QT_URL} -O - | tar --strip-components=1 -xz -C /opt/qt${QT_VERSION}
  wget -q -c ${QT_EXTRAS_URL} -O - | tar --strip-components=1 -xz -C /opt/qt${QT_VERSION}/lib
INSTALL_CLANG_QT

ENV \
  QTDIR=/opt/qt${QT_VERSION} \
  PATH=/opt/qt${QT_VERSION}/bin:/opt/cmake/bin:${PATH}
# LD_LIBRARY_PATH=/opt/qt${QT_VERSION}/lib



FROM clang_base AS clang_libstdcpp_base
ARG \
  DISTRO \
  GCC_MAJOR \
  GCC_SOURCE \
  APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
  DEBIAN_FRONTEND=noninteractive

RUN <<INSTALL_LIBSTDCPP
  if [ "$GCC_SOURCE" = "ppa" ] ; then
    wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x60c317803a41ba51845e371a1e9377a2ba9ef27f" | apt-key add -
    echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/gcc.list
    apt-get -qq update -o=Dpkg::Use-Pty=0
  fi
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    libstdc++-${GCC_MAJOR}-dev
  apt-get -qq --yes autoremove -o=Dpkg::Use-Pty=0
  apt-get -qq clean autoclean -o=Dpkg::Use-Pty=0
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_LIBSTDCPP



# final cmake-clang-libstdcpp (no Qt)
FROM clang_libstdcpp_base AS cmake-clang-libstdcpp
COPY --from=cmake_base /opt/cmake /opt/cmake
ENV \
  PATH=/opt/cmake/bin:${PATH}



# final cmake-clang-qt (with Qt)
FROM clang_libstdcpp_base AS cmake-clang-libstdcpp-qt
ARG QT_VERSION

COPY --from=cmake_base /opt/cmake /opt/cmake
COPY --from=qt_base /qt/${QT_VERSION} /qt/${QT_VERSION}
ENV \
  QTDIR=/qt/${QT_VERSION}/gcc_64 \
  PATH=/qt/${QT_VERSION}/gcc_64/bin:/opt/cmake/bin:${PATH}
# LD_LIBRARY_PATH=/qt/${QT_VERSION}/gcc_64/lib



# final qtqui (as developer setup)
FROM ${QTGUI_BASE_IMAGE} AS cmake-qtgui-dev
ARG QTGUI_PACKAGES

RUN <<INSTALL_QTGUI_PACKAGES
  apt-get -qq update -o=Dpkg::Use-Pty=0
  apt-get -qq --yes install -o=Dpkg::Use-Pty=0 --no-install-recommends \
    ${QTGUI_PACKAGES} \
    gdb
  apt-get -qq --yes autoremove -o=Dpkg::Use-Pty=0
  apt-get -qq clean autoclean -o=Dpkg::Use-Pty=0
  rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
INSTALL_QTGUI_PACKAGES
