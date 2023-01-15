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

  public string             title     { get; protected set; }
  public Terminal           terminal  { get; protected set; }
  public Gtk.ScrolledWindow scrolled  { get; protected set; }

  private SearchToolbar     search_toolbar;
  public  Window            window;

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
    // ! This makes it display in the tab widget, but we want it below and in the main view
    //  this.box.set_parent (this.window.tab_view);

    var click = new Gtk.GestureClick () {
      button = Gdk.BUTTON_SECONDARY,
    };
    click.pressed.connect (this.show_menu);

    this.terminal.add_controller (click);

    this.connect_signals ();
  }


  // function to set the current tab
  public void set_tab() {
    this.window.tab_bar.current = this;
    this.window.tab_view.child = this.box;
    //  this.box.set_parent (this.window.tab_view);
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
      }
      else if (!show_scrollbars && is_scrollbar_being_used) {
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

    Gdk.Rectangle r = {0};
    r.x = (int) (x + Settings.get_default ().get_padding ().left);
    r.y = (int) (y + Settings.get_default ().get_padding ().top);

    pop.closed.connect_after (() => {
      pop.destroy ();
    });

    pop.set_parent (this);
    pop.set_pointing_to (r);
    pop.popup ();
  }

  public void search () {
    this.search_toolbar.open ();
  }
}
