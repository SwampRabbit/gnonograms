/* View class for gnonograms-elementary - displays user interface
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

namespace Gnonograms {
/*** The View class manages the header, clue label widgets and the drawing widget under instruction
   * from the controller. It signals user interaction to the controller.
***/
public class View : Gtk.ApplicationWindow {
/**PUBLIC**/
    public signal void random_game_request ();
    public signal uint check_errors_request ();
    public signal void rewind_request ();
    public signal bool next_move_request ();
    public signal bool previous_move_request ();
    public signal void save_game_request ();
    public signal void save_game_as_request ();
    public signal void open_game_request ();
    public signal void solve_this_request ();
    public signal void restart_request ();
    public signal void resized (Dimensions dim);
    public signal void moved (Cell cell);
    public signal void game_state_changed (GameState gs);

    public Model model { get; construct; }

    public string header_title {
        get {
            return header_bar.title;
        }

        set {
            header_bar.title = value;
        }
    }

    public Dimensions dimensions {
        get {
            return _dimensions;
        }

        set {
            if (value != _dimensions) {
                _dimensions = value;
                row_clue_box.dimensions = dimensions;
                column_clue_box.dimensions = dimensions;
                fontheight = get_default_fontheight_from_dimensions ();
                app_menu.row_val = dimensions.height;
                app_menu.column_val = dimensions.width;
                resized (dimensions); /* Controller will queue draw after resizing model */
            }
        }
    }

    public Difficulty grade {
        get {
            return _grade;
        }

        set {
            _grade = value;
            app_menu.grade_val = (uint)grade;
        }
    }

    public uint rows {
        get {
            return dimensions.height;
        }
    }

    public uint cols {
        get {
            return dimensions.width;
        }
    }

    public double fontheight {
        get {
            return _fontheight;
        }


        set {
            if (value < MINFONTSIZE || value > MAXFONTSIZE) {
                return;
            }

            _fontheight = value;
            row_clue_box.fontheight = _fontheight;
            column_clue_box.fontheight = _fontheight;
            /* Allow space for lengthening clues on game generation  (typical longest clue) */
            column_clue_box.set_size_request(-1, (int)(fontheight * rows * 0.75));
            row_clue_box.set_size_request((int)(fontheight * cols * 0.5), -1);
        }
    }

    public GameState game_state {
        get {
            return _game_state;
        }

        set {
            _game_state = value;
            mode_switch.mode = value;
            cell_grid.game_state = value;

            if (value == GameState.SETTING) {
                header_bar.subtitle = _("Setting");
                restart_button.tooltip_text = _("Clear canvas");
                update_labels_from_model ();
            } else {
                header_bar.subtitle = _("Solving");
                restart_button.tooltip_text = _("Restart solving");
            }
        }
    }

    public bool can_go_back {
        set {
            check_correct_button.sensitive = value && is_solving;
        }
    }

    public View (Model _model) {
        Object (
            model: _model
        );
    }

