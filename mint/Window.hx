package mint;

import mint.Control;
import mint.Label;

import mint.types.Types;
import mint.core.Signal;
import mint.core.Macros.*;


/** Options for constructing a window */
typedef WindowOptions = {

    > ControlOptions,

        /** The title of the window to display as a label */
    @:optional var title: String;
        /** The text size for the title text */
    @:optional var text_size: Float;
        /** Whether or not the window can be moved by it's title bar */
    @:optional var moveable: Bool;
        /** Whether or not the window can be closed by the top right corner */
    @:optional var closable: Bool;
        /** Whether or not the window can be resized by it's bottom right corner*/
    @:optional var resizable: Bool;
        /** Whether or not the window is focusable (bring to front on click) */
    @:optional var focusable: Bool;
        /** Whether or not the window is collapsible */
    @:optional var collapsible: Bool;

} //WindowOptions


@:allow(mint.render.Renderer)
class Window extends Control {

    public var title : Label;
    public var close_button : Label;
    public var resize_handle : Control;
    public var collapse_handle : Control;

    public var closable : Bool = true;
    public var focusable : Bool = true;
    public var moveable : Bool = true;
    public var resizable : Bool = true;
    public var collapsible : Bool = false;

    public var onclose : Signal<Void->Bool>;
    public var oncollapse : Signal<Bool->Void>;

    var dragging : Bool = false;
    var drag_x : Float = 0;
    var drag_y : Float = 0;

    var options : WindowOptions;
    var ready = false;

    public function new( _options:WindowOptions ) {

        options = _options;
        onclose = new Signal();
        oncollapse = new Signal();

        def(options.name, 'window');
        def(options.mouse_input, true);

        super(options);

        moveable = def(options.moveable, true);
        resizable = def(options.resizable, true);
        closable = def(options.closable, true);
        focusable = def(options.focusable, true);
        collapsible = def(options.collapsible, false);

        resize_handle = new Control({
            parent : this,
            x: w-24, y: h-24, w: 24, h: 24,
            name : name + '.resize_handle',
            internal_visible: options.visible
        });

        resize_handle.mouse_input = resizable;
        resize_handle.onmousedown.listen(on_resize_down);
        resize_handle.onmouseup.listen(on_resize_up);

            //create the title label
        title = new Label({
            parent : this,
            x: 2, y: 2, w: w - 4, h: 22,
            text: options.title,
            align : TextAlign.center,
            align_vertical : TextAlign.center,
            text_size: options.text_size,
            options: options.options.label,
            name: name + '.titlelabel',
            internal_visible: options.visible
        });

            //create the close label
        close_button = new Label({
            parent : this,
            x: w - 24, y: 2, w: 22, h: 22,
            text:'x',
            align : TextAlign.center,
            align_vertical : TextAlign.center,
            text_size: options.text_size,
            options: options.options.close_button,
            name : name + '.closelabel',
            internal_visible: options.visible
        });

        ready = true;

        close_button.mouse_input = closable;

        if(!closable) {
            close_button.visible = false;
        } else {
            close_button.onmousedown.listen(function(_,_) {
                on_close();
            });
        }
        
        collapse_handle = new Control({
            parent : this,
            x: closable ? w - 48 : w - 24, y: 2, w: 22, h: 22,
            name : name + '.collapselabel',
            internal_visible: options.visible
        });

        collapse_handle.mouse_input = collapsible;

        if(!collapsible) {
            collapse_handle.visible = false;
        } else {
            collapse_handle.onmousedown.listen(on_collapse);
        }

        renderer = rendering.get( Window, this );

        oncreate.emit();

    } //new

    var resizing = false;
    var resize_x = 0.0;
    var resize_y = 0.0;

    function on_resize_up(e:MouseEvent, _) {

        if(!resizable) return;
        if(!collapsed) return;

        resizing = false;
        canvas.dragged = null;

    } //on_resize_up

    function on_resize_down(e:MouseEvent, _) {

        if(!resizable) return;
        if(!collapsed) return;
        if(resizing) return;

        resizing = true;
        resize_x = e.x;
        resize_y = e.y;
        canvas.dragged = resize_handle;

    } //on_resize_down

    var collapsed = false;
    var pre_h:Float = 0.0;
    var pre_h_min:Float = 0.0;
    var pre_resize:Bool = true;

    function on_collapse(e:MouseEvent, _) {

        if(!collapsible) return;

        collapsed = !collapsed;

        if(collapsed == true) {
            pre_resize = resize_handle.visible;
            pre_h = h;
            pre_h_min = h_min;

            for(child in children) {
                if(child == title) continue;
                if(child == collapse_handle) continue;
                if(child == close_button) continue;
                child.set_visible_only(false);
            }

            h_min = title.h+6;
            h = title.h;
        } else {
            for(child in children) {
                if(child == title) continue;
                if(child == collapse_handle) continue;
                if(child == close_button) continue;
                child.set_visible_only(true);
            }

            h_min = pre_h_min;
            h = pre_h;
        }

        oncollapse.emit(collapsed);

    } //on_collapse

    function on_close() {

        onclose.emit();

        if(closable) {
            close();
        }

    } //on_close

    public function close() {

        visible = false;

    } //close

    public function open() {

        visible = true;

    } //open

    override public function add(child:Control) {

        super.add(child);

            //readd so it's always above
        if(ready && child != resize_handle) {
            add(resize_handle);
        }

    }

    public override function mousemove(e:MouseEvent)  {

        if(resizing) {

            var _dx = e.x - resize_x;
            var _dy = e.y - resize_y;

            var ww = w + _dx;
            var hh = h + _dy;

            var resized = false;

            if(ww >= w_min || ww <= w_max) {
                resize_x = e.x;
                resized = true;
            }

            if(hh >= h_min || hh <= h_max) {
                resize_y = e.y;
                resized = true;
            }

            if(resized) set_size(ww, hh);

        } else if(dragging) {

            var _dx = e.x - drag_x;
            var _dy = e.y - drag_y;

            drag_x = e.x;
            drag_y = e.y;

            set_pos(x + _dx, y + _dy);

        } else { //dragging

            super.mousemove(e);

        }

    } //onmousemove


    public override function mousedown(e:MouseEvent)  {

        if(close_button.contains(e.x, e.y) && closable) return;

        var in_title = title.contains(e.x, e.y);

        if(!in_title) {
            super.mousedown(e);
        }

        if(focusable) canvas.bring_to_front(this);

            if(!dragging && moveable) {
                if( in_title ) {
                    dragging = true;
                    drag_x = e.x;
                    drag_y = e.y;
                    canvas.dragged = this;
                } //if inside title bounds
            } //!dragging

    } //onmousedown

    public override function mouseup(e:MouseEvent) {

        super.mouseup(e);

        if(dragging) {
            dragging = false;
            canvas.dragged = null;
        } //dragging

    } //mouseup

    override function bounds_changed(_dx:Float=0.0, _dy:Float=0.0, _dw:Float=0.0, _dh:Float=0.0) {

        super.bounds_changed(_dx, _dy, _dw, _dh);

        if(close_button != null) close_button.x_local = w - 24;
        if(title != null) title.w = w - 4;
        if(resize_handle != null) resize_handle.set_pos(x + w - 24, y + h - 24);

    } //bounds_changed

}