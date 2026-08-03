# https://mesonbuild.com/External-Project-module.html

project('pkg-config', 'c')

mod = import('unstable-external_project')

# pkg-config 0.29.2 embeds glib 2.36 (2013). Xcode 16.4 clang promoted
# -Wint-conversion (and friends) from warning to error, breaking glib's
# g_atomic_pointer_* helpers. Pass CFLAGS as autotools positional args
# (they end up as CFLAGS in configure, then in every sub-make) — env-level
# CFLAGS doesn't reach the wrapped configure through meson's externalproject.
relax = '-Wno-error=int-conversion -Wno-error=implicit-function-declaration -Wno-error=incompatible-function-pointer-types -Wno-error=deprecated-non-prototype'

p = mod.add_project('configure',
    configure_options : [
        '--prefix=@PREFIX@',
        '--disable-static',
        '--enable-fast-instal=true',
        '--disable-dependency-tracking',
        '--with-pic',
        '--with-aix-soname=aix',
        '--without-gnu-ld',
        '--with-internal-glib',
        '--without-gcov',
        'CFLAGS=' + relax,
        'CXXFLAGS=' + relax,
    ],
    verbose: true,
)

pkg_config_dep = p.dependency('pkg-config')
meson.override_dependency('pkg-config', pkg_config_dep)
