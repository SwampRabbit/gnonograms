/* Utility functions for gnonograms-elementary
 * Copyright (C) 2010-2017  Jeremy Wootten
 *
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Author:
 *  Jeremy Wootten <jeremy@elementaryos.org>
 */
namespace Gnonograms.Utils {
    public static string[] remove_blank_lines (string[] sa) {
        string[] result = {};

        foreach (string s in sa) {
            string ss = s.strip ();
            if (ss != "") {
                result += ss;
            }
        }

        return result;
    }

    public int[] block_array_from_clue (string s) {
        string[] clues = remove_blank_lines (s.split_set (", "));

        if (clues.length == 0) {
            return {0};
        } else {
            int[] blocks = new int[clues.length];
            int index = 0;
            foreach (string clue in clues) {
                blocks[index++] = int.parse (clue);
            }

            return blocks;
        }
    }

    public int blockextent_from_clue (string s) {
        int[] blocks = block_array_from_clue (s);
        int extent = 0;

        foreach (int block in blocks) {
            extent += block + 1;
        }

        extent--;
        return extent;
    }

    public string block_string_from_cellstate_array(CellState[] cs) {
        StringBuilder sb = new StringBuilder("");
        int count = 0, blocks = 0;
        bool counting = false;

        for (int i = 0; i < cs.length; i++) {
            if (cs[i] == CellState.EMPTY) {
                if (counting) {
                    sb.append (count.to_string() + BLOCKSEPARATOR);
                    counting = false;
                    count = 0;
                    blocks++;
                }
            } else if (cs[i] == CellState.FILLED) {
                counting = true;
                count++;
            } else {
                return "?";
            }
        }

        if (counting) {
            sb.append (count.to_string () + BLOCKSEPARATOR);
            blocks++;
        }

        if (blocks == 0) {
            sb.append ("0");
        } else {
            sb.truncate (sb.len - BLOCKSEPARATOR.length);
        }

        return sb.str;
    }

    public CellState[] cellstate_array_from_string (string s) {
        CellState[] cs = {};
        string[] data = remove_blank_lines (s.split_set (BLOCKSEPARATOR));

        for (int i = 0; i < data.length; i++) {
            cs += (CellState)(int.parse (data[i]).clamp (0, 6));
        }

        return cs;
    }

    public string string_from_cellstate_array (CellState[] cs) {
        if (cs == null) {
            return "";
        }

        StringBuilder sb = new StringBuilder();

        for (int i = 0; i < cs.length; i++) {
            sb.append (((int)cs[i]).to_string ());
            sb.append (" ");
        }

        return sb.str;
    }

    public string hex_string_from_cellstate_array (CellState[] sa) {
        StringBuilder sb = new StringBuilder ("");
        int length = sa.length;
        int e = 0, m = 1, count = 0;

        for (int i = length - 1; i >= 0; i--) {
            count++;
            e += ((int)(sa[i]) - 1) * m;
            m = m * 2;
            if (count == 4 || i == 0) {
                sb.prepend (int2hex (e));
                count = 0; m = 1; e = 0;
            }
        }

        return sb.str;
    }

    private const string[] letters = {"A","B","C","D","E","F"};
    private string int2hex (int i) {
        if (i > 15 || i < 0) {
            return "X";
        } else if (i <= 9) {
            return i.to_string ();
        } else {
            return letters[i - 10];
        }
    }

    public void process_events()
    {
        while (Gtk.events_pending())
        {
            Gtk.main_iteration_do(false);
        }
    }

    public static  int show_dlg(string msg, Gtk.MessageType type, Gtk.ButtonsType buttons)
    {
        //stdout.printf("Show dlg\n");
        var dialog=new Gtk.MessageDialog(
            null,
            Gtk.DialogFlags.MODAL,
            type,
            buttons,
            "%s",msg);
        dialog.set_position(Gtk.WindowPosition.MOUSE);
        int response=dialog.run();
        dialog.destroy();
        return response;

    }

    public static void show_info_dialog (string msg) {
        show_dlg (msg, Gtk.MessageType.INFO, Gtk.ButtonsType.CLOSE);
    }

    public static void show_warning_dialog (string msg) {
        show_dlg (msg, Gtk.MessageType.WARNING, Gtk.ButtonsType.CLOSE);
    }

    public static void show_error_dialog (string msg) {
        show_dlg (msg, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE);
    }

    public static bool show_confirm_dialog(string msg) {
        return show_dlg (msg ,Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO)==Gtk.ResponseType.YES;
    }

}
