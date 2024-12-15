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
function "targets" {
  params = []
  result = [
    "cmake-gcc",
    "cmake-gcc-qt",
    "cmake-gcc-qtgui-dev",
    "cmake-clang",
    "cmake-clang-libstdcpp",
    "cmake-clang-libstdcpp-qt",
    "cmake-clang-libstdcpp-qtgui-dev"
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
  params = [target]
  result = length(regexall("-clang(?:-|$)", target)) > 0 ? jsondecode(CLANGS) : [{major: "", source: ""}]
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
  params = [target]
  result = length(regexall("-(?:gcc|libstdcpp)(?:-|$)", target)) > 0 ? jsondecode(GCCS) : [{major: "", source: ""}]
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
  params = [target]
  result = length(regexall("-qt", target)) > 0 ? jsondecode(QTS) : [{version: "", arch: ""}]
}

function "matrix" {
  params = []
  result = flatten([for target in targets() :
    flatten([for distro in matrix_distros() :
      flatten([for cmake_version in matrix_cmake_versions() :
        flatten([for clang in matrix_clangs(target) :
          flatten([for gcc in matrix_gccs(target) :
            [for qt in matrix_qts(target) : {
              target: target,
              distro: distro,
              cmake_version: cmake_version,
              clang: clang,
              gcc: gcc,
              qt: qt
            }]
          ])
        ])
      ])
    ])
  ])
}

function "latestTag" {
  params = [cmake_version, clang_major, gcc_major, qt_version]
  result = (cmake_version == cmake_versions()[length(cmake_versions())-1]
    && (clang_major == "" || "X${clang_major}" == "X${clangs()[length(clangs()) - 1].major}")
    && (gcc_major == "" || "X${gcc_major}" == "X${gccs()[length(gccs()) - 1].major}")
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
  result = version == "" ? "" : (length(regexall("qtgui-dev$", target)) > 0 ? "QtGui ${version} + Dev" : "Qt ${version}")
}
function "description" {
  params = [target, distro, cmake_version, clang_major, gcc_major, qt_version]
  result = "Ubuntu ${distro} - ${join(" + ", compact(["CMake ${cmake_version}", describeClang(clang_major), describeGcc(target, gcc_major), describeQt(target, qt_version)]))}"
}
function "uniqueName" {
  params = [target, distro, cmake_version, clang_major, gcc_major, qt_version]
  result = join("-", compact([target, distro, replace(cmake_version, ".", "_"), clang_major, gcc_major, replace(qt_version, ".", "_")]))
}
function "dockerTarget" {
  params = [target]
  result = length(regexall("qtgui-dev$", target)) > 0 ? "cmake-qtgui-dev" : target
}
function "qtguiBaseImage" {
  params = [target]
  result = length(regexall("-clang-", target)) > 0 ? "cmake-clang-libstdcpp-qt" : "cmake-gcc-qt"
}

target "default" {
  dockerfile = "Dockerfile"
  context = "./"
  target = dockerTarget(matrix.target)
  name = uniqueName(matrix.target, matrix.distro, matrix.cmake_version, matrix.clang.major, matrix.gcc.major, matrix.qt.version)
  tags = tags(matrix.target, matrix.cmake_version, matrix.clang.major, matrix.gcc.major, matrix.qt.version)
  matrix = {
    matrix = matrix()
  }
  args = {
    DISTRO = matrix.distro
    CMAKE_VERSION = matrix.cmake_version
    CLANG_MAJOR = matrix.clang.major
    CLANG_SOURCE = matrix.clang.source
    GCC_MAJOR = matrix.gcc.major
    GCC_SOURCE = matrix.gcc.source
    QT_VERSION = matrix.qt.version
    QT_ARCH = matrix.qt.arch
    QTGUI_BASE_IMAGE = qtguiBaseImage(matrix.target)
  }
  labels = {
    "org.opencontainers.image.source" = "https://github.com/arBmind/cmake-containers"
    Description = description(matrix.target, matrix.distro, matrix.cmake_version, matrix.clang.major, matrix.gcc.major, matrix.qt.version)
  }
}
