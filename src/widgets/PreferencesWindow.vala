/* PreferencesWindow2.vala
 *
 * Copyright 2022 Paulo Queiroz <pvaqueiroz@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

bool dark_themes_filter_func (Gtk.FlowBoxChild child) {
  var thumbnail = child as Terminal.ColorSchemeThumbnail;
  return thumbnail.scheme.is_dark;
}

bool light_themes_filter_func (Gtk.FlowBoxChild child) {
  var thumbnail = child as Terminal.ColorSchemeThumbnail;
  return !thumbnail.scheme.is_dark;
}

[GtkTemplate (ui = "/com/fyralabs/Accelerator/preferences-window.ui")]
public class Terminal.PreferencesWindow : He.SettingsWindow {
  [GtkChild] unowned Gtk.ToggleButton block_cursor_toggle;
  [GtkChild] unowned Gtk.ToggleButton ibeam_toggle;
  [GtkChild] unowned Gtk.ToggleButton underline_toggle;
  [GtkChild] unowned Gtk.ToggleButton follow_sys_cursor_toggle;
  [GtkChild] unowned Gtk.ToggleButton on_cursor_toggle;
  [GtkChild] unowned Gtk.ToggleButton off_cursor_toggle;
  [GtkChild] unowned He.Switch style_preference_switch;
  [GtkChild] unowned Gtk.Entry custom_command_entry;
  [GtkChild] unowned Gtk.Adjustment floating_controls_delay_adjustment;
  [GtkChild] unowned Gtk.Adjustment floating_controls_hover_area_adjustment;
  [GtkChild] unowned Gtk.CheckButton filter_themes_check_button;
  [GtkChild] unowned Gtk.FlowBox preview_flow_box;
  [GtkChild] unowned He.Button font_label;
  [GtkChild] unowned He.Switch fill_tabs_switch;
  [GtkChild] unowned He.Switch floating_controls_switch;
  [GtkChild] unowned Gtk.SpinButton opacity_spin_button;
  [GtkChild] unowned He.Switch remember_window_size_switch;
  [GtkChild] unowned He.Switch run_command_as_login_switch;
  [GtkChild] unowned He.Switch show_headerbar_switch;
  [GtkChild] unowned He.Switch show_menu_button_switch;
  [GtkChild] unowned He.Switch use_custom_shell_command_switch;
  [GtkChild] unowned He.Switch drag_area_switch;
  [GtkChild] unowned Gtk.ToggleButton dark_theme_toggle;
  [GtkChild] unowned Gtk.ToggleButton light_theme_toggle;

  private Window window;

  public bool show_custom_scrollback_row { get; set; default = false; }
  public string selected_theme {
    get {
      return this.light_theme_toggle.active
        ? Settings.get_default ().theme_light
        : Settings.get_default ().theme_dark;
    }
    set {
      if (this.light_theme_toggle.active) {
        Settings.get_default ().theme_light = value;
      } else {
        Settings.get_default ().theme_dark = value;
      }
    }
  }

  static construct {
    typeof (ShortcutEditor).class_ref ();
  }

  construct {
    if (DEVEL) {
      this.add_css_class ("devel");
    }
  }

  public PreferencesWindow (Window window) {
    Object (
            application: window.application,
            transient_for: window,
            destroy_with_parent: true
    );

    this.window = window;

    cursor_blink_refresh ();
    cursor_shape_refresh ();

    this.build_ui ();
    this.bind_data ();
    this.set_size_request (360,600);
  }

  // Build UI

  private void build_ui () {
    ColorSchemeThumbnailProvider.init_resource ();

    // var model = new GLib.ListStore (typeof (ColorSchemeThumbnail));

    this.window.theme_provider.themes.for_each ((name, scheme) => {
      if (scheme != null) {
        var t = new ColorSchemeThumbnail (scheme);

        this.bind_property (
                            "selected-theme",
                            t,
                            "selected",
                            BindingFlags.SYNC_CREATE,
                            (_, from, ref to) => {
          to = from.get_string () == t.scheme.name;
          return true;
        },
                            null
        );

        // model.append (t);
        this.preview_flow_box.append (t);
      }
    });

    this.preview_flow_box.set_sort_func ((child1, child2) => {
      var a = child1 as ColorSchemeThumbnail;
      var b = child2 as ColorSchemeThumbnail;

      return strcmp (a.scheme.name.down (), b.scheme.name.down ());
    });
  }

  // Connections

  private void bind_data () {
    var settings = Settings.get_default ();

    settings.schema.bind (
                          "font",
                          this.font_label,
                          "label",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "command-as-login-shell",
                          this.run_command_as_login_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "custom-shell-command",
                          this.custom_command_entry,
                          "text",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "use-custom-command",
                          this.custom_command_entry,
                          "sensitive",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "use-custom-command",
                          this.use_custom_shell_command_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind_with_mapping (
                                       "opacity",
                                       this.opacity_spin_button,
                                       "value",
                                       SettingsBindFlags.DEFAULT,
                                       // From settings to spin button
                                       (to_val, settings_variant) => {
      to_val = settings_variant.get_uint32 ();
      return true;
    },
                                       // From spin button to settings
                                       (value) => {
      return new GLib.Variant.uint32 ((uint) value.get_double ());
    },
                                       null,
                                       null
    );

    settings.schema.bind (
                          "fill-tabs",
                          this.fill_tabs_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "show-menu-button",
                          this.show_menu_button_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "show-headerbar",
                          this.show_headerbar_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "headerbar-drag-area",
                          this.drag_area_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "remember-window-size",
                          this.remember_window_size_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    // 0 = Block, 1 = IBeam, 2 = Underline
    block_cursor_toggle.toggled.connect (() => {
      set_cursor_shape (0);
    });
    ibeam_toggle.toggled.connect (() => {
      set_cursor_shape (1);
    });
    underline_toggle.toggled.connect (() => {
      set_cursor_shape (2);
    });

    // 0 = Follow System, 1 = On, 2 = Off
    follow_sys_cursor_toggle.toggled.connect (() => {
      set_cursor_blink (0);
    });
    on_cursor_toggle.toggled.connect (() => {
      set_cursor_blink (1);
    });
    off_cursor_toggle.toggled.connect (() => {
      set_cursor_blink (2);
    });

    settings.schema.bind ("style-preference", style_preference_switch.iswitch, "active", SettingsBindFlags.DEFAULT);

    settings.schema.bind (
                          "floating-controls",
                          this.floating_controls_switch.iswitch,
                          "active",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "floating-controls-hover-area",
                          this.floating_controls_hover_area_adjustment,
                          "value",
                          SettingsBindFlags.DEFAULT
    );

    settings.schema.bind (
                          "delay-before-showing-floating-controls",
                          this.floating_controls_delay_adjustment,
                          "value",
                          SettingsBindFlags.DEFAULT
    );

    this.preview_flow_box.child_activated.connect ((child) => {
      var name = (child as ColorSchemeThumbnail) ? .scheme.name;
      this.selected_theme = name;
    });

    this.light_theme_toggle.notify["active"].connect (() => {
      this.notify_property ("selected-theme");
      this.set_themes_filter_func ();
    });

    settings.notify["theme-light"].connect (() => {
      if (this.light_theme_toggle.active) {
        this.notify_property ("selected-theme");
      }
    });

    settings.notify["theme-dark"].connect (() => {
      if (this.dark_theme_toggle.active) {
        this.notify_property ("selected-theme");
      }
    });

    if (ThemeProvider.get_default ().is_dark_style_active) {
      this.dark_theme_toggle.active = true;
    } else {
      this.light_theme_toggle.active = true;
    }

    ThemeProvider.get_default ().notify["is-dark-style-active"].connect (() => {
      if (ThemeProvider.get_default ().is_dark_style_active) {
        this.dark_theme_toggle.active = true;
      } else {
        this.light_theme_toggle.active = true;
      }
    });

    // themes-filter-func

    this.filter_themes_check_button.notify["active"].connect (() => {
      this.set_themes_filter_func ();
    });

    this.set_themes_filter_func ();
  }

  // Methods

  private void set_cursor_shape (int b) {
    var settings = Settings.get_default ();
    settings.schema.set_enum ("cursor-shape", b);
  }
  private void cursor_shape_refresh () {
    var settings = Settings.get_default ();
    int value = settings.schema.get_enum ("cursor-shape");

    if (value == 0) {
      block_cursor_toggle.set_active (true);
      ibeam_toggle.set_active (false);
      underline_toggle.set_active (false);
    } else if (value == 1) {
      block_cursor_toggle.set_active (false);
      ibeam_toggle.set_active (true);
      underline_toggle.set_active (false);
    } else if (value == 2) {
      block_cursor_toggle.set_active (false);
      ibeam_toggle.set_active (false);
      underline_toggle.set_active (true);
    }
}

  private void set_cursor_blink (int b) {
    var settings = Settings.get_default ();
    settings.schema.set_enum ("cursor-blink-mode", b);
  }
  private void cursor_blink_refresh () {
      var settings = Settings.get_default ();
      int value = settings.schema.get_enum ("cursor-blink-mode");

      if (value == 0) {
        follow_sys_cursor_toggle.set_active (true);
        on_cursor_toggle.set_active (false);
        off_cursor_toggle.set_active (false);
      } else if (value == 1) {
        follow_sys_cursor_toggle.set_active (false);
        on_cursor_toggle.set_active (true);
        off_cursor_toggle.set_active (false);
      } else if (value == 2) {
        follow_sys_cursor_toggle.set_active (false);
        on_cursor_toggle.set_active (false);
        off_cursor_toggle.set_active (true);
      }
  }

  private void set_themes_filter_func () {
    if (!this.filter_themes_check_button.active) {
      this.preview_flow_box.set_filter_func (null);
    } else {
      if (this.light_theme_toggle.active) {
        this.preview_flow_box.set_filter_func (light_themes_filter_func);
      } else {
        this.preview_flow_box.set_filter_func (dark_themes_filter_func);
      }
    }
  }

  private void do_reset_preferences () {
    var settings = Settings.get_default ();
    foreach (var key in settings.schema.settings_schema.list_keys ()) {
      settings.schema.reset (key);
    }
  }

  // Callbacks

  [GtkCallback]
  private void on_font_row_activated () {
    var fc = new Gtk.FontChooserDialog (_("Terminal Font"), this) {
      level = Gtk.FontChooserLevel.FAMILY | Gtk.FontChooserLevel.SIZE | Gtk.FontChooserLevel.STYLE,
      // Setting the font seems to have no effect
      font = Settings.get_default ().font,
    };

    fc.set_filter_func ((desc) => {
      return desc.is_monospace ();
    });

    fc.response.connect_after ((response) => {
      if (response == Gtk.ResponseType.OK && fc.font != null) {
        Settings.get_default ().font = fc.font;
      }
      fc.destroy ();
    });

    fc.show ();
  }

  [GtkCallback]
  private void on_reset_request () {
    var d = new Gtk.MessageDialog (
                                   this,
                                   Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                   Gtk.MessageType.QUESTION,
                                   Gtk.ButtonsType.YES_NO,
                                   "Are you sure you want to reset all settings?"
    );

    var yes_button = d.get_widget_for_response (Gtk.ResponseType.YES);
    yes_button?.add_css_class ("destructive-action");

    var no_button = d.get_widget_for_response (Gtk.ResponseType.NO);
    no_button?.add_css_class ("suggested-action");

    d.set_default_response (Gtk.ResponseType.NO);

    d.response.connect ((response) => {
      if (response == Gtk.ResponseType.YES) {
        this.do_reset_preferences ();
      }
      d.destroy ();
    });

    d.present ();
  }

  [GtkCallback]
  private void on_get_more_themes_online () {
    Gtk.show_uri (
                  this,
                  "https://github.com/storm119/Tilix-Themes",
                  (int32) (get_monotonic_time () / 1000)
    );
  }

  [GtkCallback]
  private void on_open_themes_folder () {
    Gtk.show_uri (
                  this,
                  "file://" + Constants.get_user_schemes_dir (),
                  (int32) (get_monotonic_time () / 1000)
    );
  }
}
