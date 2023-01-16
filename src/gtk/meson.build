blueprints = custom_target('blueprints',
  input: files(
    'help-overlay.blp',
    'search-toolbar.blp',
    'preferences-window.blp',
    'shortcut-dialog.blp',
    'shortcut-editor.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)