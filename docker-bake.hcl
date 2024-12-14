function "default_distros" {
  params = []
  result = ["noble"]
}
function "default_cmake_versions" {
  params = []
  result = ["3.30.6", "3.31.2"]
}
function "default_clangs" {
  params = []
  result = [
    {major: 17, source: "apt"},
    {major: 18, source: "llvm"},
    {major: 19, source: "llvm"}
  ]
}
function "default_gccs" {
  params = []
  result = [
    {major: 12, source: "apt"},
    {major: 13, source: "apt"},
    {major: 14, source: "apt"}
  ]
}
function "default_qts" {
  params = []
  result = [
    {version: "6.6.3", arch: "gcc_64"},
    {version: "6.7.3", arch: "linux_gcc_64"},
    {version: "6.8.1", arch: "linux_gcc_64"}
  ]
}

variable "DISTROS" {
  default = jsonencode(default_distros())
  # default = jsonencode([default_distros()[length(default_distros()) - 1]]) # only latest
}
variable "ALL_DISTROS" {
  default = jsonencode(default_distros())
}
function "distros" {
  params = []
  result = jsondecode(ALL_DISTROS)
}
function "matrix_distros" {
  params = []
  result = jsondecode(DISTROS)
}

variable "CMAKE_VERSIONS" {
  default = jsonencode(default_cmake_versions())
  # default = jsonencode([default_cmake_versions()[length(default_cmake_versions()) - 1]]) # only latest
}
variable "ALL_CMAKE_VERSIONS" {
  default = jsonencode(default_cmake_versions())
}
function "cmake_versions" {
  params = []
  result = jsondecode(ALL_CMAKE_VERSIONS)
}
function "matrix_cmake_versions" {
  params = []
  result = jsondecode(CMAKE_VERSIONS)
}

variable "CLANGS" {
  default = jsonencode(default_clangs())
  # default = jsonencode([default_clangs()[length(default_clangs()) - 1]]) # only latest
}
variable "ALL_CLANGS" {
  default = jsonencode(default_clangs())
}
function "clangs" {
  params = []
  result = jsondecode(ALL_CLANGS)
}
function "matrix_clangs" {
  params = []
  result = jsondecode(CLANGS)
}

variable "GCCS" {
  default = jsonencode(default_gccs())
  # default = jsonencode([default_gccs()[length(default_gccs()) - 1]]) # only latest
}
variable "ALL_GCCS" {
  default = jsonencode(default_gccs())
}
function "gccs" {
  params = []
  result = jsondecode(ALL_GCCS)
}
function "matrix_gccs" {
  params = []
  result = jsondecode(GCCS)
}

variable "QTS" {
  default = jsonencode(default_qts())
  # default = jsonencode([default_qts()[length(default_qts()) - 1]]) # only latest
}
variable "ALL_QTS" {
  default = jsonencode(default_qts())
}
function "qts" {
  params = []
  result = jsondecode(ALL_QTS)
}
function "matrix_qts" {
  params = []
  result = jsondecode(QTS)
}

