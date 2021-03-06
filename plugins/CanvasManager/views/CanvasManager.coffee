#
class CanvasManager extends View
    # mandatory params :
    #  - el; laceholder
    #  - items:
    # optionnal params :
    #  - selected_items
    #  - selected_entities
    #  - pre_selected_entities
    #  - undo_manager
    #  - allow_gl
    constructor: ( params ) ->
        for key, val of params
            @[ key ] = val
            
        if not @items?
            @items = new Lst
        if not @cam?
            @cam = new Cam
        if not @selected_items?
            @selected_items = new Lst
        if not @selected_entities?
            @selected_entities = new Lst
        if not @pre_selected_entities?
            @pre_selected_entities = new Lst
        if not @allow_gl?
            @allow_gl = false
        if not @time?
            @time = 0
            
        super [ @items, @cam, @selected_entities, @pre_selected_entities, @selected_items ]

        @canvas = new_dom_element
            nodeName  : "canvas"
            parentNode: @el
            style     :
                position: "absolute"
                top     : 0
                bottom  : 0
                left    : 0
                right   : 0

        # events
        @canvas.onmousedown  = ( evt ) => @_img_mouse_down evt
        @canvas.onmouseup    = ( evt ) => @_img_mouse_up evt
        @canvas.onmousewheel = ( evt ) => @_img_mouse_wheel evt
        @canvas.onmouseout   = ( evt ) => @_img_mouse_out evt
        @canvas.onmousemove  = ( evt ) => @_mouse_move evt
        @canvas.ondblclick   = ( evt ) => @_dbl_click evt
        @canvas.addEventListener?( "DOMMouseScroll", @canvas.onmousewheel, false )

        # drawing context
        @_init_ctx @allow_gl

        #
        @click_fun = [] # called if mouse down and up without move

    onchange: ->
        @draw()

    #
    bounding_box: ->
        get_min_max = ( item, x_min, x_max ) ->
            if item.update_min_max?
                item.update_min_max x_min, x_max
            else if item.sub_canvas_items?
                for sub_item in item.sub_canvas_items()
                    get_min_max sub_item, x_min, x_max
                    
        x_min = [ +1e40, +1e40, +1e40 ]
        x_max = [ -1e40, -1e40, -1e40 ]
        for item in @items
            get_min_max item, x_min, x_max
        if x_min[ 0 ] == +1e40
            return [ [ -1, -1, -1 ], [ 1, 1, 1 ] ]
        return [ x_min, x_max ]
        
    # 
    fit: ->
        b = @bounding_box()
        
        @cam.O.set [
            0.5 * ( b[ 1 ][ 0 ] + b[ 0 ][ 0 ] ),
            0.5 * ( b[ 1 ][ 1 ] + b[ 0 ][ 1 ] ), 
            0.5 * ( b[ 1 ][ 2 ] + b[ 0 ][ 2 ] )
        ]
        @cam.d.set Math.max(
            1.5 * ( b[ 1 ][ 0 ] - b[ 0 ][ 0 ] ),
            1.5 * ( b[ 1 ][ 1 ] - b[ 0 ][ 1 ] ), 
            1.5 * ( b[ 1 ][ 2 ] - b[ 0 ][ 2 ] )
        )
        @cam.C.set @cam.O.get()
        
    # 
    top: ->
        @cam.X.set [ 1, 0, 0]
        @cam.Y.set [ 0, 0, 1]
    # 
    right: ->
        @cam.X.set [ 0, 0, 1]
        @cam.Y.set [ 0, 1, 0]
    # 
    origin: ->
        @cam.X.set [ 1, 0, 0]
        @cam.Y.set [ 0, 1, 0]
    
    # redraw all the scene
    draw: ->
        flat = []
        for item in @items
            CanvasManager._get_flat_list flat, item
        @_mk_cam_info()
        #sort object depending z_index (a greater z index is in front of an element with a lower z index)
        flat.sort( ( a, b ) -> return a.z_index() - b.z_index() )
        
        for item in flat
            item.draw @cam_info

    resize: ( w, h ) ->
        @canvas.width  = w
        @canvas.height = h

    _dbl_click: ( evt ) ->
        @add_transform( evt )

    _img_mouse_down: ( evt ) ->
        evt = window.event if not evt?

        # code from http://unixpapa.com/js/mouse.html
        @old_button = 
            if evt.which?
                if evt.which  < 2 then "LEFT" else ( if evt.which  == 2 then "MIDDLE" else "RIGHT" )
            else
                if evt.button < 2 then "LEFT" else ( if evt.button == 4 then "MIDDLE" else "RIGHT" )
            
         
        @canvas.onmousemove = ( evt ) => @_img_mouse_move evt
        @old_x = evt.clientX - get_left( @canvas )
        @old_y = evt.clientY - get_top ( @canvas )
  
        @mouse_has_moved_since_mouse_down = false

        # look if there's a movable point under mouse
        for phase in [ 0 ... 3 ]
            movable_entities = @_get_movable_entities phase
            if movable_entities.length
                @undo_manager?.snapshot()
                break

        @movable_point = movable_entities[ 0 ]?.item
        
        # if @movable_point 
        if evt.ctrlKey # add / rem selection
            if @movable_point?
                @selected_entities.toggle_ref @movable_point
        else
            if @movable_point?
                @selected_entities.clear()
                @selected_entities.push @movable_point

                @movable_point.beg_click [ @old_x, @old_y ]
            else
                @selected_entities.clear()
                
        if @old_button == "RIGHT"
            @canvas.oncontextmenu = => return false
            evt.stopPropagation()
            evt.cancelBubble = true
            # ... rien ne marche sous chrome sauf document.oncontextmenu = => return false 
            document.oncontextmenu = => return false
            
        # return
        evt.preventDefault?()
        evt.returnValue = false
        return false
        
    
    _img_mouse_up: ( evt ) ->
        @canvas.onmousemove = ( evt ) => @_mouse_move evt # start event for hover
        if @old_button == "LEFT" and not @mouse_has_moved_since_mouse_down
