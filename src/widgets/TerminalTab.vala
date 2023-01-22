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
    this.terminal.enable_sixel = true;
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
    this.visible = false;

    this.connect_signals ();
  }

  private void connect_signals () {
    var settings = Settings.get_default ();

    this.terminal.notify["window-title"].connect (() => {
      this.title = this.terminal.window_title;
    });

    this.terminal.exit.connect (() => {
      this.close_request ();
    });

    // connect the expand-tabs setting to the tab hexpand
    settings.bind_property (
                            "fill-tabs",
                            this,
                            "hexpand",
                            BindingFlags.SYNC_CREATE
    );

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


  public void search () {
    this.search_toolbar.open ();
  }
}