    construct {
        resizable = false;
        drawing_with_state = CellState.UNDEFINED;

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/com/gnonograms/icons");

        header_bar = new Gtk.HeaderBar ();
        header_bar.set_has_subtitle (true);
        header_bar.set_show_close_button (true);

        title = _("Gnonograms for Elementary");

        load_game_button = new Gtk.Button ();
        var img = new Gtk.Image.from_icon_name ("document-open-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        load_game_button.image = img;
        load_game_button.tooltip_text = _("Load a Game from File");

        save_game_button = new Gtk.Button ();
        img = new Gtk.Image.from_icon_name ("document-save-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        save_game_button.image = img;
        save_game_button.tooltip_text = _("Save a Game to File");

        random_game_button = new Gtk.Button ();
        img = new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        random_game_button.image = img;
        random_game_button.tooltip_text = _("Generate a Random Game");

        check_correct_button = new Gtk.Button ();
        img = new Gtk.Image.from_icon_name ("media-seek-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        check_correct_button.image = img;
        check_correct_button.tooltip_text = _("Undo Any Errors");
        check_correct_button.sensitive = false;

        restart_button = new Gtk.Button ();
        img = new Gtk.Image.from_icon_name ("view-refresh", Gtk.IconSize.LARGE_TOOLBAR);
        restart_button.image = img;
        restart_button.sensitive = true;

        auto_solve_button = new Gtk.Button ();
        img = new Gtk.Image.from_icon_name ("system-run", Gtk.IconSize.LARGE_TOOLBAR);
        auto_solve_button.image = img;
        auto_solve_button.tooltip_text = _("Solve by Computer");
        auto_solve_button.sensitive = true;

        app_menu = new AppMenu ();
        mode_switch = new ViewModeButton ();

        header_bar.pack_start (random_game_button);
        header_bar.pack_start (load_game_button);
        header_bar.pack_start (save_game_button);
        header_bar.pack_start (check_correct_button);
        header_bar.pack_end (app_menu);
        header_bar.pack_end (mode_switch);
        header_bar.pack_end (auto_solve_button);
        header_bar.pack_end (restart_button);
        set_titlebar (header_bar);

        overlay = new Gtk.Overlay ();
        toast = new Granite.Widgets.Toast ("");

        toast.set_default_action (null);
        toast.halign = Gtk.Align.START;
        toast.valign = Gtk.Align.START;
        overlay.add_overlay (toast);

        progress_popover = new Gtk.Popover (auto_solve_button);
        progress_popover.modal = true;
        progress_popover.position = Gtk.PositionType.BOTTOM;

        var progress_grid = new Gtk.Grid ();
        progress_popover.add (progress_grid);

        progress_bar = new Gtk.ProgressBar ();
        progress_bar.show_text = true;
        progress_bar.pulse_step = 1;

        progress_grid.add (progress_bar);

        var progress_cancel_button = new Gtk.Button ();
        img = new Gtk.Image.from_icon_name ("process-stop-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        img.set_tooltip_text (_("Cancel solving"));
        progress_cancel_button.image = img;

        progress_grid.attach_next_to (progress_cancel_button, progress_bar, Gtk.PositionType.RIGHT, 1, 1);
        row_clue_box = new LabelBox (Gtk.Orientation.VERTICAL);
        column_clue_box = new LabelBox (Gtk.Orientation.HORIZONTAL);
        cell_grid = new CellGrid (model);
        main_grid = new Gtk.Grid ();

        main_grid.attach (cell_grid, 1, 1, 1, 1);
        cell_grid.cursor_moved.connect (on_grid_cursor_moved);
        cell_grid.leave_notify_event.connect (on_grid_leave);
        cell_grid.button_press_event.connect (on_grid_button_press);
        cell_grid.button_release_event.connect (on_grid_button_release);
        cell_grid.scroll_event.connect (on_scroll_event);

        main_grid.row_spacing = 0;
        main_grid.column_spacing = 0;
        main_grid.row_spacing = 0;
        main_grid.border_width = 0;
        main_grid.attach (row_clue_box, 0, 1, 1, 1); /* Clues for rows */
        main_grid.attach (column_clue_box, 1, 0, 1, 1); /* Clues for columns */
        overlay.add (main_grid);
        add (overlay);

        /* Connect signal handlers */
        realize.connect (() => {
            update_labels_from_model ();
            fontheight = get_default_fontheight_from_dimensions ();
        });

        mode_switch.mode_changed.connect (on_mode_switch_changed);

        key_press_event.connect (on_key_press_event);
        key_release_event.connect (on_key_release_event);

        app_menu.apply.connect (on_app_menu_apply);

        load_game_button.clicked.connect (on_load_game_button_clicked);
        save_game_button.clicked.connect (on_save_game_button_clicked);
        save_game_button.button_release_event.connect (on_save_game_button_release_event);
        random_game_button.clicked.connect (on_random_game_button_clicked);
        check_correct_button.clicked.connect (on_check_button_pressed);
        restart_button.clicked.connect (on_restart_button_pressed);
        auto_solve_button.clicked.connect (on_auto_solve_button_pressed);
    }

    public void blank_labels () {
        row_clue_box.blank_labels ();
        column_clue_box.blank_labels ();
    }

    public string[] get_row_clues () {
        return row_clue_box.get_clues ();
    }

    public string[] get_col_clues () {
        return column_clue_box.get_clues ();
    }


    public void update_labels_from_string_array (string[] clues, bool is_column) {
        var clue_box = is_column ? column_clue_box : row_clue_box;
        var lim = is_column ? cols : rows;

        for (int i = 0; i < lim; i++) {
            clue_box.update_label_text (i, clues[i]);
        }
    }

    public void update_labels_from_model () {
        for (int r = 0; r < rows; r++) {
            row_clue_box.update_label_text (r, model.get_label_text (r, false));
        }

        for (int c = 0; c < cols; c++) {
            column_clue_box.update_label_text (c, model.get_label_text (c, true));
        }
    }

    public void make_move (Move m) {
        move_cursor_to (m.cell);
        mark_cell (m.cell);

        queue_draw ();
    }

    public void send_notification (string text) {
        toast.title = text;
        toast.send_notification ();
        Timeout.add_seconds (NOTIFICATION_TIMEOUT_SEC, () => {
            toast.reveal_child = false;
            return false;
        });
    }

    public void show_solving () {
        progress_bar.text = (_("Solving"));
        progress_popover.set_relative_to (auto_solve_button);
        schedule_show_progress ();
    }

    public void show_generating () {
        progress_bar.text = (_("Generating"));
        progress_popover.set_relative_to (random_game_button);
        schedule_show_progress ();
    }

    public void hide_progress () {
        if (progress_timeout_id > 0) {
            Source.remove (progress_timeout_id);
            progress_timeout_id = 0;
        } else {
            progress_popover.hide ();
        }
    }

    public void pulse_progress () {
        progress_bar.pulse ();
    }

    /**PRIVATE**/
    private const uint NOTIFICATION_TIMEOUT_SEC = 2;
    private const uint PROGRESS_DELAY_MSEC = 500;

    private Gnonograms.LabelBox row_clue_box;
    private Gnonograms.LabelBox column_clue_box;
    private CellGrid cell_grid;
    private Gtk.HeaderBar header_bar;
    private AppMenu app_menu;
    private Gtk.Grid main_grid;
    private Gtk.Overlay overlay;
    private Gtk.Popover progress_popover;
    private Gtk.ProgressBar progress_bar;
    private Granite.Widgets.Toast toast;
    private ViewModeButton mode_switch;
    private Gtk.Button load_game_button;
    private Gtk.Button save_game_button;
    private Gtk.Button random_game_button;
    private Gtk.Button check_correct_button;
    private Gtk.Button auto_solve_button;
    private Gtk.Button restart_button;

    private bool control_pressed = false;
    private bool other_mod_pressed = false;
    private bool shift_pressed = false;
    private bool only_control_pressed = false;

    /* Backing variables, not to be set directly */
    private Dimensions _dimensions;
    private double _fontheight;
    private Difficulty _grade = 0;
    private GameState _game_state;
    /* ----------------------------------------- */

    private CellState drawing_with_state;

    private bool is_solving {
        get {
            return game_state == GameState.SOLVING;
        }
    }

    private unowned Cell current_cell {
        get {
            return cell_grid.current_cell;
        }
        set {
            cell_grid.current_cell = value;
        }
    }

    private bool mods {
        get {
            return control_pressed || other_mod_pressed;
        }
    }

    private double get_default_fontheight_from_dimensions () {
        double max_h, max_w;
        Gdk.Rectangle rect;

        if (get_window () == null) {
            return 0;
        }

#if HAVE_GDK_3_22
        var display = Gdk.Display.get_default();
        var monitor = display.get_monitor_at_window (get_window ());
        monitor.get_geometry (out rect);
#else
        var monitor = screen.get_monitor_at_window (get_window ());
        screen.get_monitor_geometry (monitor, out rect);
#endif
        max_h = (double)(rect.height) / ((double)(rows * 2));
        max_w = (double)(rect.width) / ((double)(cols * 2));

        return double.min (max_h, max_w) / 2;
    }


    private void update_labels_for_cell (Cell cell) {
        if (cell == NULL_CELL) {
            return;
        }

        row_clue_box.update_label_text (cell.row, model.get_label_text (cell.row, false));
        column_clue_box.update_label_text (cell.col, model.get_label_text (cell.col, true));
    }

    private void highlight_labels (Cell c, bool is_highlight) {
        /* If c is NULL_CELL then will unhighlight all labels */
        row_clue_box.highlight (c.row, is_highlight);
        column_clue_box.highlight (c.col, is_highlight);
    }

    private void make_move_at_cell (CellState state = drawing_with_state, Cell target = current_cell) {
        if (target == NULL_CELL) {
            return;
        }

        if (state != CellState.UNDEFINED) {
            Cell cell = target.clone ();
            cell.state = state;
            moved (cell);
            mark_cell (cell);
            cell_grid.highlight_cell (cell, true);
        }
    }

    private void move_cursor_to (Cell to, Cell from = current_cell) {
        highlight_labels  (from, false);
        highlight_labels (to, true);
        current_cell = to;
    }

    private void mark_cell (Cell cell) {
        if (!is_solving && cell.state != CellState.UNDEFINED) {
            update_labels_for_cell (cell);
        }
    }

    private void handle_arrow_keys (string keyname) {
        int r = 0; int c = 0;
        switch (keyname) {
            case "UP":
                    r = -1;
                    break;
            case "DOWN":
                    r = 1;
                    break;
            case "LEFT":
                    c = -1;
                    break;
            case "RIGHT":
                    c = 1;
                    break;

            default:
                    return;
        }

        cell_grid.move_cursor_relative (r, c);
    }

    private void handle_pen_keys (string keyname) {
        if (mods) {
            return;
        }

        switch (keyname) {
            case "F":
                drawing_with_state = CellState.FILLED;
                break;

            case "E":
                drawing_with_state = CellState.EMPTY;
                break;

            case "X":
                if (is_solving) {
                    drawing_with_state = CellState.UNKNOWN;
                    break;
                } else {
                    return;
                }

            default:
                    return;
        }

        make_move_at_cell ();
    }

    private uint progress_timeout_id = 0;
    private void schedule_show_progress () {
        hide_progress ();

        progress_timeout_id = Timeout.add (PROGRESS_DELAY_MSEC, () => {
            progress_popover.show_all ();
            progress_timeout_id = 0;
            return false;
        });
    }

    /*** Signal handlers ***/
    private void on_grid_cursor_moved (Cell from, Cell to) {
        highlight_labels (from, false);
        highlight_labels (to, true);
        current_cell = to;
        make_move_at_cell ();
    }

    private bool on_grid_leave () {
        row_clue_box.unhighlight_all ();
        column_clue_box.unhighlight_all ();
        return false;
    }

    private bool on_grid_button_press (Gdk.EventButton event) {
        switch (event.button) {
            case Gdk.BUTTON_PRIMARY:
            case Gdk.BUTTON_MIDDLE:
                if (event.type == Gdk.EventType.@2BUTTON_PRESS || event.button == Gdk.BUTTON_MIDDLE) {
                    if (is_solving) {
                        drawing_with_state = CellState.UNKNOWN;
                        break;
                    } else {
                        return true;
                    }
                } else {
                    drawing_with_state = CellState.FILLED;
                }
                break;

            case Gdk.BUTTON_SECONDARY:
                drawing_with_state = CellState.EMPTY;
                break;

            default:
                return false;
        }

        make_move_at_cell ();
        return true;
    }

    private bool on_grid_button_release () {
        drawing_with_state = CellState.UNDEFINED;
        return true;
    }

    /** With Control pressed, zoom using the fontsize.  Else, if button is down (drawing)
      * draw a straight line in the scroll direction.
    **/
    private bool on_scroll_event (Gdk.EventScroll event) {
        set_mods (event.state);

        if (control_pressed) {

            switch (event.direction) {
                case Gdk.ScrollDirection.UP:
                    fontheight -= 1.0;
                    break;

                case Gdk.ScrollDirection.DOWN:
                    fontheight += 1.0;
                    break;

                default:
                    break;
            }

            return true;

        } else if (drawing_with_state != CellState.UNDEFINED) {

            switch (event.direction) {
                case Gdk.ScrollDirection.UP:
                    handle_arrow_keys ("UP");
                    break;

                case Gdk.ScrollDirection.DOWN:
                    handle_arrow_keys ("DOWN");
                    break;

                case Gdk.ScrollDirection.LEFT:
                    handle_arrow_keys ("LEFT");
                    break;

                case Gdk.ScrollDirection.RIGHT:
                    handle_arrow_keys ("RIGHT");
                    break;

                default:
                    return false;
            }

            /* Cause mouse pointer to follow current cell */
            int window_x, window_y;
            double x = (current_cell.col + 0.5) * cell_grid.cell_width;
            double y = (current_cell.row + 0.5) * cell_grid.cell_height;

            cell_grid.get_window ().get_root_coords ((int)x, (int)y, out window_x, out window_y);
            event.device.warp (screen, window_x, window_y);

            return true;
        }

        return false;
    }

    private bool on_key_press_event (Gdk.EventKey event) {
        /* TODO (if necessary) ignore key autorepeat */
        if (event.is_modifier == 1) {
            return true;
        }

        set_mods (event.state);
        var name = (Gdk.keyval_name (event.keyval)).up();

        switch (name) {
            case "UP":
            case "DOWN":
            case "LEFT":
            case "RIGHT":
                handle_arrow_keys (name);
                break;

            case "F":
            case "E":
            case "X":
                handle_pen_keys (name);
                break;

            case "1":
            case "2":
                if (only_control_pressed) {
                    game_state = name == "1" ? GameState.SETTING : GameState.SOLVING;
                }

                break;

            case "MINUS":
            case "KP_SUBTRACT":
            case "EQUAL":
            case "PLUS":
            case "KP_ADD":
                if (only_control_pressed) {
                    if (name == "MINUS" || name == "KP_SUBTRACT") {
                        fontheight -= 1.0;
                    } else {
                        fontheight += 1.0;
                    }
                }

                break;

            case "R":
                if (only_control_pressed) {
                    random_game_request ();
                }

                break;

            case "S":
                if (only_control_pressed) {
                    if (shift_pressed) {
                        save_game_as_request ();
                    } else {
                        save_game_request ();
                    }
                }

                break;

            case "O":
                if (only_control_pressed) {
                    open_game_request ();
                }

                break;

            default:
                return false;
        }
        return true;
    }

    private bool on_key_release_event (Gdk.EventKey event) {
        var name = (Gdk.keyval_name (event.keyval)).up();

        switch (name) {
            case "F":
            case "E":
            case "X":
                drawing_with_state = CellState.UNDEFINED;
                break;

            default:
                return false;
        }

        return true;
    }

    private void set_mods (uint state) {
        var mods = (state & Gtk.accelerator_get_default_mod_mask ());
        control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
        other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
        shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
        only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */
    }

    private void on_mode_switch_changed (Gtk.Widget widget) {
        game_state = widget.get_data ("mode");
        game_state_changed (game_state);
    }

    private void on_save_game_button_clicked () {
        if (shift_pressed) {
            save_game_as_request ();
        } else {
            save_game_request ();
        }
    }

    private bool on_save_game_button_release_event (Gdk.EventButton event) {
        set_mods (event.state);
        return false;
    }

    private void on_load_game_button_clicked () {
        open_game_request ();
    }

    private void on_random_game_button_clicked () {
        random_game_request ();
    }

    private void on_check_button_pressed () {
        var errors = check_errors_request ();

        if (errors > 0) {
            send_notification (
                (ngettext (_("%u error found"), _("%u errors found"), errors)).printf (errors)
            );
        } else {
            send_notification (_("No errors"));
        }

        if (errors > 0) {
            rewind_request ();
        }
    }

    private void on_auto_solve_button_pressed () {
        solve_this_request ();
    }

    private void on_restart_button_pressed () {
        restart_request ();
    }

    private void on_app_menu_apply () {
        grade = (Difficulty)(app_menu.grade_val);
        var rows = app_menu.row_val;
        var cols = app_menu.column_val;

        dimensions = {cols, rows};
    }
}
}
