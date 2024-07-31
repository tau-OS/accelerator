/* HeaderBar.vala
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

namespace Terminal {
  static GLib.Menu? _window_menu = null;

  public GLib.Menu get_window_menu_model () {
    if (_window_menu == null) {
      var more_menu = new GLib.Menu ();
      var section1 = new GLib.Menu ();

      section1.append (_("Fullscreen"), ACTION_WIN_FULLSCREEN);
      section1.append (_("Preferences…"), ACTION_WIN_EDIT_PREFERENCES);
      section1.append (_("About Accelerator…"), "app.about");
      more_menu.append_section (null, section1);

      _window_menu = more_menu;
    }

    return _window_menu;
  }
}

public abstract class Terminal.BaseHeaderBar : Gtk.Box {
  public virtual Gtk.MenuButton menu_button     { get; protected set; }

  protected He.TabSwitcher tab_bar;
  protected Window window;

  construct {
    // Menu button
    this.menu_button = new Gtk.MenuButton () {
      can_focus = false,
      menu_model = get_window_menu_model (),
      icon_name = "open-menu-symbolic",
      tooltip_text = _("Menu"),
      valign = Gtk.Align.CENTER,
      hexpand = false,
      halign = Gtk.Align.END,
    };
    menu_button.add_css_class ("tab-button");
    menu_button.get_popover ().has_arrow = false;

    Settings.get_default ().schema.bind (
                                         "show-menu-button",
                                         this.menu_button,
                                         "visible",
                                         SettingsBindFlags.GET
    );
  }

  protected BaseHeaderBar (Window window) {
    Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

    this.window = window;
    this.tab_bar = this.window.tab_bar;
  }
}

public class Terminal.HeaderBar : BaseHeaderBar {


  private Gtk.WindowControls left_controls;
  private Gtk.WindowControls right_controls;
  private Gtk.Label title_label;

  private Gtk.Button unfullscreen_button;

  public HeaderBar (Window window) {
    base (window);

    var hb = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    hb.halign = Gtk.Align.FILL;
    hb.hexpand = true;

    this.tab_bar.halign = Gtk.Align.FILL;
    this.tab_bar.hexpand = true;

    this.unfullscreen_button = new Gtk.Button () {
      can_focus = false,
      icon_name = "view-restore-symbolic",
      halign = Gtk.Align.END,
      valign = Gtk.Align.CENTER,
    };
    this.unfullscreen_button.add_css_class ("tab-button");

    this.left_controls = new Gtk.WindowControls (Gtk.PackType.START);
    left_controls.valign = Gtk.Align.START;
    this.right_controls = new Gtk.WindowControls (Gtk.PackType.END);
    right_controls.valign = Gtk.Align.START;

    this.left_controls.bind_property ("empty", this.left_controls, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN, null, null);
    this.right_controls.bind_property ("empty", this.right_controls, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN, null, null);

    var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
      margin_start = 6,
      margin_end = 6
    };
    button_box.append (this.unfullscreen_button);
    button_box.append (this.menu_button);

    var layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    layout.halign = Gtk.Align.FILL;
    layout.hexpand = true;

    layout.append (this.left_controls);
    layout.append (this.tab_bar);
    layout.append (button_box);
    layout.append (this.right_controls);

    hb.append (layout);

    var wc = new Gtk.WindowHandle ();
    wc.hexpand = true;
    wc.set_child (hb);

    this.append (wc);
    this.add_css_class ("custom-headerbar");

    this.connect_signals ();
  }

  private void connect_signals () {
    var settings = Settings.get_default ();

    // window.fullscreened -> unfullscreen_button visibility
    this.window.bind_property (
                               "fullscreened",
                               this.unfullscreen_button,
                               "visible",
                               GLib.BindingFlags.SYNC_CREATE,
                               null,
                               null
    );
    // !window.fullscreened -> left_controls visibility
    this.window.bind_property (
                               "fullscreened",
                               this.left_controls,
                               "visible",
                               GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN,
                               null,
                               null
    );
    // !window.fullscreened -> right_controls visibility
    this.window.bind_property (
                               "fullscreened",
                               this.right_controls,
                               "visible",
                               GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN,
                               null,
                               null
    );
    // window.active_terminal_title -> title_label label
    this.window.bind_property (
                               "active-terminal-title",
                               this.title_label,
                               "label",
                               GLib.BindingFlags.SYNC_CREATE,
                               null,
                               null
    );
    // window.active_terminal_title -> title_label tooltip-text
    this.window.bind_property (
                               "active-terminal-title",
                               this.title_label,
                               "tooltip-text",
                               GLib.BindingFlags.SYNC_CREATE,
                               null,
                               null
    );

    settings.notify["headerbar-drag-area"].connect (
                                                    this.on_drag_area_changed
    );
    this.on_drag_area_changed ();

    this.unfullscreen_button.clicked.connect (this.on_unmaximize);

    var mcc = new Gtk.GestureClick () {
      button = Gdk.BUTTON_MIDDLE,
    };
    mcc.pressed.connect (() => {
      this.window.new_tab (null, null);
    });
    this.add_controller (mcc);
  }

  private void on_unmaximize () {
    this.window.unfullscreen ();
  }

  private void on_drag_area_changed () {
    var drag_area = Settings.get_default ().headerbar_drag_area;

    set_css_class (this, "with-dragarea", drag_area);
  }
}
