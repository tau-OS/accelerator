/* Window.vala
 *
 * Copyright 2020-2022 Paulo Queiroz
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

public struct Terminal.Padding {
  uint top;
  uint right;
  uint bottom;
  uint left;

  public Variant to_variant () {
    return new Variant (
                        "(uuuu)",
                        this.top,
                        this.right,
                        this.bottom,
                        this.left
    );
  }

  public static Padding zero () {
    return { 0 };
  }

  public static Padding from_variant (Variant vari) {
    return_val_if_fail (
                        vari.check_format_string ("(uuuu)", false),
                        Padding.zero ()
    );

    var iter = vari.iterator ();
    uint top = 0, right = 0, bottom = 0, left = 0;

    iter.next ("u", &top);
    iter.next ("u", &right);
    iter.next ("u", &bottom);
    iter.next ("u", &left);

    return Padding () {
             top = top,
             right = right,
             bottom = bottom,
             left = left,
    };
  }

  public string to_string () {
    return "Padding { %u, %u, %u, %u }".printf (
                                                this.top,
                                                this.right,
                                                this.bottom,
                                                this.left
    );
  }

  /**
   * Whether padding on all sides is the same.
   */
  public bool is_equilateral () {
    return (
            this.top == this.right &&
            this.right == this.bottom &&
            this.bottom == this.left
    );
  }
}

public class Terminal.Window : He.ApplicationWindow {

  public ThemeProvider theme_provider        { get; private set; }
  public He.TabPage tab_view              { get; private set; }
  public unowned He.TabSwitcher tab_bar;
  public He.Bin active_terminal_container    { get; private set; }
  public Terminal active_terminal       { get; private set; }
  public string? active_terminal_title { get; private set; }

  BaseHeaderBar header_bar;
  Gtk.Revealer header_bar_revealer;

  Gtk.HeaderBar floating_bar;
  Gtk.Box floating_btns;
  Gtk.MenuButton floating_menu_btn;
  Gtk.Button show_headerbar_button;
  Gtk.Button fullscreen_button;
  Gtk.Revealer floating_header_bar_revealer;

  Settings settings = Settings.get_default ();

  const uint header_bar_revealer_duration_ms = 250;
  private uint waiting_for_floating_hb_animation = 0;

  private SimpleAction copy_action;
  private Array<ulong> active_terminal_signal_handlers = new Array<ulong> ();

  static PreferencesWindow? preferences_window = null;

  construct {
    if (DEVEL) {
      this.add_css_class ("devel");
    }
    this.title = APP_NAME;

    var layout_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    var tabview = new He.TabPage (this.blank_tab ());
    tabview.name = "tabview";
    tabview.visible = true;
    tabview.hexpand = true;
    tabview.halign = Gtk.Align.FILL;
    tabview.vexpand = true;
    tabview.valign = Gtk.Align.FILL;
    tabview.show ();
    this.tab_view = tabview;

    var tabbar = new He.TabSwitcher () {
      allow_new_window = false,
      hexpand = true,
      halign = Gtk.Align.FILL,
      focus_on_click = false,
    };
    tabbar.allow_new_window = false;
    tabbar.set_focusable (false);
    tabbar.set_hexpand (true);
    tabbar.set_halign (Gtk.Align.FILL);
    tabbar.allow_drag = true;
    this.tab_bar = tabbar;


    this.header_bar = new HeaderBar (this);

    this.header_bar_revealer = new Gtk.Revealer () {
      transition_duration = Window.header_bar_revealer_duration_ms,
      child = this.header_bar,
    };

    // Floating controls bar  ===============

    this.fullscreen_button = new Gtk.Button.from_icon_name ("view-fullscreen-symbolic") {
      tooltip_text = _("Fullscreen")
    };
    this.show_headerbar_button = new Gtk.Button.from_icon_name ("view-top-pane-symbolic") {
      tooltip_text = _("Show headerbar")
    };
    this.floating_btns = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
      css_classes = { "floating-btn-box" },
      overflow = Gtk.Overflow.HIDDEN,
      valign = Gtk.Align.CENTER,
    };
    this.floating_btns.append (this.fullscreen_button);
    this.floating_btns.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
    this.floating_btns.append (this.show_headerbar_button);

