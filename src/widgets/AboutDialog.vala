/* AboutDialog.vala
 *
 * Copyright 2021-2022 Paulo Queiroz <pvaqueiroz@gmail.com>
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
  public He.AboutWindow create_about_dialog (Window parent) {
    string[] developers = {
      "Cappy Ishihara"
    };
    string[] translators = {
    };
    var window = new He.AboutWindow (parent,
                                     APP_NAME,
                                     APP_ID,
                                     VERSION,
                                     APP_ID,
                                     null,
                                     "https://github.com/tau-OS/accelerator/issues",
                                     "https://github.com/tau-OS/accelerator",
                                     translators,
                                     developers,
                                     2023,
                                     He.AboutWindow.Licenses.GPLV3, He.Colors.NONE);
    if (DEVEL) {
      window.add_css_class ("devel");
    }

    parent.main_overlay.add_overlay (window);
    return window;
  }

  private string get_debug_information () {
    var app = "Accelerator: %s\n".printf (VERSION);
    var backend = "Backend: %s\n".printf (get_gtk_backend ());
    var renderer = "Renderer: %s\n".printf (get_renderer ());
    var flatpak = get_flatpak_info ();
    var os_info = get_os_info ();
    var libs = get_libraries_info ();

    return app + backend + renderer + flatpak + os_info + libs;
  }

  private string get_gtk_backend () {
    var display = Gdk.Display.get_default ();
    switch (display.get_class ().get_name ()) {
    case "GdkX11Display": return "X11";
    case "GdkWaylandDisplay": return "Wayland";
    case "GdkBroadwayDisplay": return "Broadway";
    case "GdkWin32Display": return "Windows";
    case "GdkMacosDisplay": return "macOS";
    default: return display.get_class ().get_name ();
    }
  }

  private string get_renderer () {
    var display = Gdk.Display.get_default ();
    var surface = new Gdk.Surface.toplevel (display);
    var renderer = Gsk.Renderer.for_surface (surface);

    var name = renderer.get_class ().get_name ();
    renderer.unrealize ();

    switch (name) {
    case "GskVulkanRenderer": return "Vulkan";
    case "GskGLRenderer": return "GL";
    case "GskCairoRenderer": return "Cairo";
    default: return name;
    }
  }

  static KeyFile? flatpak_keyfile = null;

  private string ? get_flatpak_value (string group, string key) {
    try {
      if (flatpak_keyfile == null) {
        flatpak_keyfile = new KeyFile ();
        flatpak_keyfile.load_from_file ("/.flatpak-info", 0);
      }
      return flatpak_keyfile.get_string (group, key);
    } catch (Error e) {
      warning ("%s", e.message);
      return null;
    }
  }

  private string get_flatpak_info () {
    if (!is_flatpak ()) {
      return "Flatpak: No\n";
    }

    string res = "Flatpak:\n";

    res += " - Runtime: %s\n".printf (get_flatpak_value ("Application", "runtime"));
    res += " - Runtime commit: %s\n".printf (get_flatpak_value ("Instance", "runtime-commit"));
    res += " - Arch: %s\n".printf (get_flatpak_value ("Instance", "arch"));
    res += " - Flatpak version: %s\n".printf (get_flatpak_value ("Instance", "flatpak-version"));
    res += " - Devel: %s\n".printf (get_flatpak_value ("Instance", "devel") != null ? "yes" : "no");

    return res;
  }

  private string get_libraries_info () {
    string res = "Libraries:\n";

    res += " - Gtk: %d.%d.%d\n".printf (Gtk.MAJOR_VERSION, Gtk.MINOR_VERSION, Gtk.MICRO_VERSION);
    res += " - VTE: %d.%d.%d\n".printf (Vte.MAJOR_VERSION, Vte.MINOR_VERSION, Vte.MICRO_VERSION);
    res += " - Helium: 1.0\n";
    res += " - JSON-glib: %s\n".printf (Json.VERSION_S);

    return res;
  }

  private string get_os_info () {
    string res = "OS:\n";

    res += " - Name: %s\n".printf (Environment.get_os_info (OsInfoKey.NAME));
    res += " - Version: %s\n".printf (Environment.get_os_info (OsInfoKey.VERSION));

    return res;
  }
}