#             if not @movable_point?
            for fun in @click_fun
                fun( this, evt )
        if @old_button == "RIGHT" and not @mouse_has_moved_since_mouse_down
            @context_menu?( evt, true )
        else
            @context_menu?( evt, false )
                
    _img_mouse_out: ( evt ) ->
        @canvas.onmousemove = ( evt ) => @_mouse_move evt # start event for hover
            
    # zoom sur l'objet avec la mollette
    _img_mouse_wheel: ( evt ) ->
        evt = window.event if not evt?

        # browser compatibility -> stolen from http://unixpapa.com/js/mouse.html
        delta = 0
        if evt.wheelDelta?
            delta = evt.wheelDelta / 120.0
            if window.opera
                delta = - delta
        else if evt.detail
            delta = - evt.detail / 3.0

        #
        c = Math.pow 1.2, delta
        x = evt.clientX - get_left( @canvas )
        y = evt.clientY - get_top ( @canvas )

        @cam.zoom x, y, c, @canvas.width, @canvas.height

        evt.preventDefault?()
        evt.returnValue = false
        return false
        
    _mouse_move: ( evt ) ->
        evt = window.event if not evt?
        @old_x = evt.clientX - get_left( @canvas )
        @old_y = evt.clientY - get_top ( @canvas )
        movable_entities = @_get_movable_entities 0
        @movable_point = movable_entities[ 0 ]?.item
        @pre_selected_entities.clear()
        if @movable_point?
            @pre_selected_entities.push @movable_point
            
    _img_mouse_move: ( evt ) ->
        evt = window.event if not evt?
        new_x = evt.clientX - get_left( @canvas )
        new_y = evt.clientY - get_top ( @canvas )
        if new_x == @old_x and new_y == @old_y
            return false
            
        if @movable_point? and not @mouse_has_moved_since_mouse_down
            @undo_manager?.snapshot()

        @mouse_has_moved_since_mouse_down = true

        if @movable_point?        
            dec_x = new_x - @old_x
            dec_y = new_y - @old_y
