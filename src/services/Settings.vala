/* Settings.vala
 *
 * Copyright 2022 Paulo Queiroz
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
 */

public enum Terminal.ScrollbackMode {
  FIXED = 0,
  UNLIMITED = 1,
  DISABLED = 2,
}

public class Terminal.Settings : SettingsService {
  public bool command_as_login_shell               { get; set; }
  public bool easy_copy_paste                      { get; set; }
  public bool fill_tabs                            { get; set; }
  public bool headerbar_drag_area                  { get; set; }
  public bool pretty                               { get; set; }
  public bool remember_window_size                 { get; set; }
  public bool show_headerbar                       { get; set; }
  public bool show_menu_button                     { get; set; }
  public bool show_scrollbars                      { get; set; }
  public bool use_custom_command                   { get; set; }
  public bool use_overlay_scrolling                { get; set; }
  public bool use_sixel                            { get; set; }
  public bool was_fullscreened                     { get; set; }
  public bool was_maximized                        { get; set; }
  public bool window_show_borders                  { get; set; }
  public double terminal_cell_height                 { get; set; }
  public double terminal_cell_width                  { get; set; }
  public string custom_shell_command                 { get; set; }
  public string font                                 { get; set; }
  public string theme_dark                           { get; set; }
  public string theme_light                          { get; set; }
  public uint cursor_blink_mode                    { get; set; }
  public uint cursor_shape                         { get; set; }
  public uint opacity                              { get; set; }
  public uint scrollback_lines                     { get; set; }
  public uint scrollback_mode                      { get; set; }
  public bool style_preference                     { get; set; }
  public uint window_height                        { get; set; }
  public uint window_width                         { get; set; }
  public Variant terminal_padding                     { get; set; }

  public bool floating_controls                       { get; set; }
  public uint floating_controls_hover_area            { get; set; }
  public uint delay_before_showing_floating_controls  { get; set; }

  private static Settings instance = null;

  private Settings () {
    base ("com.fyralabs.Accelerator");
  }

  public static Settings get_default () {
    if (Settings.instance == null) {
      Settings.instance = new Settings ();
    }
    return Settings.instance;
  }

  public Padding get_padding () {
    return Padding.from_variant (this.terminal_padding);
  }

  public void set_padding (Padding padding) {
    this.terminal_padding = padding.to_variant ();
  }
}

public class Terminal.SearchSettings : SettingsService {
  public bool match_case_sensitive     { get; set; }
  public bool match_whole_words        { get; set; }
  public bool match_regex              { get; set; }
  public bool wrap_around              { get; set; }

  private static SearchSettings instance = null;

  private SearchSettings () {
    base ("com.fyralabs.Accelerator.terminal.search");
  }

  public static SearchSettings get_default () {
    if (SearchSettings.instance == null) {
      SearchSettings.instance = new SearchSettings ();
    }
    return SearchSettings.instance;
  }
}

public abstract class Terminal.SettingsService : Object
{
    public GLib.Settings schema { get; construct set; }

    private bool updating = false;
    private bool doing_setup = true;

    protected SettingsService (string path)
    {
        Object(schema: new GLib.Settings(path));
    }

    // Runs after Settings()
    construct
    {
        debug("Started settings from '%s'", this.schema.schema_id);

        var obj_class = (ObjectClass) this.get_type().class_ref();
        var properties = obj_class.list_properties();
            foreach (var prop in properties)
                this.load_key(prop.name);

        this.doing_setup = false;
        this.schema.changed.connect(this.load_key);
    }

    private void load_key(string key)
    {
        if (key == "schema")
            return;

        var obj_class = (ObjectClass) this.get_type().class_ref();
        var prop = obj_class.find_property(key);

        if (prop == null)
            return;

        this.notify.disconnect(this.on_notify);

        var type = prop.value_type;
        var val = Value(type);
        this.get_property(key, ref val);

        if (val.type() == prop.value_type)
        {
            if (type == typeof(int))
                this.set_property(prop.name, schema.get_int(key));
            else if (type == typeof(uint))
                this.set_property(prop.name, schema.get_uint(key));
            else if (type == typeof(double))
                this.set_property(prop.name, schema.get_double(key));
            else if (type == typeof(bool))
                this.set_property(prop.name, schema.get_boolean(key));
            else if (type == typeof(string))
                this.set_property(prop.name, schema.get_string(key));
            else if (type == typeof(string[]))
                this.set_property(prop.name, schema.get_strv(key));
            else if (type == typeof(int64))
                this.set_property(prop.name, schema.get_value(key).get_int64());
            else if (type == typeof(uint64))
                this.set_property(prop.name,
                                  schema.get_value(key).get_uint64());
            else if (type.is_enum())
                this.set_property(prop.name, schema.get_enum(key));
        }
        else
        {
            warning("Unsuported type %s for key %s", type.to_string(), key);
        }

        this.notify.connect(this.on_notify);
    }

    private void save_key(string key)
    {
        if (key == "schema" || this.updating)
            return;

        var obj_class = (ObjectClass) this.get_type().class_ref();
        var prop = obj_class.find_property(key);

        if (prop == null)
            return;

        this.notify.disconnect(this.on_notify);

        bool res = true;
        this.updating = true;

        var type = prop.value_type;
        var val = Value(type);
        this.get_property(prop.name, ref val);

        if (val.type() == prop.value_type)
        {
            if (type == typeof(int) &&
                val.get_int() != schema.get_int(key))
            {
                res = this.schema.set_int(key, val.get_int());
            }
            else if (type == typeof(uint) &&
                     val.get_uint() != schema.get_uint(key))
            {
                res = this.schema.set_uint(key, val.get_uint());
            }
            else if (type == typeof(double) &&
                     val.get_double() != schema.get_double(key))
            {
                res = this.schema.set_double(key, val.get_double());
            }
            else if (type == typeof(bool) &&
                     val.get_boolean() != schema.get_boolean(key))
            {
                res = this.schema.set_boolean(key, val.get_boolean());
            }
            else if (type == typeof(string) &&
                     val.get_string() != schema.get_string(key))
            {
                res = this.schema.set_string(key, val.get_string());
            }
            else if (type == typeof(string[]))
            {
                string[] strv = null;
                this.get(key, &strv);
                if (strv != this.schema.get_strv(key))
                {
                    res = this.schema.set_strv(key, strv);
                }
            }
            else if (type == typeof(int64) &&
                     val.get_int64() != schema.get_value(key).get_int64())
            {
                res = this.schema.set_value(key,
                        new Variant.int64(val.get_int64()));
            }
            else if (type == typeof(uint64) &&
                     val.get_uint64() != schema.get_value(key).get_uint64())
            {
                res = this.schema.set_value(key,
                        new Variant.uint64(val.get_uint64()));
            }
            else if (type.is_enum() &&
                     val.get_enum() != this.schema.get_enum(key))
            {
                res = this.schema.set_enum(key, val.get_enum());
            }
        }
        else
        {
            warning("Unsuported type %s for key %s", type.to_string(), key);
        }

        if (!res)
            warning("Could not update %s", key);

        this.updating = false;
        this.notify.connect(this.on_notify);
    }

    private void on_notify(Object sender, ParamSpec prop)
    {
        this.save_key(prop.name);
    }
}