    this.floating_menu_btn = new Gtk.MenuButton () {
      menu_model = get_window_menu_model (),
      icon_name = "open-menu-symbolic",
      css_classes = { "circular" },
      valign = Gtk.Align.CENTER,
      can_focus = false,
      tooltip_text = _("Menu")
    };

    this.floating_bar = new Gtk.HeaderBar () {
      css_classes = { "flat" },
      title_widget = new Gtk.Label ("") { hexpand = true },
    };

    this.floating_header_bar_revealer = new Gtk.Revealer () {
      transition_duration = Window.header_bar_revealer_duration_ms,
      transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,

      valign = Gtk.Align.START,
      vexpand = false,
      child = floating_bar,

      css_classes = { "floating-revealer" },
    };

    this.on_decoration_layout_changed ();

    layout_box.append (this.header_bar_revealer);
    layout_box.append (this.tab_view);
    layout_box.set_name ("accelerator-layout-box");

    var overlay = new Gtk.Overlay ();
    overlay.child = layout_box;
    overlay.set_name ("accelerator-overlay");
    overlay.add_overlay (this.floating_header_bar_revealer);

    this.child = overlay;

    this.set_name ("accelerator-main-window");
  }

  public He.Tab blank_tab () {
    var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    box.set_name ("accelerator-blank-tab-box");
    var label = new Gtk.Label (_("No tabs open")) {
      halign = Gtk.Align.CENTER,
      valign = Gtk.Align.CENTER,
      hexpand = true,
      vexpand = true,
      selectable = false,
      use_markup = true,
      wrap = true,
      wrap_mode = Pango.WrapMode.WORD_CHAR,
      css_classes = { "dim-label" }
    };
    box.append (label);
    var tab = new He.Tab ("Blank Tab", box);
    tab.set_name ("accelerator-blank-tab");
    tab.set_id ("placeholder-tab");
    return tab;
  }

  public Window (Gtk.Application app,
    string? command = null,
    string? cwd = null,
    bool skip_initial_tab = false) {
    var sett = Settings.get_default ();
    var wwidth = (int) (sett.remember_window_size ? sett.window_width : 700);
    var wheight = (int) (sett.remember_window_size ? sett.window_height : 450);

    Object (
            application: app,
            default_width: wwidth,
            default_height: wheight,
            fullscreened: sett.remember_window_size && sett.was_fullscreened,
            maximized: sett.remember_window_size && sett.was_maximized
    );

/*      Marble.add_css_provider_from_resource (
                                           "/com/fyralabs/Accelerator/resources/style.css"
    );  */

    this.theme_provider = ThemeProvider.get_default ();

    //  this.header_bar.new_tab_button.clicked.connect (() => {
    //    this.new_tab (null, null);
    //  });

    this.add_actions ();
    this.connect_signals ();

    if (!skip_initial_tab) {
      this.new_tab (command, cwd);
    }

    // remove the blank tab
    this.tab_view.get_first_child ().destroy ();
  }

  private void connect_signals () {
    // this.settings.schema.bind (
    // "fill-tabs",
    // this.tab_bar,
    // "expand-tabs",
    // SettingsBindFlags.GET
    // );

    this.settings.schema.bind (
                               "show-headerbar",
                               this.header_bar_revealer,
                               "reveal-child",
                               SettingsBindFlags.GET
    );

    this.settings.notify["show-menu-button"].connect (
                                                      this.on_decoration_layout_changed
    );

    settings.notify["floating-controls"].connect (() => {
      if (!settings.floating_controls) {
        this.floating_header_bar_revealer.reveal_child = false;
      }
    });

    settings.notify["show-headerbar"].connect (() => {
      if (settings.show_headerbar) {
        this.floating_header_bar_revealer.reveal_child = false;
      }
    });

    settings.notify["window-show-borders"].connect (() => {
      set_css_class (this, "with-borders", settings.window_show_borders);
    });
    set_css_class (this, "with-borders", settings.window_show_borders);

    this.tab_bar.tab_added.connect (() => {
      //  this.active_terminal.grab_focus ();
    });

    // this.tab_view.create_window.connect (() => {
    // var w = this.new_window (null, true);
    // return w.tab_view;
    // });

    this.tab_bar.new_tab_requested.connect (() => {
      this.new_tab (null, null);
    });


    this.tab_bar.close_tab_requested.connect ((tab) => {
      debug ("close tab requested");
      this.tab_bar.remove_tab (tab);
      tab.unrealize ();
      tab.dispose ();
      //  (tab.child as TerminalTab) ? .terminal.exit ();
      //  (tab.child as TerminalTab) ? .terminal.dispose ();
      (tab as TerminalTab) ? .close_request ();
      //  (tab.child as TerminalTab) ? .box.unrealize ();
      //  (tab as TerminalTab) ? .box.dispose ();
      (tab as TerminalTab) ? .box.unparent ();
      (tab as TerminalTab) ? .box.unref ();
      tab.unparent ();
      tab.unref ();

      // if there are no more tabs, close the window
      if (this.tab_bar.n_tabs < 1) {
        this.close ();
      }

      return false;
    });


    this.tab_bar.tab_switched.connect ((old_tab, new_tab) => {
      // make invisible
      print ("tab switched\n");
      if (old_tab != null) {
        old_tab.remove_css_class ("active");
        (old_tab as TerminalTab) ? .box.unparent ();
        (old_tab as TerminalTab) ? .box.visible = false;
      }

      new_tab.add_css_class ("active");
      (new_tab as TerminalTab) ? .box.set_parent (this.tab_view);
      (new_tab as TerminalTab) ? .box.visible = true;
      (new_tab as TerminalTab) ? .terminal.grab_focus ();
      this.active_terminal = (new_tab as TerminalTab) ? .terminal;
    });

    // this.tab_view.close_page.connect ((page) => {
    // (page.child as TerminalTab) ? .destroy ();
    // return false;
    // });

    // Close the window if all tabs were closed
    // this.tab_view.notify["n-pages"].connect (() => {
    // if (this.tab_view.n_pages < 1) {
    // this.close ();
    // }
    // });

    this.tab_view.notify["selected-page"].connect (() => {
      this.on_tab_selected ();
    });

    this.notify["default-width"].connect (() => {
      this.settings.window_width = this.default_width;
    });

    this.notify["default-height"].connect (() => {
      this.settings.window_height = this.default_height;
    });

    this.fullscreen_button.clicked.connect (this.toggle_fullscreen);

    this.show_headerbar_button.clicked.connect (() => {
      this.settings.show_headerbar = true;
      this.floating_header_bar_revealer.reveal_child = false;
    });

    var s = Gtk.Settings.get_default ();
    s.notify["gtk-decoration-layout"].connect (this.on_decoration_layout_changed);

    this.notify["active-terminal"].connect (this.on_active_terminal_changed);

    var c = new Gtk.EventControllerMotion ();
    c.motion.connect ((_, _mouseX, mouseY) => {
      // Ignore mouse motion if standard headerbars are shown or if floating
      // controls are disabled
      if (this.settings.show_headerbar || !this.settings.floating_controls) {
        return;
      }

      var h = this.floating_bar.get_height ();
      var is_shown = this.floating_header_bar_revealer.reveal_child;

      var trigger_area = settings.floating_controls_hover_area;

      bool is_hovering_trigger_area =
        mouseY >= 0 && mouseY <= (is_shown ? h : trigger_area);

      if (is_hovering_trigger_area && !is_shown) {
        // Only schedule animation if there aren't any scheduled
        if (this.waiting_for_floating_hb_animation == 0) {
          // Wait for delay to show floating controls
          this.waiting_for_floating_hb_animation = Timeout.add (
                                                                settings.delay_before_showing_floating_controls,
                                                                () => {
            this.floating_header_bar_revealer.reveal_child = true;
            this.waiting_for_floating_hb_animation = 0;
            return false;
          });
        }
      } else if (
                 !is_hovering_trigger_area &&
                 (is_shown || this.waiting_for_floating_hb_animation != 0)
      ) {
        if (this.waiting_for_floating_hb_animation != 0) {
          Source.remove (this.waiting_for_floating_hb_animation);
          this.waiting_for_floating_hb_animation = 0;
        }
        this.floating_header_bar_revealer.reveal_child = false;
      }
    });

    (this as Gtk.Widget) ? .add_controller (c);

    this.close_request.connect (() => {
      Settings.get_default ().was_fullscreened = this.fullscreened;
      Settings.get_default ().was_maximized = this.maximized;
      return false;
    });
  }

  private void add_actions () {
    var sa = new SimpleAction ("new_tab", null);
    sa.activate.connect (() => {
      this.new_tab (null, null);
    });
    this.add_action (sa);

    sa = new SimpleAction ("edit_preferences", null);
    sa.activate.connect (() => {
      if (preferences_window == null) {
        preferences_window = new PreferencesWindow (this);
        preferences_window.close_request.connect (() => {
          preferences_window = null;
          return false;
        });
      }

      preferences_window.present ();
    });
    this.add_action (sa);

    sa = new SimpleAction ("paste", null);
    sa.activate.connect (() => {
      this.on_paste_activated ();
    });
    this.add_action (sa);

    this.copy_action = new SimpleAction ("copy", null);
    copy_action.activate.connect (() => {
      this.on_copy_activated ();
    });
    this.copy_action.set_enabled (false);
    this.add_action (this.copy_action);

    sa = new SimpleAction ("switch-headerbar-mode", null);
    sa.activate.connect (() => {
      this.settings.show_headerbar = !this.settings.show_headerbar;
    });
    this.add_action (sa);

    sa = new SimpleAction ("fullscreen", null);
    sa.activate.connect (this.toggle_fullscreen);
    this.add_action (sa);

    sa = new SimpleAction ("search", null);
    sa.activate.connect (this.search);
    this.add_action (sa);

    sa = new SimpleAction ("zoom-in", null);
    sa.activate.connect (this.zoom_in);
    this.add_action (sa);

    sa = new SimpleAction ("zoom-out", null);
    sa.activate.connect (this.zoom_out);
    this.add_action (sa);

    sa = new SimpleAction ("zoom-default", null);
    sa.activate.connect (this.zoom_default);
    this.add_action (sa);

    sa = new SimpleAction ("close-tab", null);
    sa.activate.connect (this.close_active_tab);
    this.add_action (sa);

    for (uint i = 1; i < 10; i++) {
      sa = new SimpleAction ("switch-tab-%u".printf (i), null);
      sa.activate.connect (() => {
        this.focus_nth_tab ((int) i);
      });
      this.add_action (sa);
    }

    sa = new SimpleAction ("switch-tab-last", null);
    sa.activate.connect (() => {
      this.focus_nth_tab (-1);
    });
    this.add_action (sa);
  }

  public void search () {
    // (this.tab_view.selected_page ? .child as TerminalTab) ? .search ();
  }

  public void zoom_in () {
    (this.tab_bar.current as TerminalTab) ? .terminal
     .zoom_in ();
  }

  public void zoom_out () {
    (this.tab_bar.current as TerminalTab) ? .terminal
     .zoom_out ();
  }

  public void zoom_default () {
    (this.tab_bar.current as TerminalTab) ? .terminal
     .zoom_default ();
  }

  public void close_active_tab () {
    (this.tab_bar.current ? .child as TerminalTab) ? .close_request ();
  }

  public void new_tab (string? command, string? cwd) {
    var tab = new TerminalTab (this, command, cwd);

    // this.tab_view.child = tab.box;

    // if (this.tab_view == null) {
    // this.tab_view = new He.TabPage(tab);
    // }

    var pos = this.tab_bar.insert_tab (tab, -1);
    this.active_terminal = tab.terminal;
    // if (this.tab_view.name == "accelerator-blank-tab") {
    // this.tab_view.name = "tab-view";
    // this.tab_view.tab.child = this.active_terminal;
    // }


    // check for children in tab_view, and turn them invisible
    if (this.tab_view.tab != null) {
      this.tab_view.tab.visible = false;
    }

    tab.label = command ?? @"tab $(this.tab_bar.n_tabs)";
    tab.notify["title"].connect (() => {
      tab.label = tab.title;
      tab.set_name (tab.title);
    });
    tab.close_request.connect (() => {
      debug ("close request");
      this.tab_bar.close_tab_requested (tab);
      // this.tab_bar.remove_tab (tab);
      //  (this.tab_view.tab as TerminalTab) ? .dispose ();
    });
    this.tab_bar.current = tab;
    this.tab_view.tab = this.tab_bar.current as TerminalTab;
    this.tab_view.show ();
    // this.tab_view.child = tab.box;

    // todo: once tab is closed, remove the terminal session from the tab_view\
    // if it is switched, then make all other tabs invisible
    // CC: @lainsce @lleyton send help
    //  (this.tab_view.tab as TerminalTab) ? .box.set_parent (this.tab_view);
    // tab.box.set_parent (this.tab_view.tab.child);
  }

  private void on_paste_activated () {
    (this.tab_bar.current ? .child as TerminalTab) ? .terminal
     .do_paste_clipboard ();
  }

  private void on_copy_activated () {
    (this.tab_bar.current ? .child as TerminalTab) ? .terminal
     .do_copy_clipboard ();
  }

  private void on_tab_selected () {
    if (this.active_terminal != null) {
      foreach (unowned ulong id in this.active_terminal_signal_handlers) {
        this.active_terminal.disconnect (id);
      }
      this.active_terminal_signal_handlers.remove_range (
                                                         0,
                                                         this.active_terminal_signal_handlers.length
      );
    }
    var terminal = (this.tab_bar.current ? .child as TerminalTab) ? .terminal;
    this.active_terminal = terminal;
    terminal?.grab_focus ();
  }

  private void on_active_terminal_changed () {
    if (this.active_terminal == null) {
      return;
    }

    print ("active terminal changed\n");

    ulong handler;

    this.on_active_terminal_selection_changed ();
    handler = this.active_terminal
       .selection_changed
       .connect (this.on_active_terminal_selection_changed);

    this.active_terminal_signal_handlers.append_val (handler);

    this.on_active_terminal_title_changed ();
    handler = this.active_terminal
       .window_title_changed
       .connect (this.on_active_terminal_title_changed);

    this.active_terminal_signal_handlers.append_val (handler);
  }

  private void on_active_terminal_title_changed () {
    this.active_terminal_title = this.active_terminal.window_title;
  }

  private void on_active_terminal_selection_changed () {
    bool enabled = false;
    if (this.active_terminal ? .get_has_selection ()) {
      enabled = true;
    }
    this.copy_action.set_enabled (enabled);
  }

  private void on_decoration_layout_changed () {
    var layout = Gtk.Settings.get_default ().gtk_decoration_layout;

    debug ("Decoration layout: %s", layout);

    var window_controls_in_end = layout.split (":", 2)[0].contains ("menu");

    this.floating_bar.remove (this.floating_btns);
    this.floating_bar.remove (this.floating_menu_btn);
    if (this.settings.show_menu_button) {
      this.floating_bar.pack_end (this.floating_menu_btn);
    }

    if (window_controls_in_end) {
      this.floating_bar.pack_start (this.floating_btns);
    } else {
      this.floating_bar.pack_end (this.floating_btns);
    }
  }

  private void toggle_fullscreen () {
    if (this.fullscreened) {
      this.unfullscreen ();
    } else {
      this.fullscreen ();
    }
  }

  public Window new_window (string? cwd = null,
                            bool skip_initial_tab = false) {
    var w = new Window (this.application, null, cwd, skip_initial_tab);
    w.show ();
    w.close_request.connect (() => {
      return false;
    });
    return w;
  }

  public void focus_next_tab () {

    var next_tab = this.tab_bar.tabs.next.data;
    if (next_tab != null) {
      this.tab_bar.current = next_tab;
    } else {
      this.tab_bar.current = this.tab_bar.tabs.nth_data (0);
    }
    // if (!this.tab_bar.tabs.next) {

    // this.tab_bar.current = this.tab_bar.tabs.nth (0);
    // }
  }

  public void focus_previous_tab () {
    // if (!this.tab_view.select_previous_page ()) {
    // this.tab_view.set_selected_page (this.tab_view.get_nth_page (this.tab_view.n_pages - 1));
    // }

    var previous_tab = this.tab_bar.tabs.prev.data;
    if (previous_tab != null) {
      this.tab_bar.current = previous_tab;
    } else {
      this.tab_bar.current = this.tab_bar.tabs.last().data;
    }
  }

  public void focus_nth_tab (int index) {
    // if (this.tab_view.n_pages <= 1) {
    // return;
    // }
    // if (index < 0) {
    //// Go to last tab
    // this.tab_view.set_selected_page (
    // this.tab_view.get_nth_page (this.tab_view.n_pages - 1)
    // );
    // return;
    // }
    // if (index > this.tab_view.n_pages) {
    // return;
    // } else {
    // this.tab_view.set_selected_page (this.tab_view.get_nth_page (index - 1));
    // return;
    // }

    var tab = this.tab_bar.tabs.nth_data (index);
    if (tab != null) {
      this.tab_bar.current = tab;
    } else {
      this.tab_bar.current = this.tab_bar.tabs.last ().data;
    }
  }
}