#             for sel_p in @selected_entities
            p_0 = @cam_info.sc_2_rw.pos (@old_x + dec_x), (@old_y + dec_y)
            d_0 = @cam_info.sc_2_rw.dir (@old_x + dec_x), (@old_y + dec_y)
            @movable_point.mov_click @selected_entities, @movable_point.pos, p_0, d_0
            
        else
            w   = @canvas.width
            h   = @canvas.height
            mwh = Math.min w, h
            
            if @old_button == "LEFT" and evt.shiftKey # rotate / z_screen
                a = Math.atan2( new_y - h / 2.0, new_x - w / 2.0 ) - Math.atan2( @old_y - h / 2.0, @old_x - w / 2.0 )
                @cam.rotate 0.0, 0.0, a
            else if @old_button == "MIDDLE" or @old_button == "LEFT" and evt.ctrlKey # pan
                @cam.pan new_x - @old_x, @old_y - new_y, w, h
            else if @old_button == "LEFT" # rotate / C
                x = 2.0 * ( new_x - @old_x ) / mwh
                y = 2.0 * ( new_y - @old_y ) / mwh
                @cam.rotate y, x, 0.0

        @old_x = new_x
        @old_y = new_y
    
    _create_3D_context: ( canvas, opt_attribs ) ->
        for t in [ "experimental-webgl", "webgl", "webkit-3d", "moz-webgl" ]
            try
                @ctx = canvas.getContext( t, opt_attribs );
                return @ctx if @ctx?
            catch error
                continue
            
    # trouve un contexte adequat pour tracer dans le canvas
    _init_ctx: ->
        if @allow_gl == true
            @_create_3D_context @canvas
        else
            @ctx_type = "2d"
            @ctx = @canvas.getContext( '2d' )
  

    _get_movable_entities: ( phase ) ->
        res = []
        for item in @items
            @_get_movable_entities_rec res, item, phase
        return res
            
    _get_movable_entities_rec: ( res, item, phase ) ->
        if item.get_movable_entities?
            item.get_movable_entities res, @cam_info, [ @old_x, @old_y ], phase
        else if item.sub_canvas_items?
            for sub_item in item.sub_canvas_items()
                @_get_movable_entities_rec res, sub_item, phase

    # 
    _fill_selected_items_rec: ( i, item ) ->
        i[ item.model_id ] = true
        # rec
        if item.sub_canvas_items?
            for n in item.sub_canvas_items()
                @_fill_selected_items_rec i, n

    # compute and store camera info in @cam_info
    _mk_cam_info: ->
        w = @canvas.width 
        h = @canvas.height
        
        i = {}
        for item in @selected_items
            @_fill_selected_items_rec i, item[ item.length - 1 ]
        
        s = {}
        for item in @selected_entities
            s[ item.model_id ] = true
        
        pre_s = {}
        for item in @pre_selected_entities
            pre_s[ item.model_id ] = true
            
        @cam_info =
            w       : w
            h       : h
            mwh     : Math.min w, h
            ctx     : @ctx
            cam     : @cam
            re_2_sc : @cam.re_2_sc w, h
            sc_2_rw : @cam.sc_2_rw w, h
            sel_item: i
            selected: s
            pre_sele: pre_s
            time    : @time
                    
    # get leaves in item list (i.e. object with a draw method)
    @_get_flat_list: ( flat, item ) ->
        if item.sub_canvas_items?
            for sub_item in item.sub_canvas_items()
                CanvasManager._get_flat_list flat, sub_item
        else
            flat.push item
