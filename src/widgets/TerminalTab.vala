/* TerminalTab.vala
 *
 * Copyright 2021-2022 Paulo Queiroz
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

public class Terminal.TerminalTab : He.Tab {

  public signal void close_request ();

  public string title     { get; protected set; }
  public Terminal terminal  { get; protected set; }
  public Gtk.ScrolledWindow scrolled  { get; protected set; }

  private SearchToolbar search_toolbar;
  public Window window;

  public Gtk.Box box;

  public TerminalTab (Window window, string? command, string? cwd) {
    this.set_name ("terminal-tab");
    this.box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    this.box.hexpand = true;
    this.box.vexpand = true;
    this.window = window;
    this.terminal = new Terminal (this.window, command, cwd);
    this.terminal.hexpand = true;
    this.terminal.vexpand = true;
    this.focusable = false;
    this.terminal.focusable = true;
    this.focus_on_click = false;

    this.scrolled = new Gtk.ScrolledWindow ();
    this.scrolled.set_child (this.terminal);
    this.scrolled.hexpand = true;
    this.scrolled.vexpand = true;
    this.search_toolbar = new SearchToolbar (this.terminal);
    this.box.append (this.search_toolbar);
    this.box.append (this.scrolled);
    this.box.visible = false;
    // ! This makes it display in the tab widget, but we want it below and in the main view
    // this.box.set_parent (this.window.tab_view);

    var click = new Gtk.GestureClick () {
      button = Gdk.BUTTON_SECONDARY,
    };
    click.pressed.connect (this.show_menu);

    this.terminal.add_controller (click);

    this.connect_signals ();
  }

  // function to set the current tab
  public void set_tab () {
    this.window.tab_bar.current = this;
    this.window.tab_view.child = this.box;
    // this.box.set_parent (this.window.tab_view);
  }

  private void connect_signals () {
    var settings = Settings.get_default ();

    this.terminal.notify["window-title"].connect (() => {
      this.title = this.terminal.window_title;
    });

    this.terminal.exit.connect (() => {
      this.close_request ();
    });

    settings.notify["show-scrollbars"].connect (() => {
      var show_scrollbars = settings.show_scrollbars;
      var is_scrollbar_being_used = this.scrolled.child == this.terminal;

      if (show_scrollbars && !is_scrollbar_being_used) {
        this.box.remove (this.terminal);
        this.scrolled.child = this.terminal;
        this.box.append (this.scrolled);
      } else if (!show_scrollbars && is_scrollbar_being_used) {
        this.box.remove (this.scrolled);
        this.scrolled.child = null;
        this.box.append (this.terminal);
      }
    });
    settings.notify_property ("show-scrollbars");

    settings.schema.bind (
                          "use-overlay-scrolling",
                          this.scrolled,
                          "overlay-scrolling",
                          SettingsBindFlags.GET
    );

    settings.bind_property (
                            "use-sixel",
                            this.terminal as Object,
                            "enable-sixel",
                            BindingFlags.SYNC_CREATE
    );
  }

  public void show_menu (int n_pressed, double x, double y) {
    var menu = new Menu ();
    var edit_section = new Menu ();
    var preferences_section = new Menu ();
    var bottom_section = new Menu ();

    menu.append (_("New Tab"), "win.new_tab");
    menu.append (_("New Window"), "app.new-window");

    edit_section.append (_("Copy"), "win.copy");
    edit_section.append (_("Paste"), "win.paste");

    menu.append_section (null, edit_section);

    preferences_section.append (_("Preferences"), "win.edit_preferences");
    menu.append_section (null, preferences_section);

    bottom_section.append (_("Keyboard Shortcuts"), "win.show-help-overlay");
    bottom_section.append (_("About"), "app.about");
    menu.append_section (null, bottom_section);

    var pop = new Gtk.PopoverMenu.from_model (menu);

    Gdk.Rectangle r = { 0 };
    // BEGIN: scuffed position calculation ft. integer overflow
    {
      // move the popover to the right position
      // !? scuffed position calculation (chess.com brilliant move icon)
      var term_allocation = this.terminal.get_allocated_width ();

      debug ("term_width: %d", term_allocation);
      // get the tab position (but with actual human counting)
      var tab_pos = this.window.tab_bar.get_tab_position (this) + 1;
      debug ("tab_pos: %d", tab_pos);

      // now multiply the tab position by the terminal width
      var tab_pos_x = tab_pos * (term_allocation / 2);
      debug ("tab_pos_x: %d", tab_pos_x);
      debug ("x: %d", (int) x);
      var left_padding = Settings.get_default ().get_padding ().left;
      debug ("left_padding: %u", left_padding);

      int temp_value = 0;
      int cursor_offset = 25;

      if (tab_pos > 1) {
        temp_value = tab_pos_x - (tab_pos_x / 2) - (tab_pos_x / 8) - 25;
        cursor_offset += 45;
      }

      debug ("temp_value: %u", temp_value);

      debug ("cursor_offset: %u", cursor_offset);


      var offset = (((int) x) - (cursor_offset + temp_value)) + left_padding;
      debug ("offset: %u", offset);


      // todo: actually fix this offsetting code, or find the root cause of the issue
      // Confession: I have no idea what I'm doing. I failed basic algebra in high school. - @korewaChino
      // I hope someone who comes across this code who actually knows math can fix this. I'm sorry.
      // time_wasted: 30m
      r.x = (int) offset;
      r.y = (int) (y + 75 + Settings.get_default ().get_padding ().bottom);


    }
    // END: scuffed position calculation ft. integer overflow

    /*
    !? The block above is a reminder of how much I hate myself for writing this code. I don't know why it works, but it does by inducing
     * an integer overflow. wtf?
     * @lainsce: I'm sorry for this. I'm sorry for everything. On behalf of the entire Fyra Labs team, I'm sorry. This code is just really cursed
     * I seriously do not know why or how it works. It just does.
     */

    pop.closed.connect_after (() => {
      pop.destroy ();
    });

    pop.set_parent (this);
    pop.set_has_arrow (false);
    pop.set_pointing_to (r);
    pop.popup ();
  }

  public void search () {
    this.search_toolbar.open ();
  }
}
