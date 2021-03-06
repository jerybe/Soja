class Point extends Drawable
    constructor: ( pos, type = MoveScheme_3D ) ->
        super()
        
        @scheme = MoveScheme_3D
        if type instanceof MoveScheme_2D
            @scheme = MoveScheme_2D
        
        @add_attr
            pos: new Vec_3 pos
            _mv: new @scheme

    disp_only_in_model_editor: ->
        @pos
        
    beg_click: ( pos ) ->
        @_mv.beg_click pos
    
    mov_click: ( selected_entities, pos, p_0, d_0 ) ->
        @_mv.mov_click selected_entities, pos, p_0, d_0
    