function "latestTag" {
  params = [cmake_version, clang_major, gcc_major, qt_version]
  result = (cmake_version == cmake_versions()[length(cmake_versions())-1]
    && (clang_major == "" || clang_major == clangs()[length(clangs()) - 1].major)
    && (gcc_major == "" || gcc_major == gccs()[length(gccs()) - 1].major)
    && (qt_version == "" || qt_version == qts()[length(qts()) - 1].version)) ? "latest" : ""
}
function "versionTag" {
  params = [cmake_version, clang_major, gcc_major, qt_version]
  result = join("-", compact([cmake_version, clang_major, gcc_major, qt_version]))
}
function "tags" {
  params = [target, cmake_version, clang_major, gcc_major, qt_version]
  result = flatten([for tag in compact([versionTag(cmake_version, clang_major, gcc_major, qt_version), latestTag(cmake_version, clang_major, gcc_major, qt_version)]) : [
    "arbmind/${target}:${tag}",
    "ghcr.io/arbmind/${target}:${tag}"
  ]])
}
function "describeClang" {
  params = [major]
  result = major == "" ? "" : "Clang${major}"
}
function "describeGcc" {
  params = [target, major]
  result = major == "" ? "" : (length(regexall("-clang-", target)) > 0 ? "LibStdC++${major}" : "GCC${major}")
}
function "describeQt" {
  params = [target, version]
  result = version == "" ? "" : (length(regexall("qtgui", target)) > 0 ? "QtGui ${version}" : "Qt ${version}")
}
function "description" {
  params = [target, distro, cmake_version, clang_major, gcc_major, qt_version, extra]
  result = "Ubuntu ${distro} - ${join(" + ", compact(["CMake ${cmake_version}", describeClang(clang_major), describeGcc(target, gcc_major), describeQt(target, qt_version), extra]))}"
}
function "uniqueName" {
  params = [target, distro, cmake_version, clang_major, gcc_major, qt_version]
  result = join("-", compact([target, distro, replace(cmake_version, ".", "_"), clang_major, gcc_major, replace(qt_version, ".", "_")]))
}
function "dockerTarget" {
  params = [target]
  result = length(regexall("qtgui-dev$", target)) > 0 ? "cmake-qtgui-dev" : target
}

group "default" {
  targets = [
    "cmake-gcc",
    "cmake-gcc-qt",
    "cmake-gcc-qtgui-dev",
    "cmake-clang",
    "cmake-clang-libstdcpp",
    "cmake-clang-libstdcpp-qt",
    "cmake-clang-libstdcpp-qtgui-dev"
  ]
}

target "_common" {
  dockerfile = "Dockerfile"
  context = "./"
  labels = {
    "org.opencontainers.image.source" = "https://github.com/arBmind/cmake-containers"
  }
}

