gnome = import('gnome')

subdir('gtk')

gresources = gnome.compile_resources(
  'asresources',
  'accelerator.gresource.xml',
  source_dir: meson.current_build_dir(),
  dependencies: blueprints,
  c_name: 'as',
  install_dir: get_option('datadir') / meson.project_name(),
)

add_project_arguments(
    '--gresourcesdir', meson.current_build_dir(),
    '--gresourcesdir', meson.current_build_dir() / 'gtk',
    language: ['vala']
)

accelerator_sources = [
  gresources,
  'Application.vala',
  'CommandLine.vala',
  'main.vala',
]

subdir('widgets')
subdir('services')
subdir('utils')

conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', 'accelerator')
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('PREFIX', get_option('prefix'))
conf_data.set_quoted('DATADIR', join_paths (get_option('prefix'), get_option('datadir')))
conf_data.set_quoted('LOCALEDIR', join_paths (get_option('prefix'), get_option('localedir')))
conf_data.set('DEVEL', get_option('devel').to_string().to_lower())

config_header = configure_file(
            input: 'config.vala.in',
           output: 'config.vala',
    configuration: conf_data
    )

accelerator_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk4', version: '>= 4.6.2'),
  dependency('libhelium-1'),
  dependency('vte-2.91-gtk4', version: '>= 0.69.0'),
  dependency('json-glib-1.0', version: '>= 1.4.4'),
  dependency('libpcre2-8'),
  dependency('libxml-2.0', version: '>= 2.9.12'),
  dependency('librsvg-2.0', version: '>= 2.54.0'),
  dependency('gee-0.8', version: '>=0.20'),
  dependency('graphene-gobject-1.0'),
]

# https://github.com/elementary/terminal/blob/d9620eb12331a28c658f97ac9a1bdb809aa90089/meson.build
vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments('--vapidir=' + vapi_dir, language: 'vala')
add_project_arguments('-DPCRE2_CODE_UNIT_WIDTH=0', language: 'c')

# This is required until VTE 0.70 is out
add_project_arguments('--disable-since-check', language: 'vala')

executable('accel', accelerator_sources, config_header,
  vala_args: '--target-glib=2.50',  dependencies: accelerator_deps,
  install: true,

)

# symlink as accelerator
if get_option('devel') or get_option('flatpak')
install_data ('accel-link-system-fonts', install_dir: 'bin')
endif

