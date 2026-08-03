# https://mesonbuild.com/External-Project-module.html

project('uchardet', 'c', 'cpp')

cmake = import('cmake')

cpu = host_machine.cpu()
if cpu == 'amd64'
    arch = 'x86_64'
elif cpu == 'arm64'
    arch = 'arm64'
endif

options = cmake.subproject_options()
options.add_cmake_defines({
    'CMAKE_OSX_ARCHITECTURES': arch,
    'CMAKE_OSX_SYSROOT': meson.get_cross_property('cmake_osx_sysroot'),
    'BUILD_STATIC': false,
    # cmake 4.4's meson.subproject translator emits VERSION "X.Y.Z.debug"
    # for non-Release builds, which meson's shared_library() then rejects.
    # Force Release to keep VERSION valid ("0.0.8") for the translator.
    'CMAKE_BUILD_TYPE': 'Release',
    # cmake 4 dropped compat with cmake_minimum_required < 3.5; uchardet's
    # CMakeLists uses an older minimum.
    'CMAKE_POLICY_VERSION_MINIMUM': '3.5',
})

uchardet = cmake.subproject('uchardet',
    options: options,
)

uchardet_dep = uchardet.dependency('libuchardet')
meson.override_dependency('uchardet', uchardet_dep)
