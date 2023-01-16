project('accel', ['c', 'vala'],
          version: '0.1.0-alpha',
    meson_version: '>= 0.50.0',
  default_options: [ 'warning_level=2',
                   ],
)

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

# Blueprint
subproject('blueprint-compiler')
add_project_arguments(
    '--gresourcesdir', meson.current_build_dir() / 'src',
    language: ['vala']
)
#

subdir('data')
subdir('src')
subdir('po')

meson.add_install_script('build-aux/meson/postinstall.py')