target "cmake-gcc" {
  inherits = ["_common"]
  target = dockerTarget(name)
  name = uniqueName(name, distro, cmake_version, "", gcc.major, "")
  tags = tags(name, cmake_version, "", gcc.major, "")
  matrix = {
    name = ["cmake-gcc"],
    distro = matrix_distros(),
    cmake_version = matrix_cmake_versions(),
    gcc = matrix_gccs(),
  }
  args = {
    DISTRO = distro
    GCC_MAJOR = gcc.major
    GCC_SOURCE = gcc.source
    CMAKE_VERSION = cmake_version
  }
  labels = {
    Description = description(name, distro, cmake_version, "", gcc.major, "", "")
  }
}
target "cmake-gcc-qt" {
  inherits = ["_common"]
  target = dockerTarget(name)
  name = uniqueName(name, distro, cmake_version, "", gcc.major, qt.version)
  tags = tags(name, cmake_version, "", gcc.major, qt.version)
  matrix = {
    name = ["cmake-gcc-qt"],
    distro = matrix_distros(),
    cmake_version = matrix_cmake_versions(),
    gcc = matrix_gccs(),
    qt = matrix_qts()
  }
  args = {
    DISTRO = distro
    GCC_MAJOR = gcc.major
    GCC_SOURCE = gcc.source
    QT_VERSION = qt.version
    QT_ARCH = qt.arch
    CMAKE_VERSION = cmake_version
  }
  labels = {
    Description = description(name, distro, cmake_version, "", gcc.major, qt.version, "")
  }
}
target "cmake-gcc-qtgui-dev" {
  inherits = ["_common"]
  target = dockerTarget(name)
  name = uniqueName(name, distro, cmake_version, "", gcc.major, qt.version)
  tags = tags(name, cmake_version, "", gcc.major, qt.version)
  matrix = {
    name = ["cmake-gcc-qtgui-dev"],
    distro = matrix_distros(),
    cmake_version = matrix_cmake_versions(),
    gcc = matrix_gccs(),
    qt = matrix_qts()
  }
  args = {
    DISTRO = distro
    GCC_MAJOR = gcc.major
    GCC_SOURCE = gcc.source
    QT_VERSION = qt.version
    QT_ARCH = qt.arch
    CMAKE_VERSION = cmake_version
    QTGUI_BASE_IMAGE = "cmake-gcc-qt"
  }
  labels = {
    Description = description(name, distro, cmake_version, "", gcc.major, qt.version, "Dev")
  }
}
target "cmake-clang" {
  inherits = ["_common"]
  target = dockerTarget(name)
  name = uniqueName(name, distro, cmake_version, clang.major, "", "")
  tags = tags(name, cmake_version, clang.major, "", "")
  matrix = {
    name = ["cmake-clang"],
    distro = matrix_distros(),
    cmake_version = matrix_cmake_versions(),
    clang = matrix_clangs(),
  }
  args = {
    DISTRO = distro
    CLANG_MAJOR = clang.major
    CLANG_SOURCE = clang.source
    CMAKE_VERSION = cmake_version
  }
  labels = {
    Description = description(name, distro, cmake_version, clang.major, "", "", "")
  }
}
target "cmake-clang-libstdcpp" {
  inherits = ["_common"]
  target = dockerTarget(name)
  name = uniqueName(name, distro, cmake_version, clang.major, gcc.major, "")
  tags = tags(name, cmake_version, clang.major, gcc.major, "")
  matrix = {
    name = ["cmake-clang-libstdcpp"],
    distro = matrix_distros(),
    cmake_version = matrix_cmake_versions(),
    clang = matrix_clangs(),
    gcc = matrix_gccs(),
  }
  args = {
    DISTRO = distro
    CLANG_MAJOR = clang.major
    CLANG_SOURCE = clang.source
    GCC_MAJOR = gcc.major
    GCC_SOURCE = gcc.source
    CMAKE_VERSION = cmake_version
  }
  labels = {
    Description = description(name, distro, cmake_version, clang.major, gcc.major, "", "")
  }
}
target "cmake-clang-libstdcpp-qt" {
  inherits = ["_common"]
  target = dockerTarget(name)
  name = uniqueName(name, distro, cmake_version, clang.major, gcc.major, qt.version)
  tags = tags(name, cmake_version, clang.major, gcc.major, qt.version)
  matrix = {
    name = ["cmake-clang-libstdcpp-qt"],
    distro = matrix_distros(),
    cmake_version = matrix_cmake_versions(),
    clang = matrix_clangs(),
    gcc = matrix_gccs(),
    qt = matrix_qts()
  }
  args = {
    DISTRO = distro
    CLANG_MAJOR = clang.major
    CLANG_SOURCE = clang.source
    GCC_MAJOR = gcc.major
    GCC_SOURCE = gcc.source
    QT_VERSION = qt.version
    QT_ARCH = qt.arch
    CMAKE_VERSION = cmake_version
  }
  labels = {
    Description = description(name, distro, cmake_version, clang.major, gcc.major, qt.version, "")
  }
}
target "cmake-clang-libstdcpp-qtgui-dev" {
  inherits = ["_common"]
  target = dockerTarget(name)
  name = uniqueName(name, distro, cmake_version, clang.major, gcc.major, qt.version)
  tags = tags(name, cmake_version, clang.major, gcc.major, qt.version)
  matrix = {
    name = ["cmake-clang-libstdcpp-qtgui-dev"],
    distro = matrix_distros(),
    cmake_version = matrix_cmake_versions(),
    clang = matrix_clangs(),
    gcc = matrix_gccs(),
    qt = matrix_qts()
  }
  args = {
    DISTRO = distro
    CLANG_MAJOR = clang.major
    CLANG_SOURCE = clang.source
    GCC_MAJOR = gcc.major
    GCC_SOURCE = gcc.source
    QT_VERSION = qt.version
    QT_ARCH = qt.arch
    CMAKE_VERSION = cmake_version
    QTGUI_BASE_IMAGE = "cmake-clang-libstdcpp-qt"
  }
  labels = {
    Description = description(name, distro, cmake_version, clang.major, gcc.major, qt.version, "Dev")
  }
}
